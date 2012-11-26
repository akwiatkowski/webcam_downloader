$:.unshift(File.dirname(__FILE__))

require 'singleton'

module WebcamDownloader
  class WgetProxy
    include Singleton

    def initialize
      @dns_timeout = 2 # --dns-timeout
      @connect_timeout = 3 # --connect-timeout
      @read_timeout = 10 # --read-timeout

      @tmp_file = File.join('tmp', 'tmp.tmp')
    end

    def setup(_downloader, _options={ })
      @downloader = _downloader
      @logger = _downloader.logger
      @options = _options
      @verbose = _options[:verbose]
    end

    attr_accessor :verbose

    def verbose?
      @verbose
    end

    # Download file/image using wget
    def download_file(url, dest, options = { })
      ref = options[:referer] || url
      agent = options[:agent] || "Internet Explorer 8.0"
      command = "wget --dns-timeout=#{@dns_timeout} --connect-timeout=#{@connect_timeout} --read-timeout=#{@read_timeout} --quiet --referer=\"#{ref}\" --user-agent=\"#{agent}\" --load-cookies data/cookies.txt --keep-session-cookies --save-cookies data/cookies.txt \"#{url}\" -O#{dest}"
      @logger.debug("Wget proxy command - #{command}")
      `#{command}`
    end

    def download_and_remove(url)
      download_file(url, @tmp_file)
      File.delete(@tmp_file)
    end

  end
end