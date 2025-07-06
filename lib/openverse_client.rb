require_relative 'base_image_client'

class OpenverseClient < BaseImageClient
  def initialize(config = {})
    super(config)
    @base_url = 'https://api.openverse.engineering/v1'
  end

  def search_images(query, target_resolution = '1080p')
    dimensions = get_image_dimensions(target_resolution)
    url = "#{@base_url}/images/?q=#{URI.encode_www_form_component(query)}&page_size=10&filter=license_type:commercial&filter=license_type:modification&filter=aspect_ratio:wide"
    headers = {
      'Accept' => 'application/json'
    }
    data = make_request(url, headers)
    return nil unless data
    {
      provider: 'openverse',
      query: query,
      images: data['results'].map do |image|
        {
          url: image['url'],
          download_url: image['url'],
          width: image['width'] || dimensions[:width],
          height: image['height'] || dimensions[:height],
          description: image['title'] || image['alt_text'],
          photographer: image['creator'] || 'Unknown',
          photographer_url: image['creator_url'],
          metadata: {
            id: image['id'],
            license: image['license'],
            license_version: image['license_version'],
            tags: image['tags']&.map { |tag| tag['name'] } || []
          }
        }
      end
    }
  end
end 