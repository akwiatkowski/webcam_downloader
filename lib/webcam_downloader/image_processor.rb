$:.unshift(File.dirname(__FILE__))

module WebcamDownloader
  class ImageProcessor
    def initialize(_downloader, _options = { })
      @options = _options
      @downloader = _downloader
      @logger = _downloader.logger

      @jpeg_quality = 88
    end

    def process(webcam)
      # resizing
      puts "resizing image #{webcam.temporary}"
      command = "convert \"#{webcam.temporary}\" -resize '1920x1080>' -quality #{@jpeg_quality}% \"#{webcam.path_temporary_processed}\""
      time_pre = Time.now
      `#{command}`
      File.delete(webcam.temporary)
      File.rename(webcam.path_temporary_processed, webcam.temporary)
    end

  end
end