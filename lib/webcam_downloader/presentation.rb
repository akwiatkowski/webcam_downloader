$:.unshift(File.dirname(__FILE__))

module WebcamDownloader
  class Presentation

    def initialize(_downloader, _options = { })
      @downloader = _downloader
      @options = _options
      @logger = @downloader.logger
    end

    def after_loop_cycle
      @logger.debug("Presentation - after cycle")
    end

  end
end