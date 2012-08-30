require 'yaml'

load 'lib/web_cam_downloader.rb'
flat_urls = WebCamDownloader.load_and_flatten_definitions('config/defs.yml')
wd = WebCamDownloader.new
wd.urls = flat_urls
wd.make_it_so