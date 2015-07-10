require 'yaml'
require 'webcam_downloader/archive_downloader'
require 'logger'
options = {
  logger_level: Logger::DEBUG
}

b = WebcamDownloader::ArchiveDownloader.new(options)
# use one proxy
#b.proxy = "666.666.666.666"
# or use multiproxy
b.load_and_use_proxies('config/proxies.txt')
b.setup_desc("lienz")
b.start


# proxy test
#"".each_line do |proxy|
#  command = 'wget  -t 1 --dns-timeout=10 --connect-timeout=10 --read-timeout=25  -e use_proxy=yes -e http_proxy=' + proxy.strip + ' --referer="http://www.foto-webcam.eu/webcam/lienz/" --user-agent="Mozilla/5.0 (compatible; MSIE 10.0; Windows NT 6.1; Trident/6.0)" --load-cookies data/cookies.txt --keep-session-cookies --save-cookies data/cookies.txt "http://www.foto-webcam.eu/webcam/lienz/2014/12/31/1400_hu.jpg" -Opix/archived/2014_12/germany_lienz/germany_lienz_1420030800.jpg'
#  puts command
#  `#{command}`
#end