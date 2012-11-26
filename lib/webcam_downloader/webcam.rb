$:.unshift(File.dirname(__FILE__))

module WebcamDownloader
  class Webcam
    def initialize(_options, _downloader)
      @options = _options
      @downloader = _downloader
      @storage = _downloader.storage
      @image_processor = _downloader.image_processor
      @presentation = _downloader.presentation
      @logger = _downloader.logger

      @desc = _options[:desc]
      @interval = _options[:interval]
      @pre_url = _options[:pre_url]
      @referer = _options[:ref] || _options[:referer]
      @url = _options[:url]
      @url_schema = _options[:url_schema]
      @process_resize = _options[:resize] || _options[:process_resize]
      @jpeg_quality = _options[:resize_jpg_quality] || _options[:jpg_quality]

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
      @file_size_zero_count = 0
      @file_identical_count = 0

      @stored_file_size_last = 0.0
      @stored_file_size_sum = 0.0
      @stored_file_size_count = 0
      @stored_file_size_max = 0.0

    end

    attr_reader :desc, :jpeg_quality
    attr_reader :download_count, :process_count, :file_size_zero_count, :file_identical_count
    attr_reader :download_time_cost_total, :process_time_cost_total
    attr_reader :stored_file_size_last, :stored_file_size_sum, :stored_file_size_count, :stored_file_size_max
    attr_reader :process_resize
    attr_reader :latest_stored_at, :last_downloaded_temporary_at

    attr_accessor :path_temporary, :path_temporary_processed, :path_store

    # time cost stats

    def avg_download_cost
      c = self.download_count
      c = 1 if c == 0 # div by 0
      return self.download_time_cost_total / c.to_f
    end

    def avg_process_cost
      c = self.process_count
      c = 1 if c == 0 # div by 0
      return self.process_time_cost_total / c.to_f
    end

    def avg_cost
      avg_download_cost + avg_process_cost
    end

    def last_download_cost
      self.download_time_cost_last
    end

    def last_process_cost
      self.process_time_cost_last
    end

    def last_cost
      last_download_cost + last_process_cost
    end

    def max_download_cost
      self.download_time_cost_max
    end

    def max_process_cost
      self.process_time_cost_last
    end

    def max_cost
      max_download_cost + max_process_cost
    end

    def avg_file_size
      c = self.stored_file_size_count
      c = 1 if c == 0
      return @stored_file_size_sum.to_f / c.to_f
    end


    #

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
        @file_size_zero_count += 1
        return true
      end

      if 0 == File.size(@path_temporary)
        @logger.debug("#{@desc} - Downloaded file 0 size")
        @file_size_zero_count += 1
        return true
      end

      return false
    end

    def downloaded_file_is_equal_to_previous?
      return false if @latest_downloaded_size.nil? or @latest_downloaded_digest.nil?
      return false unless @latest_downloaded_size == @last_downloaded_temporary_size
      return false unless @latest_downloaded_digest == @last_downloaded_temporary_digest

      @logger.debug("#{@desc} - Downloaded file is identical as previously stored")
      @file_identical_count += 1
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
      @presentation.after_image_store(self)
      @latest_stored_at = Time.now
      @latest_stored_path = @path_store

      @stored_file_size_last = File.size(@path_store).to_f / 1024.0
      @stored_file_size_sum += @stored_file_size_last
      @stored_file_size_count += 1
      @stored_file_size_max = @stored_file_size_last if @stored_file_size_last > @stored_file_size_max

    end


  end
end