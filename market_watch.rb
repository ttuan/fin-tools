require 'net/http'
require 'uri'
require 'openssl'
require 'nokogiri'
require 'json'
require 'date'
require 'slack-ruby-client'
require 'concurrent-ruby'
require 'pry'

# Constants
SLACK_TOKEN="xoxb-xxxxx-xxxxx-xxxxx"
SLACK_CHANNEL="#zz_market_watch"

ICONS = {
  "US10Y" => "📊",
  "VN1Y" => "📉",
  "VN10Y" => "📈",
  "USDVND" => "💵",
  "DXY" => "💰",
  "Gold Price" => "🥇",
  "GD NDT NN" => "🌍",
  "Tự doanh" => "🏢",
  "VNINDEX" => "🇻🇳",
  "VNINDEX P/E" => "📈",
  "VN Gold Prices" => "🏅",
  "Brent Oil" => "⛽",
  "ON" => "📰"
}.freeze

URLS = {
  "US10Y" => "https://tradingeconomics.com/united-states/government-bond-yield",
  "VN10Y" => "https://tradingeconomics.com/vietnam/government-bond-yield",
  "Brent Oil" => "https://tradingeconomics.com/commodity/brent-crude-oil",
  "Gold Price" => "https://tradingeconomics.com/commodity/gold",
  "VN Gold Prices" => "http://giavang.doji.vn/",
  "GD NDT NN" => "https://cafef.vn/du-lieu/tracuulichsu2/3/hose/#{Date.today.strftime("%d/%m/%Y")}.chn",
  "Tự doanh" => "https://dstock.vndirect.com.vn/",
  "VNINDEX" => "https://dstock.vndirect.com.vn/",
  "VNINDEX P/E" => "https://etrade.tcsc.vn/tci/analytic-tool",
  "DXY" => "https://tradingeconomics.com/united-states/currency",
  "VN1Y" => "https://vn.investing.com/rates-bonds/vietnam-1-year-bond-yield-streaming-chart",
  "USDVND" => "https://tradingeconomics.com/usdvnd:cur",
  "ON" => "https://vira.org.vn/tin/Ban-tin.html"
}.freeze

# Abstract class for fetching financial data
class FinancialDataFetcher
  attr_reader :url, :symbol

  HEADERS = {
    'User-Agent' => 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/58.0.3029.110 Safari/537.3'
  }.freeze

  def initialize(url, symbol = nil)
    @url = url
    @symbol = symbol
  end

  def fetch_data
    raise NotImplementedError, "Subclasses must implement `fetch_data`"
  end

  protected

  def fetch_soup(verify: true)
    uri = URI.parse(@url)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = (uri.scheme == "https")
    http.verify_mode = OpenSSL::SSL::VERIFY_NONE unless verify

    request = Net::HTTP::Get.new(uri.request_uri, HEADERS)
    response = http.request(request)
    return Nokogiri::HTML(response.body) if response.is_a?(Net::HTTPSuccess)

    nil
  rescue StandardError => e
    puts "Error fetching #{@url}: #{e}"
    nil
  end

  def convert_to_vnd_billion(amount)
    billion_vnd = amount.to_f / 1_000_000_000
    formatted = format('%.2f', billion_vnd)

    if billion_vnd >= 1000
      "#{(formatted.split('.')[0].to_f / 1000).round(2)} nghìn tỷ"
    else
      "#{formatted} tỷ"
    end
  end
end

class TradingEconomicsFetcher < FinancialDataFetcher
  def fetch_data
    soup = fetch_soup
    return nil unless soup

    row = soup.at_css("tr[data-symbol='#{@symbol}']")
    return nil unless row

    price = row.at_css("td#p")&.text&.strip
    day_change = row.at_css("td#pch")&.text&.strip
    date_value = row.at_css("td#date")&.text&.strip
    return nil unless price && day_change && date_value

    "`#{price}`, Day Change: `#{day_change}` (#{date_value})"
  end
end

