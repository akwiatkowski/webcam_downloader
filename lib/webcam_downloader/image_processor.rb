$:.unshift(File.dirname(__FILE__))

module WebcamDownloader
  class ImageProcessor
    def initialize(_downloader, _options = {})
      @options = _options
      @downloader = _downloader

      @jpeg_quality = 88
    end

  end
end