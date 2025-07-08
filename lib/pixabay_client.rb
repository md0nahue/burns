require_relative 'base_image_client'

class PixabayClient < BaseImageClient
  def initialize(config = {})
    super(config)
    @base_url = 'https://pixabay.com/api'
  end

  def search_images(query, target_resolution = '1080p')
    return nil unless @api_key
    
    # Enhanced query for high quality and request larger images
    enhanced_query = "#{query} high quality professional"
    
    # Request high resolution images with quality filters
    url = "#{@base_url}/?key=#{@api_key}&q=#{URI.encode_www_form_component(enhanced_query)}&image_type=photo&orientation=horizontal&per_page=20&min_width=2000&min_height=1000&order=popular"
    
    data = make_request(url)
    return nil unless data
    
    {
      provider: 'pixabay',
      query: query,
      images: data['hits'].map do |photo|
        # Use the highest quality version available
        image_url = photo['fullHDURL'] || photo['largeImageURL'] || photo['webformatURL']
        
        {
          url: image_url,
          download_url: photo['largeImageURL'] || image_url,
          width: photo['imageWidth'],
          height: photo['imageHeight'],
          description: photo['tags'],
          photographer: photo['user'],
          photographer_url: "https://pixabay.com/users/#{photo['user']}-#{photo['user_id']}/",
          metadata: {
            id: photo['id'],
            likes: photo['likes'],
            downloads: photo['downloads'],
            comments: photo['comments'],
            tags: photo['tags'].split(', '),
            quality_score: calculate_quality_score(photo)
          }
        }
      end.select { |img| 
        # Additional quality filtering
        img[:width] && img[:height] && 
        img[:width] >= 2400 && img[:height] >= 1200 &&  # Higher resolution requirement
        img[:metadata][:likes] >= 10 &&  # Require some popularity
        img[:metadata][:downloads] >= 50  # Require some usage validation
      }.sort_by { |img| 
        # Sort by quality score
        -img[:metadata][:quality_score]
      }
    }
  end

  private

  def calculate_quality_score(photo)
    # Calculate quality score based on Pixabay metrics
    score = 0
    
    # Dimension score
    if photo['imageWidth'] && photo['imageHeight']
      pixel_count = photo['imageWidth'] * photo['imageHeight']
      score += (pixel_count / 1_000_000.0) * 8  # 8 points per megapixel
    end
    
    # Social metrics
    score += (photo['likes'] || 0) * 0.2
    score += (photo['downloads'] || 0) * 0.01
    score += (photo['comments'] || 0) * 0.5
    
    # Quality indicators in tags
    quality_tags = ['hd', 'high resolution', '4k', 'professional', 'studio']
    tag_string = (photo['tags'] || '').downcase
    quality_tags.each do |tag|
      score += 10 if tag_string.include?(tag)
    end
    
    score
  end
end 