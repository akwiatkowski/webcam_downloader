$:.unshift(File.dirname(__FILE__))

module WebcamDownloader
  class Webcam
    def initialize(_options, _downloader)
      @options = _options
      @downloader = _downloader
      @storage = _downloader.storage
      @image_processor = _downloader.image_processor
      @logger = _downloader.logger

      @desc = _options[:desc]
      @interval = _options[:interval]
      @pre_url = _options[:pre_url]
      @referer = _options[:ref] || _options[:referer]
      @url = _options[:url]
      @url_schema = _options[:url_schema]
      @process_resize = _options[:resize] || _options[:process_resize]

      @path_temporary = nil
      @path_temporary_processed = nil
      @path_store = nil
      @latest_downloaded_time = nil
      @download_count = 0
      @download_time_cost_total = 0.0
      @download_time_cost_max = 0.0
      @last_downloaded_temporary_at = nil
      @process_count = 0
      @process_time_cost_total = 0.0
      @process_time_cost_max = 0.0

    end

    attr_reader :desc

    attr_accessor :path_temporary, :path_temporary_processed, :path_store


    def make_it_so
      if download_by_interval?
        download!
      end
    end

    def download_by_interval?
      (Time.now.to_i - @last_downloaded_temporary_at.to_i >= @interval.to_i)
    end

    def download!
      # if user has to download something before main image
      pre_url_download
      # setup all local paths
      setup_paths
      # generate url when url schemes
      generate_url_if_needed
      # download image to temp, store size, digest, ...
      download_to_temp
      # if image can't be downloaded or is 0-size, delete and ignore this attempt
      # wait interval for another attempt
      return false if downloaded_file_is_empty?
      # check if that image wasn't downloaded at previous attempt
      return false if downloaded_file_is_equal_to_previous?
      # mark that this image is last downloaded and store
      mark_temp_image_as_latest
      # process image (resize, re-compress) if that is set in definition
      process_temp_image_if_needed
      # move to storage
      move_to_storage
    end

    #

    # download temporary and remove
    def pre_url_download
      unless @pre_url.nil?
        WebcamDownloader::WgetProxy.instance.download_and_remove(@pre_url)
        @logger.debug("#{@desc} - Pre-url downloaded from #{@pre_url}")
      end
    end

    def setup_paths
      @storage.set_paths_for_webcam(self)
    end

    def generate_url_if_needed
      return if @url_schema.nil?

      t = Time.now.to_i
      # webcams store image every :time_modulo interval
      if @url_schema[:time_modulo]
        t -= t % @url_schema[:time_modulo]
      end

      # time offset
      if @url_schema[:time_offset]
        t += @url_schema[:time_offset].to_i
        t -= @url_schema[:time_modulo]
      end

      @url = Time.at(t).strftime(@url_schema[:url_schema])
      @logger.info("#{@desc} - Url generated #{@url}")
      return @url
    end

    def download_to_temp
      time_pre = Time.now

      WebcamDownloader::WgetProxy.instance.download_file(
        @url,
        @path_temporary,
        { ref: @referer }
      )

      @download_count = @download_count.to_i + 1
      @download_time_cost_last = Time.now - time_pre
      @download_time_cost_total = @download_time_cost_total.to_f + @download_time_cost_last
      @download_time_cost_max = @download_time_cost_last if @download_time_cost_last > @download_time_cost_max

      @logger.debug("#{@desc} - Downloaded: count #{@download_count}, cost #{@download_time_cost_last}")

      @last_downloaded_temporary_at = Time.now.to_i

      @last_downloaded_temporary_size = File.size(@path_temporary)
      @last_downloaded_temporary_digest = Digest::MD5.hexdigest(File.read(@path_temporary))
      @last_downloaded_temporary_mtime = File.new(@path_temporary).mtime
    end

    def downloaded_file_is_empty?
      unless File.exists?(@path_temporary)
        @logger.debug("#{@desc} - Downloaded file not exists")
        return true
      end

      if 0 == File.size(@path_temporary)
        @logger.debug("#{@desc} - Downloaded file 0 size")
        return true
      end

      return false
    end

    def downloaded_file_is_equal_to_previous?
      return false if @latest_downloaded_size.nil? or @latest_downloaded_digest.nil?
      return false unless @latest_downloaded_size == @last_downloaded_temporary_size
      return false unless @latest_downloaded_digest == @last_downloaded_temporary_digest

      @logger.debug("#{@desc} - Downloaded file is identical as previously stored")
      return true
    end

    def mark_temp_image_as_latest
      @latest_downloaded_time = Time.now
      @latest_downloaded_path = @path_temporary
      @latest_downloaded_size = File.size(@latest_downloaded_path)
      @latest_downloaded_digest = Digest::MD5.hexdigest(File.read(@latest_downloaded_path))
      @latest_downloaded_mtime = File.new(@latest_downloaded_path).mtime

      @logger.debug("#{@desc} - Marked as stored in #{@latest_downloaded_path}")
    end

    def process_temp_image_if_needed
      return unless @process_resize
      time_pre = Time.now
      @image_processor.process(self)

      @process_count = @process_count.to_i + 1
      @process_time_cost_last = Time.now - time_pre
      @process_time_cost_total = @process_time_cost_total.to_f + @process_time_cost_last
      @process_time_cost_max = @process_time_cost_last if @process_time_cost_last > @process_time_cost_max

      @logger.debug("#{@desc} - Image processed, count #{@process_count}, cost #{@process_time_cost_last}")
    end

    def move_to_storage
      @storage.store_temporary_image(self)
      @latest_stored_at = Time.now
      @latest_stored_path = @path_store
    end


  end
end