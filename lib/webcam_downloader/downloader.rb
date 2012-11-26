$:.unshift(File.dirname(__FILE__))

require 'digest/md5'

module WebcamDownloader
  class Downloader
    DEV_MODE = true
    DEV_MODE_LIMIT = 5

    def initialize(_options={ })
      @options = _options
      @defs = Array.new
      @webcams = Array.new

      @dns_timeout = 2 # --dns-timeout
      @connect_timeout = 3 # --connect-timeout
      @read_timeout = 10 # --read-timeout

    end

    def make_it_so
      # create WebCam instances
      @defs.each do |d|
        @webcams << WebcamDownloader::Webcam.new(d, self)
      end
    end

    def load_definition_file(file = File.join('config', 'defs.yml'))
      defs = YAML::load(File.open(file))
      flat_defs = Array.new
      defs.each do |u|
        flat_defs += u[:array]
      end

      if DEV_MODE
        flat_defs = flat_defs[0..DEV_MODE_LIMIT]
      end

      @defs += flat_defs
    end

  end
end