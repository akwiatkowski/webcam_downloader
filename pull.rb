require 'yaml'

load 'lib/web_cam_downloader.rb'
load 'lib/web_cam_puller.rb'
flat_urls = WebCamDownloader.load_and_flatten_definitions('config/defs.yml')
url = "root@192.168.0.7:/opt/webcam_downloader/"
destination = ''
WebCamPuller.make_it_so(flat_urls, url, destination)