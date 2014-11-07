require 'yaml'
require 'webcam_downloader'
require 'logger'
options = {
  logger_level: Logger::DEBUG,
  workers_count: 6,
  development: true
}
#options[:logger_level] = Logger::DEBUG

wd = WebcamDownloader::Downloader.new(options)
wd.load_definition_file('config/germany.yml')
#wd.load_all_definition_files

#wd.make_it_so
#puts wd.defs.inspect

wd.prepare_loop
wd.inside_loop
