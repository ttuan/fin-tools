import requests
import csv
import pandas as pd
import time

# ~3 years of data
DAYS = 1200

STOCK_SYMBOLS = ["VNINDEX", "HPG", "SSI", "PVT", "REE", "TCB", "FPT"]

def fetch_stock_prices(stock):
    end_time = int(time.time())
    start_time = end_time - (DAYS * 24 * 60 * 60)

    url = f"https://dchart-api.vndirect.com.vn/dchart/history?resolution=D&symbol={stock}&from={start_time}&to={end_time}&sort=date:desc"

    headers = {
        "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/58.0.3029.110 Safari/537.3"
    }
    response = requests.get(url, headers=headers)
    if response.status_code == 200:
        return response.json()
    else:
        print(f"Error fetching data: {response.status_code}")
        return []

def create_stock_prices_csv():
    csv_data = []

    for symbol in STOCK_SYMBOLS:
        stock_data = fetch_stock_prices(symbol)
        if stock_data:
            dates = stock_data["t"]
            close_prices = stock_data["c"]
            for date, close_price in zip(dates, close_prices):
                formatted_date = time.strftime("%d/%m/%Y", time.localtime(date))
                if symbol != "VNINDEX":
                    close_price = round(close_price * 1000, 2)
                csv_data.append({"date": formatted_date, "close_price": close_price, "symbol": symbol})

    df = pd.DataFrame(csv_data)
    df_pivot = df.pivot(index='date', columns='symbol', values='close_price')

    # Convert the index to datetime format
    df_pivot.index = pd.to_datetime(df_pivot.index, format="%d/%m/%Y")

    # Sort the DataFrame by date in descending order
    df_pivot = df_pivot.sort_index(ascending=False)

    # Write to CSV
    df_pivot.to_csv("stock_prices.csv", index=True, header=True)

create_stock_prices_csv()
