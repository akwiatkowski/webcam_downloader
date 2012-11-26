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

      @temporary = nil
      @last_downloaded_time = nil
      @download_count = 0
      @download_time_cost_total = 0.0
      @last_downloaded_at = nil

    end

    attr_reader :desc, :temporary

    attr_accessor :path_temporary, :path_temporary_process, :path_store, :path_store_processed


    def make_it_so
      if download_by_interval?
        download!
        post_download!
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
    end

    #

    def post_download!
      @last_downloaded_time = Time.now
    end

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
      # TODO
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


  end
end