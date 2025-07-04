#!/usr/bin/env ruby

require 'net/http'
require 'json'
require 'uri'
require 'date'
require 'slack-ruby-client'

class GoldChecker
  SLACK_TOKEN = ENV['SLACK_TOKEN']
  SLACK_CHANNEL = ENV['SLACK_CHANNEL'] || "#zz-gold-checker"

  GOLD_API_URL = 'https://apiclient.topi.vn/api-web/GetGoldChart'

  def initialize(slack_token = nil, slack_channel = nil)
    @slack_token = slack_token || SLACK_TOKEN
    @slack_channel = slack_channel || SLACK_CHANNEL

    if @slack_token
      Slack.configure { |config| config.token = @slack_token }
      @slack_client = Slack::Web::Client.new
    end
  end

  def check_gold_prices
    puts "Starting gold price check at #{Time.now}"

    # Check for 30 days
    puts "\n=== Checking 30-day data ==="
    check_period(30)

    # Check for 90 days
    puts "\n=== Checking 90-day data ==="
    check_period(90)
  end

  private

  def check_period(days)
    data = fetch_gold_data(days)
    return unless data

    latest_data = get_latest_data(data)
    return unless latest_data

    puts "Latest data (#{days} days): #{latest_data['Date']}"
    puts "  SJCXAUPrice: #{latest_data['SJCXAUPrice']}"
    puts "  AvgSJCXAUPrice: #{latest_data['AvgSJCXAUPrice']}"
    puts "  RingXAUPrice: #{latest_data['RingXAUPrice']}"
    puts "  AvgRingXAUPrice: #{latest_data['AvgRingXAUPrice']}"

    # Check conditions
    ring_condition = latest_data['RingXAUPrice'] <= latest_data['AvgRingXAUPrice']
    sjc_condition = latest_data['SJCXAUPrice'] <= latest_data['AvgSJCXAUPrice']

    puts "  Ring condition (RingXAUPrice <= AvgRingXAUPrice): #{ring_condition}"
    puts "  SJC condition (SJCXAUPrice <= AvgSJCXAUPrice): #{sjc_condition}"

    if ring_condition || sjc_condition
      message = build_slack_message(latest_data, days, ring_condition, sjc_condition)
      send_slack_notification(message)
    else
      puts "  No conditions met, no notification sent"
    end
  end

  def fetch_gold_data(days)
    uri = URI(GOLD_API_URL)

    request_body = {
      "Source" => "AVERAGE",
      "Days" => days,
      "platform" => "Web"
    }

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true

    request = Net::HTTP::Post.new(uri)
    request['accept'] = 'application/json, text/plain, */*'
    request['accept-language'] = 'en,vi;q=0.9,ja;q=0.8'
    request['content-type'] = 'application/json'
    request['origin'] = 'https://online.topi.vn'
    request['priority'] = 'u=1, i'
    request['referer'] = 'https://online.topi.vn/'
    request['sec-ch-ua'] = '"Google Chrome";v="137", "Chromium";v="137", "Not/A)Brand";v="24"'
    request['sec-ch-ua-mobile'] = '?0'
    request['sec-ch-ua-platform'] = '"macOS"'
    request['sec-fetch-dest'] = 'empty'
    request['sec-fetch-mode'] = 'cors'
    request['sec-fetch-site'] = 'same-site'
    request['user-agent'] = 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/137.0.0.0 Safari/537.36'
    request.body = request_body.to_json

    begin
      response = http.request(request)

      if response.code == '200'
        parsed_response = JSON.parse(response.body)

        if parsed_response['success'] == 1 && parsed_response['data']['Data']
          puts "Successfully fetched #{days}-day data: #{parsed_response['data']['Data'].length} records"
          return parsed_response['data']['Data']
        else
          puts "API error: #{parsed_response['message']}"
          return nil
        end
      else
        puts "HTTP error: #{response.code} - #{response.message}"
        return nil
      end
    rescue => e
      puts "Request failed: #{e.message}"
      return nil
    end
  end

  def get_latest_data(data)
    return nil if data.empty?

    # Sort by date to get the latest (assuming the data might not be sorted)
    sorted_data = data.sort_by do |item|
      parse_date(item['Date'])
    end

    sorted_data.last
  end

  def parse_date(date_str)
    # The API returns dates in DD/MM/YYYY format
    begin
      return Date.strptime(date_str, '%d/%m/%Y')
    rescue Date::Error
      # Fall back to MM/DD/YYYY format just in case
      begin
        return Date.strptime(date_str, '%m/%d/%Y')
      rescue Date::Error
        puts "Warning: Could not parse date: #{date_str}"
        return Date.new(2000, 1, 1) # Fallback date
      end
    end
  end

  def build_slack_message(data, days, ring_condition, sjc_condition)
    # Helper method to format VND numbers
    def format_vnd(number)
      return "N/A" if number.nil?
      number.round.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse
    end

    conditions_met = []
    conditions_met << "Ring: `#{format_vnd(data['RingXAUPrice'])}` <= `#{format_vnd(data['AvgRingXAUPrice'])}`" if ring_condition
    conditions_met << "SJC: `#{format_vnd(data['SJCXAUPrice'])}` <= `#{format_vnd(data['AvgSJCXAUPrice'])}`" if sjc_condition

    blocks = [
      {
        type: "section",
        text: {
          type: "mrkdwn",
          text: "🏆 *Gold Price Alert - #{days} Days*"
        }
      },
      {
        type: "section",
        fields: [
          {
            type: "mrkdwn",
            text: "*Date:*\n#{data['Date']}"
          },
          {
            type: "mrkdwn",
            text: "*Period:*\n#{days} days"
          },
          {
            type: "mrkdwn",
            text: "*Ring XAU Price:*\n`#{format_vnd(data['RingXAUPrice'])}` (avg: `#{format_vnd(data['AvgRingXAUPrice'])}`)"
          },
          {
            type: "mrkdwn",
            text: "*SJC XAU Price:*\n`#{format_vnd(data['SJCXAUPrice'])}` (avg: `#{format_vnd(data['AvgSJCXAUPrice'])}`)"
          }
        ]
      },
      {
        type: "section",
        text: {
          type: "mrkdwn",
          text: "*Conditions Met:*\n#{conditions_met.join("\n")}"
        }
      }
    ]

    { blocks: blocks }
  end

  def send_slack_notification(message)
    unless @slack_client
      puts "  ⚠️  Slack client not configured, skipping notification"
      puts "  Would send: Gold Price Alert"
      return
    end

    begin
      params = {
        channel: @slack_channel,
        **message
      }

      response = @slack_client.chat_postMessage(**params)
      puts "  ✅ Slack notification sent successfully"
    rescue Slack::Web::Api::Errors::SlackError => e
      puts "  ❌ Failed to send Slack notification: #{e.message}"
    rescue => e
      puts "  ❌ Slack notification failed: #{e.message}"
    end
  end
end

# Usage
if __FILE__ == $0
  # You can pass the Slack token and channel as arguments or set them as environment variables
  slack_token = ARGV[0] if ARGV.length > 0
  slack_channel = ARGV[1] if ARGV.length > 1

  checker = GoldChecker.new(slack_token, slack_channel)
  checker.check_gold_prices
end
