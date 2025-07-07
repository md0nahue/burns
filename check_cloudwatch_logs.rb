#!/usr/bin/env ruby

require_relative 'config/services'
require 'aws-sdk-cloudwatchlogs'
require 'json'

puts "📊 CloudWatch Logs Investigation"
puts "=" * 60

# Initialize CloudWatch Logs client
logs_client = Aws::CloudWatch::Logs::Client.new(
  region: Config::AWS_CONFIG[:region],
  credentials: Aws::Credentials.new(
    Config::AWS_CONFIG[:access_key_id],
    Config::AWS_CONFIG[:secret_access_key]
  )
)

function_name = Config::AWS_CONFIG[:lambda_function]
log_group_name = "/aws/lambda/#{function_name}"

puts "🔍 Checking CloudWatch logs for Lambda function: #{function_name}"
puts "📋 Log group: #{log_group_name}"

begin
  # Check if log group exists
  response = logs_client.describe_log_groups(
    log_group_name_prefix: log_group_name
  )
  
  if response.log_groups.any?
    puts "✅ Log group exists"
    
    log_group = response.log_groups.first
    puts "  📅 Created: #{Time.at(log_group.creation_time / 1000)}"
    puts "  📊 Stored bytes: #{log_group.stored_bytes}"
    puts "  📝 Metric filter count: #{log_group.metric_filter_count}"
    
    # Get recent log streams
    puts "\n🔍 Recent log streams:"
    streams_response = logs_client.describe_log_streams(
      log_group_name: log_group_name,
      order_by: 'LastEventTime',
      descending: true,
      limit: 5
    )
    
    if streams_response.log_streams.any?
      streams_response.log_streams.each_with_index do |stream, index|
        puts "  📄 Stream #{index + 1}: #{stream.log_stream_name}"
        puts "    📅 Last event: #{stream.last_event_time ? Time.at(stream.last_event_time / 1000) : 'None'}"
        puts "    📊 Events: #{stream.stored_bytes} bytes"
      end
      
      # Get events from the most recent stream
      latest_stream = streams_response.log_streams.first
      puts "\n📋 Recent log events from: #{latest_stream.log_stream_name}"
      
      events_response = logs_client.get_log_events(
        log_group_name: log_group_name,
        log_stream_name: latest_stream.log_stream_name,
        limit: 50,
        start_from_head: false
      )
      
      if events_response.events.any?
        puts "  📊 Found #{events_response.events.length} recent events"
        puts "  " + "-" * 58
        
        events_response.events.last(10).each do |event|
          timestamp = Time.at(event.timestamp / 1000)
          puts "  [#{timestamp.strftime('%H:%M:%S')}] #{event.message}"
        end
      else
        puts "  ❌ No recent events found"
      end
    else
      puts "  ❌ No log streams found"
    end
    
  else
    puts "❌ Log group not found"
    puts "  This might indicate the Lambda function has never been invoked"
    puts "  or CloudWatch logging is not enabled"
  end
  
rescue => e
  puts "❌ Error accessing CloudWatch logs: #{e.message}"
  puts "  This might be due to insufficient permissions"
end

# Also check for any Lambda errors in CloudWatch
puts "\n🔍 Checking for Lambda errors..."
begin
  # Query CloudWatch Logs for errors
  query_string = "fields @timestamp, @message | filter @message like /ERROR/ | sort @timestamp desc | limit 10"
  
  query_response = logs_client.start_query(
    log_group_name: log_group_name,
    start_time: (Time.now - 3600).to_i, # Last hour
    end_time: Time.now.to_i,
    query_string: query_string
  )
  
  query_id = query_response.query_id
  puts "  📋 Started error query: #{query_id}"
  
  # Wait for query to complete
  sleep(2)
  
  results_response = logs_client.get_query_results(query_id: query_id)
  
  if results_response.results.any?
    puts "  ❌ Found #{results_response.results.length} error messages:"
    results_response.results.each do |result|
      timestamp = result.find { |field| field.field == '@timestamp' }&.value
      message = result.find { |field| field.field == '@message' }&.value
      puts "    [#{timestamp}] #{message}"
    end
  else
    puts "  ✅ No error messages found in the last hour"
  end
  
rescue => e
  puts "  ❌ Error querying for Lambda errors: #{e.message}"
end

puts "\n" + "=" * 60
puts "🏁 CloudWatch investigation complete"