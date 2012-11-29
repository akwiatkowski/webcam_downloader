$:.unshift(File.dirname(__FILE__))

require 'digest/md5'
require 'webcam_downloader/image_processor'
require 'webcam_downloader/presentation'
require 'webcam_downloader/storage'
require 'webcam_downloader/wget_proxy'
require 'webcam_downloader/webcam'
require 'webcam_downloader/downloader'

require 'webcam_downloader/puller'

def fl_to_s(fl, level = 2)
  (fl.to_f * (10.0 ** level)).round.to_f / (10.0 ** level)
end

module WebcamDownloader
end

