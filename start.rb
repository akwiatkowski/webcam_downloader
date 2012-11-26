require 'yaml'

load 'lib/web_cam_downloader.rb'
wd = WebCamDownloader.new
wd.load_definition_file('config/defs.yml')
wd.make_it_so