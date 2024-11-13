import ccxt
import time
import json
import os
import sys

# Define timeframes and their corresponding parameters
timeframes = {
    '1h': ('1m', 1 * 60 * 60 * 1000),
    '1d': ('15m', 24 * 60 * 60 * 1000),
    '1w': ('1h', 7 * 24 * 60 * 60 * 1000),
    '1M': ('6h', 30 * 24 * 60 * 60 * 1000),
    '1y': ('1d', 365 * 24 * 60 * 60 * 1000),
    'all': ('1w', int(time.mktime(time.strptime('2010-01-01', '%Y-%m-%d')) * 1000))
}

# Set up output directory only once
output_dir = "ohlc_data"
os.makedirs(output_dir, exist_ok=True)

# Debugging step: Print the absolute path where data will be saved
print(f"Data will be saved to directory: {os.path.abspath(output_dir)}")

def fetch_all_timeframes(symbol, exchange: ccxt.Exchange):
    now = int(time.time() * 1000)
    results = {}

    # Normalize symbol for filename purposes (replace '/' with '_')
    normalized_symbol = symbol.replace('/', '_')

    for chart_range, (timeframe, period_ms) in timeframes.items():
        start_time = now - period_ms if chart_range != 'all' else period_ms
        print(f"Fetching data from API for {normalized_symbol}_{chart_range}...")

        all_ohlc_data = []
        while start_time < now:
            try:
                # Fetch OHLC data
                ohlc_data = exchange.fetch_ohlcv(symbol, timeframe, since=start_time, limit=1500)
                if not ohlc_data:
                    break
                all_ohlc_data.extend(ohlc_data)
                start_time = ohlc_data[-1][0] + 1  # Move to the next timestamp
                
            except Exception as e:
                print(f"Error fetching data for {chart_range}: {str(e)}", file=sys.stderr)
                break

        # Extract timestamp and close price if data was fetched
        if all_ohlc_data:
            line_data = [[candle[0], candle[4]] for candle in all_ohlc_data]
            results[chart_range] = line_data

    return results

def find_exchange_for_symbol(symbol):
    exchanges_to_check = ['binance', 'kucoin', 'bitget', 'okx', 'gate', 'mexc']
    for exchange_name in exchanges_to_check:
        try:
            exchange = getattr(ccxt, exchange_name)()
            markets = exchange.load_markets()
            if symbol in markets:
                print(f"Symbol {symbol} found on exchange: {exchange_name}")
                return exchange
            else:
                print(f"Symbol {symbol} not found on exchange: {exchange_name}")
        except Exception as e:
            print(f"Error loading {exchange_name}: {str(e)}", file=sys.stderr)
    
    print(f"Symbol {symbol} is not available on any of the checked exchanges.")
    return None

if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("Usage: python3 ohlc_data_fetcher.py <symbol>", file=sys.stderr)
        sys.exit(1)

    symbol = sys.argv[1]

    # Find an exchange that supports the symbol
    exchange = find_exchange_for_symbol(symbol)
    
    if exchange is None:
        print(f"No exchange found for symbol {symbol}. Exiting.")
        sys.exit(1)

    try:
        data = fetch_all_timeframes(symbol, exchange)
        
        if not data:
            print(f"No data fetched for {symbol}. Symbol might not be listed on the exchange.")
            sys.exit(1)
        
        # Save JSON to file
        output_file = os.path.join(output_dir, f"{symbol.replace('/', '_')}_all.json")

        # Debugging step: Print the absolute file path where data is saved
        print(f"Saving data to file: {os.path.abspath(output_file)}")
        
        with open(output_file, "w") as f:
            json.dump(data, f)
        
        # Output the file path for reference (this is what you need in your app to load the file)
        print(f"Path:{os.path.abspath(output_file)}")

    except Exception as e:
        print(f"Error fetching OHLC data: {str(e)}", file=sys.stderr)
