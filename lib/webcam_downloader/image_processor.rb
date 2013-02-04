$:.unshift(File.dirname(__FILE__))

module WebcamDownloader
  class ImageProcessor
    def initialize(_downloader, _options = { })
      @options = _options
      @downloader = _downloader
      @logger = _downloader.logger

      @jpeg_quality = 84
      @resolution = "1920x1080"
    end

    def process(webcam)
      # not exists
      return false if not File.exists?(webcam.path_temporary)

      # used for comparison
      webcam.pre_processing_file_size_last = File.size(webcam.path_temporary).to_f / 1024.0

      jpeg_quality = webcam.jpeg_quality || @jpeg_quality
      @logger.debug("#{webcam.desc.to_s.yellow} - Resize to #{@resolution.to_s.red}, quality #{jpeg_quality.to_s.blue}")
      command = "convert \"#{webcam.path_temporary}\" -resize '#{@resolution}>' -quality #{jpeg_quality}% \"#{webcam.path_temporary_processed}\""
      `#{command}`
      File.delete(webcam.path_temporary) if File.exists?(webcam.path_temporary)

      # can't convert file
      return false if not File.exists?(webcam.path_temporary_processed)

      File.rename(webcam.path_temporary_processed, webcam.path_temporary)
      return true
    end

  end
end