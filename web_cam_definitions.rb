require 'yaml'

urls = YAML::load( File.open( 'defs.yml' ) )
flat_urls = Array.new
urls.each do |u|
  flat_urls += u[:array]
end

load 'web_cam_downloader.rb'
wd = WebCamDownloader.new
wd.urls = flat_urls
wd.make_it_so