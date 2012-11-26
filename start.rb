require 'yaml'
require 'webcam_downloader'
wd = WebcamDownloader::Downloader.new
wd.load_definition_file('config/defs.yml')
wd.make_it_so