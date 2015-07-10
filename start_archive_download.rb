require 'yaml'
require 'webcam_downloader/archive_downloader'
require 'logger'
options = {
  logger_level: Logger::DEBUG
}

b = WebcamDownloader::ArchiveDownloader.new(options)
# use one proxy
#b.proxy = "666.666.666.666"
# or use multiproxy
b.load_and_use_proxies('config/proxies.txt')
b.setup_desc("lienz")
b.start