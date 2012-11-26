$:.unshift(File.dirname(__FILE__))

module WebcamDownloader
  class ImageProcessor
    def initialize(_downloader, _options = { })
      @options = _options
      @downloader = _downloader
      @logger = _downloader.logger

      @jpeg_quality = 88
      @resolution = "1920x1080"
    end

    def process(webcam)
      jpeg_quality = webcam.jpeg_quality || @jpeg_quality
      @logger.debug("#{webcam.desc} - Resize to #{@resolution}, quality #{jpeg_quality}")
      command = "convert \"#{webcam.temporary}\" -resize '#{@resolution}>' -quality #{jpeg_quality}% \"#{webcam.path_temporary_processed}\""
      `#{command}`
      File.delete(webcam.temporary)
      File.rename(webcam.path_temporary_processed, webcam.temporary)
    end

  end
end