class Vietnam1YBondFetcher < FinancialDataFetcher
  def fetch_data
    soup = fetch_soup
    return nil unless soup

    yield_value = soup.at_css("div[data-test='instrument-price-last']")&.text&.strip
    change_percent = soup.at_css("span[data-test='instrument-price-change-percent']")&.text&.strip
    return nil unless yield_value && change_percent

    "`#{yield_value}`, Change: `#{change_percent.gsub(/[()]/, '')}`"
  end
end

# For ON interest
class MarketReportFetcher < FinancialDataFetcher
  BASE_URL = "https://vira.org.vn"

  def fetch_data
    soup = fetch_soup
    return nil unless soup

    today_date = Date.today.strftime("%d/%m/%Y")
    link = nil

    soup.css('.story__header').each do |header|
      meta_time = header.at_css('.story__meta time')

      if meta_time && meta_time.text.include?(today_date)
        header_text = header.text.strip

        if header_text.include?("Market Watch")
          relative_link = header.at_css('a')['href']
          link = URI.join(BASE_URL, relative_link).to_s
          break
        end
      end
    end

    if link.nil?
      puts "Market Watch link not found. Searching by title..."
      row_div = soup.at_css('.row')
      return nil unless row_div

      articles = row_div.css('article.story')
      return nil if articles.empty?

      articles.each do |article|
        title_tag = article.at_css('.story__title')
        if title_tag && title_tag.text.include?("Market Watch")
          link = URI.join(BASE_URL, title_tag.at_css('a')['href']).to_s
          break
        end
      end
    end

    return nil unless link

    @url = link
    new_soup = fetch_soup
    return nil unless new_soup

    money_market_section = new_soup.at_xpath("//ul[li[contains(normalize-space(.), 'MONEY MARKET')]]")

    if money_market_section
      next_p = money_market_section.at_xpath("following-sibling::p[1]")
      image = next_p.at_css("img") if next_p
      return image['src'] if image
    end

    "MONEY MARKET section not found."
  end
end

class VietnamGoldFetcher < FinancialDataFetcher
  def fetch_data
    soup = fetch_soup(verify: false)
    return nil unless soup

    prices = []

    # Find the gold price table
    table = soup.at_css('#bang-gia-theo-vung-mien .hn table.goldprice-view')
    return "No gold price table found." unless table

    # Process rows in the table
    table.css('tbody tr').each do |row|
      label = row.at_css('td.label')&.text&.strip
      sell_price = row.css('td')[2]&.text&.strip

      if label == "SJC - Bán Lẻ"
        prices << "SJC - Bán Lẻ: `#{sell_price}`"
      elsif label == "Nhẫn Tròn 9999 Hưng Thịnh Vượng - Bán Lẻ"
        prices << "Nhẫn Tròn 9999 Hưng Thịnh Vượng - Bán Lẻ: `#{sell_price}`"
      end
      break if prices.size == 2
    end

    prices.any? ? prices.join(", ") : "No prices found."
  end
end

class VnindexFetcher < FinancialDataFetcher
  def fetch_data
    @url = "https://api-finfo.vndirect.com.vn/v4/vnmarket_prices?sort=date&q=code:VNINDEX"
    uri = URI.parse(@url)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = (uri.scheme == "https")

    request = Net::HTTP::Get.new(uri.request_uri, HEADERS)
    response = http.request(request)
    response_json = JSON.parse(response.body)
    data = response_json["data"]&.first

    return nil unless data

    close = data["close"]
    change = data["change"].round(2)
    volume = convert_to_vnd_billion(data["accumulatedVal"])
    date_time = "#{data['date']} #{data['time']}"
    parsed_date_time = DateTime.parse(date_time).strftime("%d/%m %H:%M")

    "`#{close}`, Change: `#{change}`, Volume: `#{volume}` (#{parsed_date_time})"
  end
end

