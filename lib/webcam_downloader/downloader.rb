$:.unshift(File.dirname(__FILE__))

require 'digest/md5'
require 'logger'

module WebcamDownloader
  class Downloader
    DEV_MODE = true
    DEV_MODE_LIMIT = 5
    LOGGER_LEVEL = Logger::DEBUG

    def initialize(_options={ })
      @options = _options

      @logger = _options[:logger] || Logger.new(STDOUT)
      @logger.level = _options[:logger_level] || LOGGER_LEVEL

      @defs = Array.new
      @webcams = Array.new

      @sleep_interval = 5

      @storage = WebcamDownloader::Storage.new(self, _options)
      @image_processor = WebcamDownloader::ImageProcessor.new(self, _options)
    end

    attr_reader :storage, :image_processor, :logger

    def make_it_so
      # create WebCam instances
      @defs.each do |d|
        w = WebcamDownloader::Webcam.new(d, self)
        @webcams << w
        @logger.debug("Created Webcam for #{w.desc}")
      end

      @logger.info("Start!")
      @started_at = Time.now
      @storage.descs = @webcams.collect{|w| w.desc}
      @storage.prepare_file_structure
      @storage.prepare_monthly_directories

      @logger.info("Start loop!")
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