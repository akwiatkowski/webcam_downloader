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

      @sleep_interval = 5

      @storage = WebcamDownloader::Storage.new(self)
    end

    attr_reader :storage

    def make_it_so
      # create WebCam instances
      @defs.each do |d|
        @webcams << WebcamDownloader::Webcam.new(d, self)
      end

      @started_at = Time.now
      @storage.prepare_file_structure
      @storage.prepare_monthly_directories(@webcams.collect{|w| w.desc})
      start_loop
    end

    def start_loop
      loop do
        @webcams.each do |webcam|
          webcam.make_it_so
        end

        sleep(@sleep_interval)
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