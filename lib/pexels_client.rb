require_relative 'base_image_client'

class PexelsClient < BaseImageClient
  def initialize(config = {})
    super(config)
    @base_url = 'https://api.pexels.com/v1'
  end

  def search_images(query, target_resolution = '1080p')
    return nil unless @api_key
    
    # Request larger images and higher quality for Ken Burns effects
    # Add minimum size filter to get better quality images
    enhanced_query = "#{query} high quality"
    url = "#{@base_url}/search?query=#{URI.encode_www_form_component(enhanced_query)}&per_page=15&orientation=landscape&size=large"
    
    headers = {
      'Authorization' => @api_key
    }
    data = make_request(url, headers)
    return nil unless data
    
    {
      provider: 'pexels',
      query: query,
      images: data['photos'].map do |photo|
        # Use the highest quality version available
        image_url = photo['src']['original'] || photo['src']['large2x'] || photo['src']['large']
        
        {
          url: image_url,
          download_url: photo['src']['original'],
          width: photo['width'],
          height: photo['height'],
          description: photo['alt'],
          photographer: photo['photographer'],
          photographer_url: photo['photographer_url'],
          metadata: {
            id: photo['id'],
            avg_color: photo['avg_color'],
            liked: photo['liked'],
            original_size: photo['src']['original'] ? true : false
          }
        }
      end.select { |img| 
        # Additional filtering for high-quality images
        img[:width] && img[:height] && 
        img[:width] >= 2000 && img[:height] >= 1000  # Pre-filter for higher resolution
      }
    }
  end
end 