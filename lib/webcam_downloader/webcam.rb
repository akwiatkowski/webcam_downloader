$:.unshift(File.dirname(__FILE__))

module WebcamDownloader
  class Webcam
    def initialize(_options, _downloader)
      @options = _options
      @downloader = _downloader
      @storage = _downloader.storage

      @desc = _options[:desc]
      @interval = _options[:interval]
      @pre_url = _options[:pre_url]
      @referer = _options[:ref] || _options[:referer]
      @url = _options[:url]
      @url_schema = _options[:url_schema]

      @temporary = nil
      @last_downloaded_time = nil
      @download_count = 0
      @download_time_cost_total = 0.0
      @last_downloaded_at = nil

    end

    attr_reader :desc, :temporary

    attr_accessor :path_temporary, :path_store


    def make_it_so
      if download_by_interval?
        download!

      end
    end

    def download_by_interval?
      (Time.now.to_i - @last_downloaded_time.to_i >= @interval.to_i)
    end

    def download!
      pre_url_download
      setup_paths
      generate_url
      download_to_temp
      return false if downloaded_file_is_empty?
      return false if downloaded_file_is_equal_to_previous?
      process_temp_image_if_needed

      # TODO

      post_download
    end

    #

    # download temporary and remove
    def pre_url_download
      unless @pre_url.nil?
        WebcamDownloader::WgetProxy.instance.download_and_remove(@pre_url)
      end
    end

    def setup_paths
      @storage.set_paths_for_webcam(self)
    end

    def generate_url
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
      puts "generated url #{@url}"
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
      @last_downloaded_at = Time.now.to_i
    end

    def downloaded_file_is_empty?
      return true unless File.exists?(@path_temporary)
      return true if 0 == File.size(@path_temporary)
      return false
    end

    def downloaded_file_is_equal_to_previous?
      # TODO
      return false
    end

    def process_temp_image_if_needed
      # resizing
      puts "resizing image #{u[:new_downloaded]}"
      u[:new_proc_filename] = u[:new_downloaded_processed]
      command = "convert \"#{u[:new_downloaded]}\" -resize '1920x1080>' -quality #{@jpeg_quality}% \"#{u[:new_proc_filename]}\""
      time_pre = Time.now
      `#{command}`
      u[:process_count] = u[:process_count].to_i + 1
      u[:process_time_cost] = Time.now - time_pre
      u[:process_time_cost_total] = u[:process_time_cost_total].to_f + u[:process_time_cost]

      # remove original
      `rm #{u[:new_downloaded]}`
    end

    def post_download!
      @last_downloaded_time = Time.now
      @last_downloaded_path = @path_store
      @last_downloaded_size = File.size(@last_downloaded_path)
      @last_downloaded_digest = Digest::MD5.hexdigest(File.read(@last_downloaded_path))
      @last_downloaded_mtime = File.new(@last_downloaded_path).mtime
    end


  end
end