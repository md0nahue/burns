require_relative 'base_image_client'

class UnsplashClient < BaseImageClient
  def initialize(config = {})
    super(config)
    @base_url = 'https://api.unsplash.com'
  end

  def search_images(query, target_resolution = '1080p')
    return nil unless @api_key
    dimensions = get_image_dimensions(target_resolution)
    url = "#{@base_url}/search/photos?query=#{URI.encode_www_form_component(query)}&per_page=10&orientation=landscape"
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
        {
          url: photo['urls']['regular'],
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
            color: photo['color']
          }
        }
      end
    }
  end
end 