load 'lib/timelapse_generator.rb'
t = KickAssAwesomeTimelapseGenerator.new
t.load_config
t.only_with_coords!
t.only_enabled_for_timelapse!
t.add_to_import_paths('/home/olek/pliki.big/webcam_downloader/pulling/webcam_downloader/pix_part_1')
t.import_all_files
t.calculate_extreme_times