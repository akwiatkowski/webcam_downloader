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
    @desc_sorted = @defs.sort { |a, b| a[:coord][:lon] <=> b[:coord][:lon] }.collect { |a| a[:desc] }
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

  def select_images_by_desc_and_times(_desc, _time_from, _time_to)
    @stored_webcams[_desc].select { |w| w[:time] >= _time_from and w[:time] <= _time_to }.sort { |a, b| a[:time] <=> b[:time] }
  end

  # create timelapse using all images, only during the day
  def generate_day_timelapse
    # movie frames
    @frames = Array.new

    finished = false
    day = 0
    while not finished do
      # loop by time/days, from first_time to

      @stored_webcams.keys.each do |_desc|
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

  def create_images_list(absolute_path = true)
    # create symlinks
    Dir.mkdir 'tmp' if not File.exist?('tmp')
    Dir.mkdir 'tmp/timelapse' if not File.exist?('tmp/timelapse')

    @timelapse_output_name = Time.now.to_i.to_s
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

  def create_render_command(_options = { }, preset = nil)
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
    command_youtube = "mencoder #{input_string}#{fps_string}#{scale_crop_string}#{options_string}#{output_string}"

    @timelapse_script_file = File.absolute_path("tmp/timelapse/video_#{@timelapse_output_name}.sh")
    File.open(@timelapse_script_file, 'w') do |f|
      f.puts command_youtube
    end
  end
end
