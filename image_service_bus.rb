require_relative 'lib/image_service_bus'

if __FILE__ == $0
  # Configuration - you'll need to get API keys from the respective services
  config = {
    unsplash: { api_key: ENV['UNSPLASH_API_KEY'] },
    pexels: { api_key: ENV['PEXELS_API_KEY'] },
    pixabay: { api_key: ENV['PIXABAY_API_KEY'] },
    lorem_picsum: {}, # No API key needed
    openverse: {} # No API key needed
  }

  # Initialize the service bus
  service_bus = ImageServiceBus.new(config)

  # Example usage
  puts "Image Service Bus Demo"
  puts "======================"
  
  # Get client status
  puts "\nClient Status:"
  service_bus.client_status.each do |client, status|
    puts "  #{client}: #{status[:available] ? 'Available' : 'Unavailable'}"
  end

  # Search for images
  query = "mountain landscape"
  puts "\nSearching for: '#{query}'"
  
  results = service_bus.get_images(query, 3, '1080p')
  
  results.each do |result|
    next unless result
    puts "\nResults from #{result[:provider]}:"
    result[:images].each_with_index do |image, i|
      puts "  #{i + 1}. #{image[:description]} (#{image[:width]}x#{image[:height]})"
      puts "     URL: #{image[:url]}"
      puts "     Photographer: #{image[:photographer]}"
    end
  end
end 