require_relative 'base_image_client'

class WikimediaClient < BaseImageClient
  def initialize(config = {})
    super(config)
    @base_url = 'https://commons.wikimedia.org/w/api.php'
  end

  def search_images(query, target_resolution = '1080p')
    dimensions = get_image_dimensions(target_resolution)
    
    # WikiMedia Commons API parameters
    params = {
      action: 'query',
      format: 'json',
      list: 'search',
      srsearch: query,
      srnamespace: 6, # File namespace
      srlimit: 10,
      srqiprofile: 'classic', # Better quality results
      srqisize: 'large' # Prefer larger images
    }
    
    url = build_url(@base_url, params)
    headers = {
      'Accept' => 'application/json',
      'User-Agent' => 'Burns-Video-Generator/1.0'
    }
    
    data = make_request(url, headers)
    return nil unless data && data['query']
    
    # Get detailed info for each image
    image_titles = data['query']['search'].map { |item| item['title'] }
    detailed_images = get_image_details(image_titles)
    
    {
      provider: 'wikimedia',
      query: query,
      images: detailed_images.compact.map do |image|
        {
          url: image[:url],
          download_url: image[:url],
          width: image[:width] || dimensions[:width],
          height: image[:height] || dimensions[:height],
          description: image[:description] || query,
          photographer: image[:author] || 'Wikimedia Commons',
          photographer_url: image[:author_url],
          metadata: {
            id: image[:pageid],
            license: image[:license],
            categories: image[:categories],
            usage_restrictions: image[:usage_restrictions],
            file_size: image[:file_size]
          }
        }
      end
    }
  end

  private

  def build_url(base_url, params)
    query_string = params.map { |k, v| "#{k}=#{URI.encode_www_form_component(v.to_s)}" }.join('&')
    "#{base_url}?#{query_string}"
  end

  def get_image_details(titles)
    return [] if titles.empty?
    
    # Get detailed information for each image
    params = {
      action: 'query',
      format: 'json',
      titles: titles.join('|'),
      prop: 'imageinfo|categories',
      iiprop: 'url|size|mime|extmetadata',
      cllimit: 10,
      clshow: '!hidden'
    }
    
    url = build_url(@base_url, params)
    headers = {
      'Accept' => 'application/json',
      'User-Agent' => 'Burns-Video-Generator/1.0'
    }
    
    data = make_request(url, headers)
    return [] unless data && data['query']
    
    pages = data['query']['pages']
    images = []
    
    pages.each do |pageid, page|
      next unless page['imageinfo'] && page['imageinfo'].any?
      
      imageinfo = page['imageinfo'].first
      extmetadata = imageinfo['extmetadata'] || {}
      
      # Extract license and author information
      license = extract_license(extmetadata)
      author = extract_author(extmetadata)
      author_url = extract_author_url(extmetadata)
      
      # Check if image meets size requirements
      width = imageinfo['width'].to_i
      height = imageinfo['height'].to_i
      
      # Only include images that meet minimum size requirements
      if width >= 1920 && height >= 1080
        images << {
          url: imageinfo['url'],
          width: width,
          height: height,
          description: extract_description(extmetadata),
          author: author,
          author_url: author_url,
          license: license,
          pageid: pageid,
          file_size: imageinfo['size'],
          categories: page['categories']&.map { |cat| cat['title'] } || [],
          usage_restrictions: extract_usage_restrictions(extmetadata)
        }
      end
    end
    
    images
  end

  def extract_license(extmetadata)
    license_field = extmetadata['License'] || extmetadata['license']
    if license_field && license_field['value']
      license_field['value']
    else
      'Unknown'
    end
  end

  def extract_author(extmetadata)
    author_field = extmetadata['Author'] || extmetadata['author'] || extmetadata['Artist'] || extmetadata['artist']
    if author_field && author_field['value']
      author_field['value']
    else
      'Wikimedia Commons'
    end
  end

  def extract_author_url(extmetadata)
    author_url_field = extmetadata['AuthorURL'] || extmetadata['authorurl']
    if author_url_field && author_url_field['value']
      author_url_field['value']
    else
      nil
    end
  end

  def extract_description(extmetadata)
    desc_field = extmetadata['ImageDescription'] || extmetadata['imagedescription'] || extmetadata['Description'] || extmetadata['description']
    if desc_field && desc_field['value']
      desc_field['value']
    else
      nil
    end
  end

  def extract_usage_restrictions(extmetadata)
    restrictions = []
    
    # Check for various restriction indicators
    restriction_fields = ['Restrictions', 'restrictions', 'UsageRestrictions', 'usagerestrictions']
    restriction_fields.each do |field|
      if extmetadata[field] && extmetadata[field]['value']
        restrictions << extmetadata[field]['value']
      end
    end
    
    restrictions.empty? ? nil : restrictions.join(', ')
  end
end 