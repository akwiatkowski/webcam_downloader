load 'lib/timelapse_generator.rb'
t = KickAssAwesomeTimelapseGenerator.new
#t.log.level = Logger::DEBUG
t.load_config
t.only_with_coords!
t.only_enabled_for_timelapse!
t.add_to_import_paths('/home/olek/pliki.big/webcam_downloader/pulling/webcam_downloader/pix_part_1')
t.add_to_import_paths('/home/olek/pliki.big/webcam_downloader/pulling/webcam_downloader/pix')
t.import_all_files
t.calculate_extreme_times
t.desc_sorted_by_coords

t.generate_day_timelapse
t.create_images_list
t.create_render_command