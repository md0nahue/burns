require 'httparty'
require 'logger'

class BaseImageClient
  attr_reader :api_key, :logger

  def initialize(config = {})
    @api_key = config[:api_key]
    @logger = Logger.new(STDOUT)
    @logger.level = Logger::INFO
  end

  def search_images(query, target_resolution = '1080p')
    raise NotImplementedError, "Subclasses must implement search_images"
  end

  def get_image_dimensions(target_resolution)
    case target_resolution.downcase
    when '1080p'
      { width: 2560, height: 1440 }
    when '4k'
      { width: 5120, height: 2880 }
    else
      { width: 2560, height: 1440 } # default to 1080p
    end
  end

  def make_request(url, headers = {})
    response = HTTParty.get(url, headers: headers)
    if response.success?
      response.parsed_response
    else
      raise "HTTP Error: #{response.code} - #{response.message}"
    end
  rescue => e
    @logger.error("Request failed: #{e.message}")
    nil
  end
end 