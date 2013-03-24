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

      @logger.info("Loaded #{il[:array].size.to_s.blue} images")

      # sort
      il[:array] = il[:array].sort { |a, b| a[:time] <=> b[:time] }

      after_analyze(desc)
    end

    def after_analyze(desc)
      file_list_file_path = File.absolute_path(File.join("tmp", "#{desc}_#{Time.now.to_i.to_s}.txt"))
      movie_file_path = File.absolute_path(File.join("data", "#{desc}_#{Time.now.to_i.to_s}.avi"))
      command_file_path = File.absolute_path(File.join("tmp", "#{desc}_#{Time.now.to_i.to_s}.sh"))

      # file list
      file_list_file = File.open(file_list_file_path, 'w')
      @image_lists[desc][:array].each do |image|
        file_list_file.puts(image[:path].to_s)
      end
      file_list_file.close

      @logger.info("Saved file list #{file_list_file_path.to_s.green} with #{@image_lists[desc][:array].size} images")

      # command
      command_options = @options.clone.merge(
        {
          file_list: file_list_file_path,
          output: movie_file_path
        })

      command = generate_command(command_options)
      command_file = File.open(command_file_path, 'w')
      command_file.puts(command)
      command_file.close
    end

    def generate_command(_options = { }, preset = nil)
      if preset.to_s == 'HD'
        _options = _options.merge(
          {
            width: 1280,
            height: 720,
            bitrate: 5000
          }
        )
      end

      if preset.to_s == '480p'
        _options = _options.merge(
          {
            width: 854,
            height: 480,
            bitrate: 3000
          }
        )
      end

      width = _options[:width] || 1280
      height = _options[:height] || 720
      ratio = width.to_f / height.to_f
      bitrate = _options[:bitrate] || 4000
      fps = _options[:fps] || 25
      file_list = _options[:file_list]
      output = _options[:output]

      # -1 true aspect ratio
      # -2 fit into movie size, aspect not maintained
      aspect_ratio_type = _options[:aspect] || -2

      scale_crop_string = "-aspect #{ratio} -vf scale=#{aspect_ratio_type}:#{height},crop=#{width}:#{height} -sws 9 "
      input_string = "\"mf://@#{file_list}\" "
      fps_string = "-mf fps=#{fps} "
      options_string = "-ovc xvid -xvidencopts noqpel:nogmc:trellis:nocartoon:nochroma_me:chroma_opt:lumi_mask:max_iquant=7:max_pquant=7:max_bquant=7:bitrate=#{bitrate}:threads=120 "
      output_string = "-o \"#{output}\" -oac copy "
      command = "mencoder #{input_string}#{fps_string}#{scale_crop_string}#{options_string}#{output_string}"

      return command
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

          if (success + errors) % 100 == 0
            @logger.info(" ... #{(success + errors)} / #{files.size}")
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