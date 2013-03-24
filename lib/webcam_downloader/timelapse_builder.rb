$:.unshift(File.dirname(__FILE__))

require 'webcam_downloader'
require 'pathname'
require 'colorize'
require 'fastimage'

module WebcamDownloader
  class TimelapseBuilder

    def initialize(_options = { })
      @options = _options

      @logger = _options[:logger] || Logger.new(STDOUT)
      @logger.level = _options[:logger_level] || WebcamDownloader::Downloader::LOGGER_LEVEL
      @workers_count = _options[:workers_count] || WebcamDownloader::Downloader::DEFAULT_WORKERS_COUNT

      @root_paths = _options[:root_paths] || []

      @downloader = WebcamDownloader::Downloader.new(_options)
      @downloader.load_all_definition_files

      @image_lists = Hash.new

    end

    def add_root_path(path)
      @root_paths << path
    end

    def analyze_webcam_images_for(desc)
      @image_lists[desc] = {
        started: Time.now,
        array: Array.new
      }
      il = @image_lists[desc]

      # root paths loop
      @root_paths.each do |path|
        p = File.join(path, 'pix')
        months_paths = Pathname.glob("#{p}/*/")
        months_paths.sort.each do |month_path|
          @logger.info("Start analyze of #{desc.to_s.red}, month #{month_path.basename.to_s.red}")

          path = File.join(month_path, desc)
          d = analyze_webcam_from_path(path)
          il[:array] += d
        end
      end

    end

    def analyze_webcam_from_path(month_path)
      a = Array.new
      files = Pathname.glob("#{month_path}/*")
      @logger.info(" #{files.size.to_s.blue} files")

      errors = 0
      success = 0

      files.each do |f|
        res = check_valid_jpeg(f)

        if res == false
          errors += 1
        else
          success += 1

          if f.basename.to_s =~ /(\d{6,20})/
            a << { time: $1.to_i, path: f }
          end

          if f % 100 == 0
            @logger.info(" ... #{files.size.to_s.blue}")
          end

        end
      end

      @logger.info(" errors #{errors.to_s.yellow}, success #{success.to_s.green}")

      return a
    end

    def check_valid_jpeg(path)
      return true if FastImage.type(path, timeout: 0.5) == :jpeg
      return false
    end

  end
end