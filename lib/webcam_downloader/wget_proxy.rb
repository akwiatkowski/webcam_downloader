$:.unshift(File.dirname(__FILE__))

require 'singleton'

module WebcamDownloader
  class WgetProxy
    include Singleton

    def initialize
      @dns_timeout = 3 # --dns-timeout
      @connect_timeout = 4 # --connect-timeout
      @read_timeout = 4 # --read-timeout

      @retries = 3

      @tmp_file = File.join('tmp', 'tmp.tmp')
    end

    def setup(_downloader, _options={})
      @downloader = _downloader
      @logger = _downloader.logger
      @options = _options
      @verbose = _options[:verbose]
    end

    attr_accessor :verbose

    def verbose?
      @verbose
    end

    def proxy=(ps)
      @proxy = ps
    end

    # Download file/image using wget
    def download_file(url, dest, options = {})
      ref = options[:referer] || url
      add_options = options[:wget_options] || ""

      # http://www.greenberetcd.com/decals/d-401.jpg
      if @proxy
        proxy = " -e use_proxy=yes -e http_proxy=#{@proxy}"
      else
        proxy = ""
      end

      agent = options[:agent] || "Mozilla/5.0 (compatible; MSIE 9.0; Windows NT 6.1; Trident/5.0)"
      command = "wget #{add_options} -t #{@retries} --dns-timeout=#{@dns_timeout} --connect-timeout=#{@connect_timeout} --read-timeout=#{@read_timeout} #{proxy} --quiet --referer=\"#{ref}\" --user-agent=\"#{agent}\" --load-cookies data/cookies.txt --keep-session-cookies --save-cookies data/cookies.txt \"#{url}\" -O#{dest}"

      @logger.debug("Wget proxy command - #{command.to_s.green}")
      `#{command}`
    end

    #def download_and_remove_new(url)
    #  download_file(url, @tmp_file, { wget_options: "-cm" })
    #end

    def download_and_remove(url)
      download_file(url, @tmp_file)
      File.delete(@tmp_file) if File.exists?(@tmp_file)
    end

  end
end