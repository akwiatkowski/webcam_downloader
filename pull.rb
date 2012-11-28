require 'yaml'
require 'webcam_downloader'
require 'logger'

wd = WebcamDownloader::Downloader.new
wd.load_all_definition_files
flat_urls = wd.defs

flat_urls = [flat_urls.first]

url = "root@192.168.0.7:/opt/webcam_downloader/"
destination = ''
WebcamDownloader::Puller.make_it_so(flat_urls, url, destination)
