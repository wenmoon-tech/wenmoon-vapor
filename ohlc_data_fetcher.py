import ccxt
import time
import sys
import json
import os
from argparse import ArgumentParser

# Define timeframes and aggregation settings
timeframes = {
    '1d': ('15m', 24 * 60 * 60 * 1000),  # Aggregates 15-minute data into 1-day
    '1w': ('1h', 7 * 24 * 60 * 60 * 1000),  # Aggregates 1-hour data into 1-week
    '1M': ('6h', 30 * 24 * 60 * 60 * 1000),  # Aggregates 6-hour data into 1-month
    '1y': ('1d', 365 * 24 * 60 * 60 * 1000),  # Aggregates 1-day data into 1-year
    'all': ('1w', int(time.mktime(time.strptime('2010-01-01', '%Y-%m-%d')) * 1000))  # Fetches all data since 2010
}

# List of exchanges to try in order
exchanges_to_check = ["kucoin", "bitget", "mexc"]

# Parse arguments
parser = ArgumentParser()
parser.add_argument("symbol", help="Symbol to fetch data for (e.g., BTC/USDT)")
parser.add_argument("timeframe", help="Timeframe to fetch (e.g., 1d, 1w, 1M etc.)")
parser.add_argument("--output_dir", default="/tmp/output_data", help="Directory to write output files")
args = parser.parse_args()

output_dir = args.output_dir
os.makedirs(output_dir, exist_ok=True)

def find_exchange_for_symbol(symbol):
    """Find an exchange that supports the given symbol."""
    for exchange_name in exchanges_to_check:
        try:
            exchange = getattr(ccxt, exchange_name)()
            markets = exchange.load_markets()
            if symbol in markets:
                print(f"Symbol {symbol} found on exchange: {exchange_name}", file=sys.stderr)  # Debug to stderr
                return exchange
            else:
                print(f"Symbol {symbol} not found on exchange: {exchange_name}", file=sys.stderr)  # Debug to stderr
        except Exception as e:
            print(f"Error loading exchange {exchange_name}: {str(e)}", file=sys.stderr)  # Debug to stderr
    print(json.dumps({"error": f"Symbol {symbol} is not available on any of the checked exchanges."}))
    sys.exit(1)

def fetch_ohlcv(symbol, exchange, timeframe, start_time, limit=1500):
    """Fetch OHLCV data."""
    all_ohlc_data = []
    now = int(time.time() * 1000)

    while start_time < now:
        try:
            ohlc_data = exchange.fetch_ohlcv(symbol, timeframe, since=start_time, limit=limit)
            if not ohlc_data:
                break
            all_ohlc_data.extend(ohlc_data)
            start_time = ohlc_data[-1][0] + 1  # Move to the next timestamp
        except Exception as e:
            print(json.dumps({"error": f"Error fetching data: {str(e)}"}))
            sys.exit(1)

    return [[candle[0], candle[4]] for candle in all_ohlc_data]  # Extract timestamp and close price

def write_to_file(data, symbol, chart_range):
    """Write data to a file and return the file path."""
    filename = f"{symbol.replace('/', '_')}_{chart_range}.json"
    file_path = os.path.join(output_dir, filename)
    with open(file_path, 'w') as f:
        json.dump(data, f)
    return file_path

if __name__ == "__main__":
    symbol = args.symbol
    chart_range = args.timeframe

    if chart_range not in timeframes:
        print(json.dumps({"error": f"Invalid timeframe: {chart_range}. Valid options are: {', '.join(timeframes.keys())}"}))
        sys.exit(1)

    timeframe, period_ms = timeframes[chart_range]
    exchange = find_exchange_for_symbol(symbol)

    start_time = int(time.time() * 1000) - period_ms if chart_range != 'all' else period_ms
    data = fetch_ohlcv(symbol, exchange, timeframe, start_time)

    # Always write data to a file and return the file path
    file_path = write_to_file(data, symbol, chart_range)
    print(json.dumps({"file_path": file_path}))