class VnindexPEFetcher < FinancialDataFetcher
  def fetch_data
    @url = "https://wl-market.fiintrade.vn/MarketInDepth/GetValuationSeriesV2?language=vi&Code=VNINDEX&TimeRange=ThreeYears&FromDate=&ToDate="

    headers = HEADERS.merge({
      'Accept' => 'application/json',
      'Accept-Language' => 'en,vi;q=0.9,ja;q=0.8',
      'Connection' => 'keep-alive',
      'Content-Type' => 'application/json',
      'Origin' => 'https://etrade.tcsc.vn',
      'Referer' => 'https://etrade.tcsc.vn/',
      'Sec-Fetch-Dest' => 'empty',
      'Sec-Fetch-Mode' => 'cors',
      'Sec-Fetch-Site' => 'cross-site',
      'X-Fiin-Key' => 'KEY',
      'X-Fiin-Seed' => 'SEED',
      'X-Fiin-User-ID' => 'ID',
      'sec-ch-ua' => '"Not;A=Brand";v="99", "Google Chrome";v="139", "Chromium";v="139"',
      'sec-ch-ua-mobile' => '?0',
      'sec-ch-ua-platform' => '"macOS"'
    })

    uri = URI.parse(@url)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = (uri.scheme == "https")

    request = Net::HTTP::Get.new(uri.request_uri, headers)
    response = http.request(request)

    return nil unless response.is_a?(Net::HTTPSuccess)

    response_json = JSON.parse(response.body)
    items = response_json["items"]

    return nil unless items && items.any?

    # Get the last (most recent) item
    latest_item = items.last
    pe_ratio = latest_item["r21"]&.round(2)
    trading_date = Date.parse(latest_item["tradingDate"]).strftime("%d/%m")

    return nil unless pe_ratio

    "`#{pe_ratio}` (#{trading_date})"
  rescue StandardError => e
    puts "Error fetching VNINDEX P/E: #{e}"
    nil
  end
end

class ForeignTransactionFetcher < FinancialDataFetcher
  def fetch_data
    # Get current date in YYYY-MM-DD format
    current_date = Date.today.strftime("%Y-%m-%d")

    # Build the API URL
    @url = "https://api-finfo.vndirect.com.vn/v4/foreigns?q=code:STOCK_HNX,STOCK_UPCOM,STOCK_HOSE,ETF_HOSE,IFC_HOSE&sort=tradingDate&size=500"

    headers = HEADERS.merge({
      'Accept' => '*/*',
      'Accept-Language' => 'en,vi;q=0.9,ja;q=0.8',
      'Connection' => 'keep-alive',
      'Content-Type' => 'application/json',
      'Origin' => 'https://dstock.vndirect.com.vn',
      'Referer' => 'https://dstock.vndirect.com.vn/',
      'Sec-Fetch-Dest' => 'empty',
      'Sec-Fetch-Mode' => 'cors',
      'Sec-Fetch-Site' => 'same-site',
      'sec-ch-ua' => '"Not;A=Brand";v="99", "Google Chrome";v="139", "Chromium";v="139"',
      'sec-ch-ua-mobile' => '?0',
      'sec-ch-ua-platform' => '"macOS"'
    })

    uri = URI.parse(@url)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = (uri.scheme == "https")

    request = Net::HTTP::Get.new(uri.request_uri, headers)
    response = http.request(request)

    return nil unless response.is_a?(Net::HTTPSuccess)

    response_json = JSON.parse(response.body)
    data = response_json["data"]

    return nil unless data && data.any?

    # Filter data by current date and calculate totals
    current_date_data = data.select { |item| item["tradingDate"] == current_date }

    # If no data for current date, use the first 5 records (most recent date)
    if current_date_data.empty?
      # Take first 5 records from the sorted response (most recent date)
      recent_data = data.first(5)
      return nil if recent_data.empty?

      # Use the date from the first record as the actual date
      actual_date = recent_data.first["tradingDate"]

      # Calculate totals for the most recent date
      total_buy_val = recent_data.sum { |item| item["buyVal"] || 0 }
      total_sell_val = recent_data.sum { |item| item["sellVal"] || 0 }
      total_net_val = recent_data.sum { |item| item["netVal"] || 0 }
    else
      # Use current date data
      actual_date = current_date
      total_buy_val = current_date_data.sum { |item| item["buyVal"] || 0 }
      total_sell_val = current_date_data.sum { |item| item["sellVal"] || 0 }
      total_net_val = current_date_data.sum { |item| item["netVal"] || 0 }
    end

    # Convert to billions VND
    buy_billion = convert_to_vnd_billion(total_buy_val)
    sell_billion = convert_to_vnd_billion(total_sell_val)
    net_billion = convert_to_vnd_billion(total_net_val)

    # Format output for Slack
    net_prefix = total_net_val >= 0 ? "+" : ""
    formatted_date = Date.parse(actual_date).strftime("%b/%d")
    "Mua: `#{buy_billion}`, Bán: `#{sell_billion}`, Ròng: `#{net_prefix}#{net_billion}` (#{formatted_date})"
  rescue StandardError => e
    puts "Error fetching foreign transaction data: #{e}"
    nil
  end
