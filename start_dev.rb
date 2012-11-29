require 'yaml'
require 'webcam_downloader'
require 'logger'
options = {
  logger_level: Logger::INFO,
  workers_count: 6,
  development: true
}
#options[:logger_level] = Logger::DEBUG

wd = WebcamDownloader::Downloader.new(options)
#wd.load_definition_file('config/defs.yml')
#wd.load_definition_file('config/part_2012_11_27.yml')
#wd.load_definition_file('config/part_2012_11_28.yml')
wd.load_all_definition_files
wd.make_it_so