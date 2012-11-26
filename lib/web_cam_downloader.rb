require 'digest/md5'

class WebCamDownloader
  attr_accessor :urls

  DEV_MODE = true
  DEV_MODE_LIMIT = 5

  def initialize(_options={ })
    @options = _options
  end

  def load_definition_file(file = File.join('config', 'defs.yml'))
    urls = YAML::load(File.open(file))
    flat_urls = Array.new
    urls.each do |u|
      flat_urls += u[:array]
    end
    # just for dev

    if DEV_MODE
      flat_urls = flat_urls[0..DEV_MODE_LIMIT]
    end

    return flat_urls
  end


end
