require_relative 'base_image_client'

class LoremPicsumClient < BaseImageClient
  def initialize(config = {})
    super(config)
    @base_url = 'https://picsum.photos'
  end

  def search_images(query, target_resolution = '1080p')
    dimensions = get_image_dimensions(target_resolution)
    images = []
    5.times do |i|
      random_id = rand(1..1000)
      images << {
        url: "#{@base_url}/#{dimensions[:width]}/#{dimensions[:height]}?random=#{random_id}",
        download_url: "#{@base_url}/#{dimensions[:width]}/#{dimensions[:height]}?random=#{random_id}",
        width: dimensions[:width],
        height: dimensions[:height],
        description: "Random placeholder image #{i + 1}",
        photographer: "Lorem Picsum",
        photographer_url: "https://picsum.photos",
        metadata: {
          id: random_id,
          seed: random_id
        }
      }
    end
    {
      provider: 'lorem_picsum',
      query: query,
      images: images
    }
  end
end 