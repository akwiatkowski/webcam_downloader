require 'yaml'
require 'webcam_downloader'
require 'logger'
options = {
  logger_level: Logger::INFO
}
wd = WebcamDownloader::Downloader.new(options)
wd.load_definition_file('config/defs.yml')
wd.make_it_so