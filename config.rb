# Configuration file for Image Service Bus
# Copy this file to config_local.rb and add your API keys

module ImageServiceBusConfig
  # API Keys - Get these from the respective services
  # Unsplash: https://unsplash.com/developers
  # Pexels: https://www.pexels.com/api/
  # Pixabay: https://pixabay.com/api/docs/
  
  API_KEYS = {
    unsplash: ENV['UNSPLASH_ACCESS_KEY'] || nil,
    pexels: ENV['PEXELS_API_KEY'] || nil,
    pixabay: ENV['PIXABAY_API_KEY'] || nil
  }

  # Service configuration
  SERVICES = {
    unsplash: { 
      api_key: API_KEYS[:unsplash],
      rate_limit: 50, # requests per hour
      timeout: 30
    },
    pexels: { 
      api_key: API_KEYS[:pexels],
      rate_limit: 200, # requests per hour
      timeout: 30
    },
    pixabay: { 
      api_key: API_KEYS[:pixabay],
      rate_limit: 5000, # requests per hour
      timeout: 30
    },
    lorem_picsum: {
      rate_limit: 1000, # requests per hour
      timeout: 10
    },
    openverse: {
      rate_limit: 100, # requests per hour
      timeout: 30
    }
  }

  # Image resolution presets for YouTube Ken Burns effect
  RESOLUTIONS = {
    '1080p' => {
      width: 2560,
      height: 1440,
      description: 'Minimum for 1080p YouTube videos'
    },
    '4k' => {
      width: 5120,
      height: 2880,
      description: 'Minimum for 4K YouTube videos'
    },
    'ideal_1080p' => {
      width: 3840,
      height: 2160,
      description: 'Ideal for 1080p YouTube videos'
    },
    'ideal_4k' => {
      width: 6000,
      height: 3375,
      description: 'Ideal for 4K YouTube videos'
    }
  }

  # Default settings
  DEFAULTS = {
    target_resolution: '1080p',
    backup_count: 2,
    max_retries: 3,
    retry_delay: 2, # seconds
    log_level: 'INFO'
  }

  # Test settings
  TEST = {
    enabled_apis: [:lorem_picsum, :openverse], # APIs that don't require keys
    test_queries: ['mountain', 'ocean', 'forest', 'city', 'sunset'],
    max_test_requests: 5, # Limit test requests to avoid rate limits
    test_delay: 2 # seconds between tests
  }
end 