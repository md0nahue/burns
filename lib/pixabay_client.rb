require_relative 'base_image_client'

class PixabayClient < BaseImageClient
  def initialize(config = {})
    super(config)
    @base_url = 'https://pixabay.com/api'
  end

  def search_images(query, target_resolution = '1080p')
    return nil unless @api_key
    dimensions = get_image_dimensions(target_resolution)
    url = "#{@base_url}/?key=#{@api_key}&q=#{URI.encode_www_form_component(query)}&image_type=photo&orientation=horizontal&per_page=20"
    data = make_request(url)
    return nil unless data
    {
      provider: 'pixabay',
      query: query,
      images: data['hits'].map do |photo|
        {
          url: photo['webformatURL'],
          download_url: photo['largeImageURL'],
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
            tags: photo['tags'].split(', ')
          }
        }
      end
    }
  end
end 