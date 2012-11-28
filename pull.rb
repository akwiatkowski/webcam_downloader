require 'yaml'
require 'webcam_downloader'
require 'logger'

wd = WebcamDownloader::Downloader.new(options)
wd.load_all_definition_files
flat_urls = wd.defs

url = "root@192.168.0.7:/opt/webcam_downloader/"
destination = ''
WebCamPuller.make_it_so(flat_urls, url, destination)
