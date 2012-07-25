load 'lib/timelapse_generator.rb'
t = KickAssAwesomeTimelapseGenerator.new
t.generate_separated_movies(
  {
    all: true,
    #descs: ['stawy'],
    separated: true,
    day: false,
    paths: [
      '/home/olek/pliki.big/webcam_downloader/pulling/webcam_downloader/pix_part_1',
      '/home/olek/pliki.big/webcam_downloader/pulling/webcam_downloader/pix'
    ]
  })

return 0
#t.log.level = Logger::DEBUG
t.load_config
t.only_with_coords!
t.only_enabled_for_timelapse!
t.add_to_import_paths('/home/olek/pliki.big/webcam_downloader/pulling/webcam_downloader/pix_part_1')
t.add_to_import_paths('/home/olek/pliki.big/webcam_downloader/pulling/webcam_downloader/pix')
t.import_all_files
t.calculate_extreme_times
t.desc_sorted_by_coords

# many timelapse types
#t.add_images_daily_timelapse
t.add_images_noon_everyday_for_webcam('stawy')

t.create_images_list
t.create_render_command