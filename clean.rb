require 'yaml'

urls = YAML::load( File.open( 'config/defs.yml' ) )
flat_urls = Array.new
urls.each do |u|
  flat_urls += u[:array]
end

load 'lib/web_cam_downloader.rb'
wd = WebCamDownloaderOld.new
wd.urls = flat_urls
wd.relocate_files2