end

class ProprietaryTradingFetcher < FinancialDataFetcher
  def fetch_data
    # Get current date in YYYY-MM-DD format
    start_date = (Date.today - 10).strftime("%Y-%m-%d")
    current_date = Date.today.strftime("%Y-%m-%d")

    # Build the API URL with proper date range
    @url = "https://api-finfo.vndirect.com.vn/v4/proprietary_trading?q=code:HNX,VNINDEX,UPCOM~date:gte:#{start_date}~date:lte:#{current_date}&sort=date:desc&size=600"

    headers = HEADERS.merge({
      'sec-ch-ua-platform' => '"macOS"',
      'Referer' => 'https://dstock.vndirect.com.vn/',
      'Content-Type' => 'application/json',
      'sec-ch-ua' => '"Not;A=Brand";v="99", "Google Chrome";v="139", "Chromium";v="139"',
      'sec-ch-ua-mobile' => '?0'
    })

    uri = URI.parse(@url)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = (uri.scheme == "https")

    request = Net::HTTP::Get.new(uri.request_uri, headers)
    response = http.request(request)

    return nil unless response.is_a?(Net::HTTPSuccess)

    response_json = JSON.parse(response.body)
    data = response_json["data"]

    return nil unless data && data.any?

    # Filter data by current date and calculate totals
    current_date_data = data.select { |item| item["date"] == current_date }

    # If no data for current date, use the first 3 records (most recent date)
    if current_date_data.empty?
      # Take first 3 records from the sorted response (most recent date)
      recent_data = data.first(3)
      return nil if recent_data.empty?

      # Use the date from the first record as the actual date
      actual_date = recent_data.first["date"]

      # Calculate totals for the most recent date
      total_buying_val = recent_data.sum { |item| item["buyingVal"] || 0 }
      total_selling_val = recent_data.sum { |item| item["sellingVal"] || 0 }
      total_net_val = recent_data.sum { |item| item["netVal"] || 0 }
    else
      # Use current date data
      actual_date = current_date
      total_buying_val = current_date_data.sum { |item| item["buyingVal"] || 0 }
      total_selling_val = current_date_data.sum { |item| item["sellingVal"] || 0 }
      total_net_val = current_date_data.sum { |item| item["netVal"] || 0 }
    end

    # Convert to billions VND
    buying_billion = convert_to_vnd_billion(total_buying_val)
    selling_billion = convert_to_vnd_billion(total_selling_val)
    net_billion = convert_to_vnd_billion(total_net_val)

    # Format output for Slack
    net_prefix = total_net_val >= 0 ? "+" : ""
    formatted_date = Date.parse(actual_date).strftime("%b/%d")
    "Mua: `#{buying_billion}`, Bán: `#{selling_billion}`, Ròng: `#{net_prefix}#{net_billion}` (#{formatted_date})"
  rescue StandardError => e
    puts "Error fetching proprietary trading data: #{e}"
    nil
  end
end

