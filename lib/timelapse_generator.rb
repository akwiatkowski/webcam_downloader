require 'rubygems'
require 'solareventcalculator'
require 'yaml'
require 'logger'

class KickAssAwesomeTimelapseGenerator
  # :civil # normal day
  # :official # shortest day
  # :nautical # day is longer than :civil
  # :astronomical # longest day
  @@sunset_type = :nautical

  def initialize
    @defs = Array.new
    # this places will be checked for importing images
    @import_paths = Array.new
    @import_paths << '.'
    @import_paths << 'pix'

    @stored_webcams = Hash.new

    @log = Logger.new(STDOUT)
    @log.level = Logger::INFO

    reset_frames
  end

  attr_accessor :log
  attr_reader :defs

  # load webcam configuration from config file
  def load_config(_filename = 'config/defs.yml')
    urls = YAML::load(File.open(_filename))
    urls.each do |u|
      @defs += u[:array]
    end
    @defs.uniq!
    @log.info "Config file #{_filename} loaded, now #{@defs.size} webcams"
  end

  def only_with_coords!
    @defs = @defs.select { |u| not u[:coord].nil? and not u[:coord][:lat].nil? and not u[:coord][:lon].nil? }
    @log.info "There are only #{@defs.size} webcams with coords (usable for dawn/sunset calculation)"
  end

  def only_enabled_for_timelapse!
    @defs = @defs.select { |u| u[:use_in_timelapse] == true }
    @log.info "There are only #{@defs.size} enabled for timelapse"
  end

  def only_this!(_desc)
    @defs = @defs.select { |u| u[:desc] == _desc }
    @log.info "There are only #{@defs.size} enabled for timelapse"
  end

  # importer can search thought many paths for downloaded images
  def add_to_import_paths(_new_path = '.')
    @import_paths << _new_path
    @import_paths.uniq!
    @log.debug "Path '#{_new_path}' added to list, now #{@import_paths.size} paths"
  end

  def import_all_files
    @import_paths.each do |path|
      @log.info "Searching thought '#{path}'"

      # import
      @defs.each do |u|
        desc = u[:desc]
        base_path = File.join(path, desc)
        # only search if this path exists
        if File.exists?(base_path)
          # here will be Array of webcams
          @stored_webcams[desc] ||= Array.new
          stored_count = 0

          Dir[File.join(base_path, "*.jpg")].each do |f|
            h = Hash.new
            h[:filename] = f
            # supa-dupa-lazy
            h[:time] = Time.at(f[/\d{4,20}/].to_i)
            @stored_webcams[desc] << h
            stored_count += 1
          end
          @log.info " #{stored_count.to_s.rjust(10)}     #{base_path}"
        end

      end
    end

    sort_imported_webcams
  end

  def sort_imported_webcams
    @stored_webcams.keys.each do |desc|
      @stored_webcams[desc] = @stored_webcams[desc].sort { |a, b| a[:time] <=> b[:time] }
    end
  end

  def sunrise(lat, lon, time)
    calc = SolarEventCalculator.new(time, BigDecimal.new(lat.to_s), BigDecimal.new(lon.to_s))
    stime = case @@sunset_type
              when :civil then
                calc.compute_utc_civil_sunrise
              when :official then
                calc.compute_utc_official_sunrise
              when :nautical then
                calc.compute_utc_nautical_sunrise
              when :astronomical then
                calc.compute_utc_astronomical_sunrise
              else
                calc.compute_utc_civil_sunrise
            end
    return stime.localtime if not stime.nil?
    return Time.mktime(time.year, time.month, time.day, 0)
  end

  def sunset(lat, lon, time)
    calc = SolarEventCalculator.new(time, BigDecimal.new(lat.to_s), BigDecimal.new(lon.to_s))
    stime = case @@sunset_type
              when :civil then
                calc.compute_utc_civil_sunset
              when :official then
                calc.compute_utc_official_sunset
              when :nautical then
                calc.compute_utc_nautical_sunset
              when :astronomical then
                calc.compute_utc_astronomical_sunset
              else
                calc.compute_utc_civil_sunset
            end
    return stime.localtime if not stime.nil?
    return Time.mktime(time.year, time.month, time.day, 0) + 24*3600
  end

  def is_day_now?(lat, lon, time)
    _sunrise = sunrise(lat, lon, time)
    _sunset = sunset(lat, lon, time)
    return (time >= _sunrise and time <= _sunset)
  end

  def save
    d = Hash.new
    d["@stored_webcams"] = @stored_webcams

    File.open('data/timelapse.yml', 'w') do |f|
      f.puts d.to_yaml
    end
    @log.debug "Saved"
  end

  def reload
    d = YAML::load(File.open('data/timelapse.yml'))
    @stored_webcams = d["@stored_webcams"]
    @log.debug "Loaded"
  end

  # calculate min/max time for every webcam and for all
  def calculate_extreme_times
    @min_times = Hash.new
    @max_times = Hash.new
    @defs.each do |d|
      desc = d[:desc]
      if @stored_webcams[desc].size > 0
        @min_times[desc] = @stored_webcams[desc].first[:time]
        @max_times[desc] = @stored_webcams[desc].last[:time]
      end
    end
    # calculate for all
    @min_time = @min_times.values.min
    @max_time = @max_times.values.max
    @log.info "Min time #{@min_time}, max time #{@max_time}"
  end

  # sort coords according to time of dawn
  def desc_sorted_by_coords
    _sorted = @defs.sort { |a, b| a[:coord][:lon] <=> b[:coord][:lon] } rescue @defs
    @desc_sorted = _sorted.collect { |a| a[:desc] }
  end

  # get webcam definition by desc
  def def_by_desc(_desc)
    @defs.select { |d| d[:desc] == _desc }.first
  end

  # calculate sunrise/sunset by desc for one day
  def sunrise_and_sunset_by_desc_and_time(_desc, _time)
    webcam_def = def_by_desc(_desc)
    _sunrise = sunrise(webcam_def[:coord][:lat], webcam_def[:coord][:lon], _time)
    _sunset = sunset(webcam_def[:coord][:lat], webcam_def[:coord][:lon], _time)
    return [_sunrise, _sunset]
  end

  # get images from one webcam within time range
  def select_images_by_desc_and_times(_desc, _time_from, _time_to)
    @stored_webcams[_desc].select { |w| w[:time] >= _time_from and w[:time] <= _time_to }.sort { |a, b| a[:time] <=> b[:time] }
  end

  # get the '_limit' of images nearest to '_time'
  def select_images_most_accurate(_desc, _time, _time_range = 10*60, _limit = 100)
    _images = select_images_by_desc_and_times(_desc, _time - _time_range, _time + _time_range)
    _images = _images.sort { |a, b| (a[:time] - _time).abs <=> (b[:time] - _time).abs }
    _images = _images[0, _limit]
    _images = _images.sort { |a, b| a[:time] <=> b[:time] }
    return _images
  end

  # clear frame tables
  def reset_frames
    @frames = Array.new
  end

  ## -- rendering output
  def create_images_list(output_name = nil, absolute_path = true)
    # create symlinks
    Dir.mkdir 'tmp' if not File.exist?('tmp')
    Dir.mkdir 'tmp/timelapse' if not File.exist?('tmp/timelapse')

    @timelapse_output_name = output_name || Time.now.to_i.to_s
    @timelapse_output_file = File.absolute_path("tmp/timelapse/video_#{@timelapse_output_name}.avi")
    @timelapse_images_list_file = File.absolute_path("tmp/timelapse/list_#{@timelapse_output_name}.txt")

    f = File.new(@timelapse_images_list_file, 'w')
    @frames.each_with_index do |t, i|
      _file = t[:filename]
      _file = File.absolute_path(_file) if absolute_path
      f.puts _file
    end
    f.close
  end

  def render_command(_options = { }, preset = nil)
    if preset.to_s == 'HD'
      _options = _options.merge(
        {
          width: 1280,
          height: 720,
          bitrate: 6000
        }
      )
    end

    if preset.to_s == '480p'
      _options = _options.merge(
        {
          width: 854,
          height: 480,
          bitrate: 4000
        }
      )
    end

    width = _options[:width] || 1280
    height = _options[:height] || 720
    ratio = width.to_f / height.to_f
    bitrate = _options[:bitrate] || 6000
    fps = _options[:fps] || 25
    file_list = _options[:file_list] || @timelapse_images_list_file
    output = _options[:output] || @timelapse_output_file

    # -1 true aspect ratio
    # -2 fit into movie size, aspect not maintained
    aspect_ratio_type = _options[:aspect] || -2

    scale_crop_string = "-aspect #{ratio} -vf scale=#{aspect_ratio_type}:#{height},crop=#{width}:#{height} -sws 9 "
    input_string = "\"mf://@#{file_list}\" "
    fps_string = "-mf fps=#{fps} "
    options_string = "-ovc xvid -xvidencopts noqpel:nogmc:trellis:nocartoon:nochroma_me:chroma_opt:lumi_mask:max_iquant=7:max_pquant=7:max_bquant=7:bitrate=#{bitrate}:threads=120 "
    output_string = "-o \"#{output}\" -oac copy "
    command = "mencoder #{input_string}#{fps_string}#{scale_crop_string}#{options_string}#{output_string}"

    return command
  end

  def create_render_command(_options = { }, preset = nil)
    command = render_command(_options, preset)
    save_command_to_file(command, @timelapse_output_name)
  end

  def save_command_to_file(command, name)
    _script_file = File.absolute_path("tmp/timelapse/video_#{name}.sh")
    File.open(_script_file, 'w') do |f|
      f.puts command
    end
  end

  ## -- end of rendering output code

  # add images for timelapse using all images, all webcams, only during the day, day by day
  def add_images_daily_timelapse
    add_images_for_webcams_during_day(@stored_webcams.keys)
  end

  # add images for timelapse using selected webcams, only during the day, day by day
  def add_images_for_webcams_during_day(_descs)
    _descs = [_descs] unless _descs.kind_of?(Array)

    finished = false
    day = 0
    while not finished do
      # loop by time/days, from first_time to

      _descs.keys.each do |_desc|
        # loop by provider
        _time = @min_time + day * 24*3600
        _sunrise, _sunset = sunrise_and_sunset_by_desc_and_time(_desc, _time)
        @log.debug "Adding photos from #{_desc} from #{_sunrise} to #{_sunset}"

        webcams_partial = select_images_by_desc_and_times(_desc, _sunrise, _sunset)
        @log.debug "...added #{webcams_partial.size} images"
        @frames += webcams_partial
      end

      # next day
      day += 1

      # end condition
      if @min_time + day * 24*3600 > @max_time
        finished = true
      end
      @log.info "Added #{@frames.size} images"
    end
  end

  # add images for timelapse using a few (ex. 1) images during noon
  def add_images_noon_everyday_for_webcam(_desc, limit = 1)
    finished = false
    day = 0
    while not finished do
      # loop by time/days, from first_time to

      # loop by provider
      _time = @min_time + day * 24*3600
      _sunrise, _sunset = sunrise_and_sunset_by_desc_and_time(_desc, _time)
      _noon = Time.at((_sunrise.to_i + _sunset.to_i) / 2)
      @log.debug "Adding some photos from #{_desc} from noon #{_noon}"

      webcams_partial = select_images_most_accurate(_desc, _noon, 3600, limit)
      @log.debug "...added #{webcams_partial.size} images"
      @frames += webcams_partial

      # next day
      day += 1

      # end condition
      if @min_time + day * 24*3600 > @max_time
        finished = true
      end
    end

    @log.info "Added #{@frames.size} images"
  end

  # add all images from one webcam, even night shots
  def add_images_for_webcam_whole_day(_desc)
    @frames += select_images_by_desc_and_times(_desc, @min_time, @max_time)
    @log.info "Added #{@frames.size} images"
  end


  ## -- one method to generate timelapse
  # create everything for making separated timelapse per webcam
  #
  # types:
  # * :separated - if true every webcam has separated output video file
  # * :day - if true only images during the day
  # * :all - if true ignore :use_in_timelapse flag in definition
  # * :descs - Array of webcam desc used only
  def generate_separated_movies(_options = { })
    load_config

    only_with_coords! if _options[:only_with_coords!] or _options[:day]
    only_enabled_for_timelapse! if _options[:only_enabled_for_timelapse] or not _options[:all]

    _separated = _options[:separated]
    _only_day = _options[:day] || _options[:only_day]

    # only selected webcams
    if _options[:descs]
      new_defs = Array.new
      _options[:descs].each do |_desc|
        new_defs << def_by_desc(_desc)
      end
      @defs = new_defs
    end

    # adding optional paths
    _options[:paths] ||= Array.new
    _options[:paths].each do |path|
      add_to_import_paths(path)
    end

    _options[:mencoder_options] ||= Hash.new
    _options[:name] ||= Time.now.strftime('%m_%d__%H_%m')
    _name = _options[:name]

    # import images and initial processing
    import_all_files
    calculate_extreme_times
    desc_sorted_by_coords

    @command = ""

    if _separated
      @defs.each do |webcam|
        reset_frames
        _desc = webcam[:desc]

        if _only_day
          add_images_for_webcams_during_day(_desc)
        else
          add_images_for_webcam_whole_day(_desc)
        end

        # create list, command, ...
        create_images_list("#{_name}_#{_desc}")
        @command += render_command(_options[:mencoder_options])
        @command += "\n\n"
      end
    else
      # in one file
      if _only_day
        add_images_daily_timelapse
        create_images_list(_name)
        @command += render_command(_options[:mencoder_options])
        @command += "\n\n"
      else
        # TODO not implemented
      end
    end

    save_command_to_file(@command, _name)
  end
end
