$:.unshift(File.dirname(__FILE__))

require 'singleton'

module WebcamDownloader
  class WgetProxy
    include Singleton

    def initialize(_options={ })
      @options = _options
      @verbose = _options[:verbose]

      @dns_timeout = 2 # --dns-timeout
      @connect_timeout = 3 # --connect-timeout
      @read_timeout = 10 # --read-timeout
    end

    def verbose?
      @verbose
    end

    # Download file/image using wget
    def download_file(url, dest, options = { })
      ref = options[:ref] || url
      agent = options[:agent] || "Internet Explorer 8.0"
      command = "wget --dns-timeout=#{@dns_timeout} --connect-timeout=#{@connect_timeout} --read-timeout=#{@read_timeout} --quiet --referer=\"#{ref}\" --user-agent=\"#{agent}\" --load-cookies data/cookies.txt --keep-session-cookies --save-cookies data/cookies.txt \"#{url}\" -O#{dest}"
      puts command if verbose?
      `#{command}`
    end

  end
end