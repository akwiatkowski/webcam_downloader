$:.unshift(File.dirname(__FILE__))

require 'webcam_downloader'
require 'pathname'
require 'colorize'
require 'fastimage'
require 'active_support'
require 'active_support/core_ext'

module WebcamDownloader
  class ArchiveDownloader

    attr_reader :logger

    def initialize(_options = {})
      @options = _options

      @logger = _options[:logger] || Logger.new(STDOUT)
      @logger.level = _options[:logger_level] || WebcamDownloader::Downloader::LOGGER_LEVEL

      @downloader = WebcamDownloader::Downloader.new(_options)
      @downloader.load_all_definition_files

      @archived_path = File.join("pix", "archived")

      WebcamDownloader::WgetProxy.instance.setup(self, _options)
    end

    def archivable_defs
      @downloader.defs.select { |d| d[:url_schema] }
    end

    def proxy=(ps)
      WebcamDownloader::WgetProxy.instance.proxy = ps
    end

    def setup_desc(desc, schema = nil)
      @def = @downloader.defs.select { |d| d[:url_schema] and d[:desc] =~ /#{desc}/ }.first

      raise StandardError if @def.nil?

      @desc = @def[:desc]
      @url_schema = @def[:url_schema]

      # just initial
      prepare_path
      load_results
    end

    def start(from_time = Time.now)
      full_month = true
      t = from_time.to_datetime
      t = t.beginning_of_month

      @logger.info("Start archive of #{@desc.green} from #{from_time.to_date.to_s(:db).blue}")

      while full_month
        @logger.info("Start month archive for #{t.to_date.to_s(:db).blue}")

        # not using active support or something
        t = t.beginning_of_month

        # process month
        full_month = start_month(t)

        # month before
        t = t.prev_month
      end
    end

    def start_month(time)
      end_of_month = time.end_of_month
      beginning_of_month = time.beginning_of_month
      every = 10.minutes
      t = end_of_month
      max_iteration = (end_of_month.to_f - beginning_of_month.to_f) / every.to_f
      current_iteration = 0

      # stats
      total_size = 0
      downloaded_count = 0

      month_path = prepare_path(time)

      while t >= beginning_of_month
        percentage = 100.0 * current_iteration.to_f / max_iteration.to_f
        url = WebcamDownloader::Webcam.generate_url(@url_schema, t)
        image_time = WebcamDownloader::Webcam.adjust_time_for_schema(@url_schema, t)
        destination = File.join(month_path, "#{@desc}_#{image_time.to_i}.jpg")

        if t >= @last_tried or t > Time.now or File.exists?(destination)
          # skip if it was tried before, or it's in future, or it's image exists
          @logger.debug("#{"%.1f" % percentage}% - SKIPPING url #{url.green}")
        else


          WebcamDownloader::WgetProxy.instance.download_file(url, destination)

          if File.exists?(destination)
            image_size = File.size(destination)
            if image_size == 0
              File.delete(destination)
              @logger.debug("#{"%.1f" % percentage}% ERROR - url #{url.red} EMPTY")

              @last_tried = t
              @last_failed = t
              @stats_image_fail_count += 1
              @error_array << {
                image_time: image_time,
                url: url,
                destination: destination
              }


              store_results
              random_sleep(nil)
            else
              total_size += image_size
              downloaded_count += 1
              @logger.debug("#{"%.1f" % percentage}% - url #{url.green}, size #{image_size.to_s.red}, total #{total_size.to_s.yellow}")

              @last_downloaded = t
              @last_tried = t
              @stats_image_count += 1
              @stats_image_total_size += image_size

              store_results
              random_sleep(true)
            end
          end
        end


        # next iteration
        t -= every
        current_iteration += 1
      end

      true
    end

    def random_sleep(is_exists = true)
      if is_exists
        sleep(10 + rand(40))
      else
        sleep(2 + rand(15))
      end
    end

    def prepare_path(time = Time.now)
      f = @archived_path
      Dir.mkdir(f) unless File.exists?(f)

      mp = WebcamDownloader::Storage.monthly_prefix(time)
      f = File.join(@archived_path, mp)
      Dir.mkdir(f) unless File.exists?(f)

      f = File.join(f, @desc)
      Dir.mkdir(f) unless File.exists?(f)

      # put there images
      return f
    end

    def load_results
      results = nil
      if File.exists?(results_path)
        results = YAML.load_file(results_path)
      end

      results = Hash.new unless results.kind_of?(Hash)
      # standard time
      results[@desc] = Hash.new unless results[@desc].kind_of?(Hash)
      results[@desc][:last_downloaded] ||= Time.now.end_of_month + 1.day
      results[@desc][:last_tried] ||= Time.now.end_of_month + 1.day
      results[@desc][:last_failed] ||= Time.now.end_of_month + 1.day
      results[@desc][:error_array] ||= Array.new
      results[@desc][:stats_image_fail_count] ||= 0
      results[@desc][:stats_image_count] ||= 0
      results[@desc][:stats_image_total_size] ||= 0

      @last_downloaded = results[@desc][:last_downloaded]
      @last_tried = results[@desc][:last_tried]
      @last_failed = results[@desc][:last_failed]
      @error_array = results[@desc][:error_array]
      @stats_image_fail_count = results[@desc][:stats_image_fail_count]
      @stats_image_count = results[@desc][:stats_image_count]
      @stats_image_total_size = results[@desc][:stats_image_total_size]
    end

    def store_results
      results = nil
      if File.exists?(results_path)
        results = YAML.load_file(results_path)
        FileUtils.copy(results_path, results_path(".2"))
      end

      results = Hash.new unless results.kind_of?(Hash)
      # standard time
      results[@desc] = Hash.new unless results[@desc].kind_of?(Hash)
      results[@desc][:last_downloaded] = @last_downloaded
      results[@desc][:last_tried] = @last_tried
      results[@desc][:last_failed] = @last_failed
      results[@desc][:error_array] = @error_array
      results[@desc][:stats_image_fail_count] = @stats_image_fail_count
      results[@desc][:stats_image_count] = @stats_image_count
      results[@desc][:stats_image_total_size] = @stats_image_total_size

      File.open(results_path, 'w') { |f| f.write results.to_yaml }
    end

    def results_path(backup_sufix = "")
      File.join("pix", "archived", "resume.yml#{backup_sufix}")
    end

  end
end