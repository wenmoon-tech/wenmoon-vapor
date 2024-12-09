# ================================
# Build image
# ================================
FROM swift:5.8-jammy as build

# Install OS updates and dependencies, including python3 for building
RUN export DEBIAN_FRONTEND=noninteractive DEBCONF_NONINTERACTIVE_SEEN=true \
    && apt-get -q update \
    && apt-get -q dist-upgrade -y \
    && apt-get -q install -y python3 python3-pip \
    && rm -rf /var/lib/apt/lists/*

# Set up a build area
WORKDIR /build

# First just resolve dependencies
COPY ./Package.* ./
RUN swift package resolve

# Copy entire repo into container
COPY . .

# Build everything, with optimizations
RUN swift build -c release --static-swift-stdlib

# Switch to the staging area
WORKDIR /staging

# Copy main executable to staging area
RUN cp "$(swift build --package-path /build -c release --show-bin-path)/App" ./

# Copy resources bundled by SPM to staging area
RUN find -L "$(swift build --package-path /build -c release --show-bin-path)/" -regex '.*\.resources$' -exec cp -Ra {} ./ \;

# Copy any resources from the public directory and views directory if the directories exist
RUN [ -d /build/Public ] && { mv /build/Public ./Public && chmod -R a-w ./Public; } || true
RUN [ -d /build/Resources ] && { mv /build/Resources ./Resources && chmod -R a-w ./Resources; } || true

# Copy the Python script to staging
COPY ohlc_data_fetcher.py /staging/ohlc_data_fetcher.py

# ================================
# Run image
# ================================
FROM ubuntu:jammy

# Install Python and essential system packages, including pip and the required packages
RUN export DEBIAN_FRONTEND=noninteractive DEBCONF_NONINTERACTIVE_SEEN=true \
    && apt-get -q update \
    && apt-get -q dist-upgrade -y \
    && apt-get -q install -y \
      ca-certificates \
      python3 \
      python3-pip \
      tzdata \
    && rm -r /var/lib/apt/lists/*

# Install Python dependencies (ccxt)
COPY requirements.txt /app/requirements.txt
RUN pip3 install -r /app/requirements.txt

# Create a vapor user and group with /app as its home directory
RUN useradd --user-group --create-home --system --skel /dev/null --home-dir /app vapor

# Switch to the new home directory
WORKDIR /app

# Ensure vapor user has write access to the directory where the Python script saves data
RUN mkdir -p /app/ohlc_data && chmod -R 777 /app/ohlc_data

# Copy built executable and any staged resources from builder
COPY --from=build --chown=vapor:vapor /staging /app

# Ensure all further commands run as the vapor user
USER vapor:vapor

# Let Docker bind to port 8080
EXPOSE 8080

# Start the Vapor service when the image is run, default to listening on 8080 in production environment
ENTRYPOINT ["./App"]
CMD ["serve", "--env", "production", "--hostname", "0.0.0.0", "--port", "8080"]
