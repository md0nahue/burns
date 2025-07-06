require_relative 'base_image_client'

class PexelsClient < BaseImageClient
  def initialize(config = {})
    super(config)
    @base_url = 'https://api.pexels.com/v1'
  end

  def search_images(query, target_resolution = '1080p')
    return nil unless @api_key
    url = "#{@base_url}/search?query=#{URI.encode_www_form_component(query)}&per_page=10&orientation=landscape"
    headers = {
      'Authorization' => @api_key
    }
    data = make_request(url, headers)
    return nil unless data
    {
      provider: 'pexels',
      query: query,
      images: data['photos'].map do |photo|
        {
          url: photo['src']['large'],
          download_url: photo['src']['original'],
          width: photo['width'],
          height: photo['height'],
          description: photo['alt'],
          photographer: photo['photographer'],
          photographer_url: photo['photographer_url'],
          metadata: {
            id: photo['id'],
            avg_color: photo['avg_color'],
            liked: photo['liked']
          }
        }
      end
    }
  end
end 