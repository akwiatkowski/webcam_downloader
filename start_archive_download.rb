require 'yaml'
require 'webcam_downloader/archive_downloader'
require 'logger'
options = {
  logger_level: Logger::DEBUG
}

b = WebcamDownloader::ArchiveDownloader.new(options)
#b.proxy = "666.666.666.666" # :)
b.setup_desc("lienz")
b.start