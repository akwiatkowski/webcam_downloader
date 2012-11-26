$:.unshift(File.dirname(__FILE__))

require 'singleton'

module WebcamDownloader
  class WgetProxy
    include Singleton

    def initialize(_options={ })
      @options = _options
      @dns_timeout = 2 # --dns-timeout
      @connect_timeout = 3 # --connect-timeout
      @read_timeout = 10 # --read-timeout
    end

  end
end