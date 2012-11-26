$:.unshift(File.dirname(__FILE__))

module WebcamDownloader
  class Webcam
    def initialize(_options, _downloader)
      @options = _options
      @downloader = _downloader
      @desc = _options[:desc]
    end

    attr_reader :desc
  end
end