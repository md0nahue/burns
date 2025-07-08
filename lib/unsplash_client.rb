require_relative 'base_image_client'

class UnsplashClient < BaseImageClient
  def initialize(config = {})
    super(config)
    @base_url = 'https://api.unsplash.com'
    @secret_key = config[:secret_key] || ENV['UNSPLASH_SECRET_KEY']
  end

  def search_images(query, target_resolution = '1080p')
    return nil unless @api_key
    
    # Enhanced query for better quality results
    enhanced_query = "#{query} high resolution professional"
    
    # Request more results to filter for quality
    url = "#{@base_url}/search/photos?query=#{URI.encode_www_form_component(enhanced_query)}&per_page=15&orientation=landscape&order_by=relevant"
    
    headers = {
      'Authorization' => "Client-ID #{@api_key}",
      'Accept-Version' => 'v1'
    }
    data = make_request(url, headers)
    return nil unless data
    
    {
      provider: 'unsplash',
      query: query,
      images: data['results'].map do |photo|
        # Use the highest quality version available
        image_url = photo['urls']['full'] || photo['urls']['raw'] || photo['urls']['regular']
        
        {
          url: image_url,
          download_url: photo['links']['download'],
          width: photo['width'],
          height: photo['height'],
          description: photo['description'] || photo['alt_description'],
          photographer: photo['user']['name'],
          photographer_url: photo['user']['links']['html'],
          metadata: {
            id: photo['id'],
            created_at: photo['created_at'],
            likes: photo['likes'],
            color: photo['color'],
            quality_score: calculate_quality_score(photo)
          }
        }
      end.select { |img| 
        # Pre-filter for high-quality images based on dimensions and metadata
        img[:width] && img[:height] && 
        img[:width] >= 2400 && img[:height] >= 1600 &&  # Higher minimum for Unsplash
        img[:metadata][:likes] >= 5  # Prefer images with some social validation
      }.sort_by { |img| 
        # Sort by quality score (likes, dimensions, etc.)
        -img[:metadata][:quality_score]
      }
    }
  end

  private

  def calculate_quality_score(photo)
    # Calculate a quality score based on various factors
    score = 0
    
    # Dimension score (higher resolution = better)
    if photo['width'] && photo['height']
      pixel_count = photo['width'] * photo['height']
      score += (pixel_count / 1_000_000.0) * 10  # 10 points per megapixel
    end
    
    # Social validation score (likes)
    score += (photo['likes'] || 0) * 0.1
    
    # Premium/Plus status bonus
    score += 20 if photo['user']['for_hire'] == true
    
    # Description quality bonus (longer descriptions often indicate curated content)
    description_length = (photo['description'] || photo['alt_description'] || '').length
    score += [description_length / 10.0, 10].min
    
    score
  end
end 