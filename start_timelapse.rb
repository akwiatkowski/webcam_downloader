require 'yaml'
require 'webcam_downloader/timelapse_builder'
require 'logger'
options = {
  logger_level: Logger::DEBUG
}

b = WebcamDownloader::TimelapseBuilder.new(options)
#b.add_root_path('/media/f35c3848-ec12-4e09-bc60-f5622b3015f5/backup/webcam_downloader')
b.add_root_path(".")
b.analyze_webcam_images_for('austria_Kufsteinblick')