class SlackNotifier
  def initialize(token, channel)
    Slack.configure { |config| config.token = token }
    @client = Slack::Web::Client.new
    @channel = channel
  end

  def send_message(data, thread_ts: nil)
    today_date = Time.now.strftime("%Y-%m-%d %H:%M")
    blocks = [{ type: "section", text: { type: "mrkdwn", text: "*Market Update - #{today_date}*" } }]

    data.each do |label, value|
      next unless value

      icon = ICONS.fetch(label, "📌")
      url = URLS.fetch(label, "#")
      linked_label = "<#{url}|#{label}>"

      text = "#{icon} *#{linked_label}*: #{value}"
      blocks << { type: "section", text: { type: "mrkdwn", text: text } }

      if label == "ON" && value.start_with?("http")
        blocks << {
          type: "image",
          image_url: value,
          alt_text: "Market Report"
        }
      end

      blocks << { type: "divider" } if label == "VN Gold Prices" or label == "VNINDEX P/E"
    end

    params = { channel: @channel, blocks: blocks }
    params[:thread_ts] = thread_ts if thread_ts
    response = @client.chat_postMessage(**params)
    puts "Slack message sent successfully."
    response["ts"]
  rescue Slack::Web::Api::Errors::SlackError => e
    puts "Error sending Slack message: #{e.message}"
    nil
  end

  def send_title_only
    today_date = morning_run? ? Time.now.strftime("%Y-%m-%d") : Time.now.strftime("%Y-%m-%d %H:%M")
    blocks = [{ type: "section", text: { type: "mrkdwn", text: "*Market Watch - #{today_date}*" } }]
    params = { channel: @channel, blocks: blocks }
    response = @client.chat_postMessage(**params)
    puts "Slack title message sent successfully."
    response["ts"]
  end
end

# Helper methods for thread_ts file
THREAD_FILE = ".market_watch_thread"

def save_thread_ts(ts)
  File.write(THREAD_FILE, ts)
end

def read_thread_ts
  File.exist?(THREAD_FILE) ? File.read(THREAD_FILE).strip : nil
end

def morning_run?
  now = Time.now
  now.hour == 8 && now.min < 40 # allow a 10-min window for cron
end

def fetch_concurrently(fetchers)
  futures = fetchers.map do |label, fetcher|
    [label, Concurrent::Future.execute { fetcher.fetch_data }]
  end.to_h

  futures.transform_values(&:value) # Blocking call to get all values
end

def run_market_update(slack_token, slack_channel)
  fetchers = {
    "US10Y" => TradingEconomicsFetcher.new(URLS["US10Y"], "USGG10YR:IND"),
    "VN10Y" => TradingEconomicsFetcher.new(URLS["VN10Y"], "VNMGOVBON10Y:GOV"),
    "Brent Oil" => TradingEconomicsFetcher.new(URLS["Brent Oil"], "CO1:COM"),
    "Gold Price" => TradingEconomicsFetcher.new(URLS["Gold Price"], "XAUUSD:CUR"),
    "VN Gold Prices" => VietnamGoldFetcher.new(URLS["VN Gold Prices"]),
    "GD NDT NN" => ForeignTransactionFetcher.new(URLS["GD NDT NN"]),
    "Tự doanh" => ProprietaryTradingFetcher.new(URLS["Tự doanh"]),
    "VNINDEX" => VnindexFetcher.new(URLS["VNINDEX"]),
    "VNINDEX P/E" => VnindexPEFetcher.new(URLS["VNINDEX P/E"]),
    "DXY" => TradingEconomicsFetcher.new(URLS["DXY"], "DXY:CUR"),
    "VN1Y" => Vietnam1YBondFetcher.new(URLS["VN1Y"]),
    "USDVND" => TradingEconomicsFetcher.new(URLS["USDVND"], "USDVND:CUR"),
    "ON" => MarketReportFetcher.new(URLS["ON"])
  }

  market_data = fetch_concurrently(fetchers)
  slack_notifier = SlackNotifier.new(slack_token, slack_channel)

  if morning_run?
    ts = slack_notifier.send_title_only
    save_thread_ts(ts) if ts
    slack_notifier.send_message(market_data, thread_ts: ts)
  else
    thread_ts = read_thread_ts
    if thread_ts
      slack_notifier.send_message(market_data, thread_ts: thread_ts)
    else
      ts = slack_notifier.send_title_only
      save_thread_ts(ts) if ts
      slack_notifier.send_message(market_data, thread_ts: ts)
    end
  end
end

run_market_update(SLACK_TOKEN, SLACK_CHANNEL)
