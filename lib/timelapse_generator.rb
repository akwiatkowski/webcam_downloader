require 'rubygems'
require 'solareventcalculator'
require 'yaml'

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
  end

  attr_reader :defs

  # load webcam configuration from config file
  def load_config(_filename = 'config/defs.yml')
    urls = YAML::load(File.open(_filename))
    urls.each do |u|
      @defs += u[:array]
    end
    @defs.uniq!
    puts "Config file #{_filename} loaded, now #{@defs.size} webcams"
  end

  def only_with_coords!
    @defs = @defs.select { |u| not u[:coord].nil? and not u[:coord][:lat].nil? and not u[:coord][:lon].nil? }
    puts "There are only #{@defs.size} webcams with coords (usable for dawn/sunset calculation)"
  end

  def only_enabled_for_timelapse!
    @defs = @defs.select { |u| u[:use_in_timelapse] == true }
    puts "There are only #{@defs.size} enabled for timelapse"
  end

  # importer can search thought many paths for downloaded images
  def add_to_import_paths(_new_path = '.')
    @import_paths << _new_path
    @import_paths.uniq!
    puts "Path '#{_new_path}' added to list, now #{@import_paths.size} paths"
  end

  def import_all_files
    @import_paths.each do |path|
      puts "Searching throught '#{path}'"

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
          puts " #{stored_count.to_s.rjust(10)}     #{base_path}"
        end

      end
    end

    sort_imported_webcams
  end

  def sort_imported_webcams
    @stored_webcams.keys.each do |desc|
      @stored_webcams[desc] = @stored_webcams[desc].sort{|a,b| a[:time] <=> b[:time]}
    end
  end

  def sunrise(lat, lon, time)
    #puts "#{lat} #{lon} #{time}"
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
    puts "Saved"
  end

  def reload
    d = YAML::load(File.open('data/timelapse.yml'))
    @stored_webcams = d["@stored_webcams"]
    puts "Loaded"
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
    puts "Min time #{@min_time}, max time #{@max_time}"
  end

  # to refactor
  # if u[:night] or is_day_now?(u[:coord][:lat], u[:coord][:lon], h[:time])


  def generate_timelapse_script
    first_time = nil
    last_time = nil
    puts "Getting first and last time"

    keys_ordered = @us.sort { |a, b| a[:coord][:lon] <=> b[:coord][:lon] }.collect { |a| a[:desc] }

    #@stored_webcams.keys.each do |k|
    keys_ordered.each do |k|
      sw = @stored_webcams[k]
      if sw.size > 0
        # some providers has no images
        first_time = sw.first[:time] if first_time.nil?
        first_time = sw.first[:time] if first_time > sw.first[:time]

        last_time = sw.last[:time] if last_time.nil?
        last_time = sw.last[:time] if last_time < sw.last[:time]
      end
    end
    puts "First time at #{first_time}"
    puts "Last time at #{last_time}"

    # movie frames
    @frames = Array.new

    # TODO maybe something to sort by providers/webcams?

    finished = false
    day = 0
    while not finished do
      # loop by time/days, from first_time to

      @stored_webcams.keys.each do |k|
        # loop by provider

        # calculate sunrise and sunset
        webcam_def = @defs.select { |d| d[:desc] == k }.first
        lat = webcam_def[:coord][:lat]
        lon = webcam_def[:coord][:lon]
        time = first_time + day * 24*3600
        _sunrise = sunrise(lat, lon, time)
        _sunset = sunset(lat, lon, time)

        puts "Adding photos from #{k} from #{_sunrise} to #{_sunset}"
        webcams_partial = @stored_webcams[k].select { |w| w[:time] >= _sunrise and w[:time] <= _sunset }
        webcams_partial = webcams_partial.sort { |a, b| a[:time] <=> b[:time] }
        puts "...added #{webcams_partial.size} images"

        @frames += webcams_partial.collect { |w| w[:filename] }
      end

      # next day
      day += 1

      # end condition
      if first_time + day * 24*3600 > last_time
        finished = true
      end
    end

    puts "Finished with #{@frames.size} images"
    File.open('timelapse_frames.yml', 'w') do |f|
      f.puts @frames.to_yaml
    end
    puts "Frames saved"

    # create symlinks
    Dir.mkdir 'tmp' if not File.exist?('tmp')
    Dir.mkdir 'tmp/timelapse' if not File.exist?('tmp/timelapse')

    f = File.new('tmp/timelapse/list.txt', 'w')
    @frames.each_with_index do |t, i|
      f.puts t
    end
    f.close

    # HD
    width = 1280
    height = 720
    ratio = width.to_f / height.to_f
    # ratio - "16:9"
    bitrate = 6000
    fps = 25

    # -1 true aspect ratio
    # -2 fit into movie size, aspect not maintained
    aspect_ratio_ @@sunset_type = -2

    scale_crop_string = "-aspect #{ratio} -vf scale=#{aspect_ratio_ @@sunset_type}:#{height},crop=#{width}:#{height} -sws 9 "
    input_string = "\"mf://@tmp/timelapse/list.txt\" "
    fps_string = "-mf fps=#{fps} "
    youtube_string = "-ovc xvid -xvidencopts noqpel:nogmc:trellis:nocartoon:nochroma_me:chroma_opt:lumi_mask:max_iquant=7:max_pquant=7:max_bquant=7:bitrate=#{bitrate}:threads=120 "
    youtube_output_string = "-o video_yhd.avi -oac copy "

    command_youtube = "mencoder #{input_string}#{fps_string}#{scale_crop_string}#{youtube_string}#{youtube_output_string}"
    puts "# youtube hd", command_youtube

    # 480p
    width = 854
    height = 480
    ratio = width.to_f / height.to_f
    bitrate = 4000

    scale_crop_string = "-aspect #{ratio} -vf scale=#{aspect_ratio_ @@sunset_type}:#{height},crop=#{width}:#{height} -sws 9 "
    youtube_string = "-ovc xvid -xvidencopts noqpel:nogmc:trellis:nocartoon:nochroma_me:chroma_opt:lumi_mask:max_iquant=7:max_pquant=7:max_bquant=7:bitrate=#{bitrate}:threads=120 "
    youtube_output_string = "-o video_1.avi -oac copy "

    command_youtube = "mencoder #{input_string}#{fps_string}#{scale_crop_string}#{youtube_string}#{youtube_output_string}"
    puts "# youtube 480p", command_youtube


    #command_vimeo = "mencoder \"mf://@tmp/timelapse/list.txt\" -mf fps=25:w=#{width}:h=#{height} -profile x264-vimeo -o video_vimeo.avi"
    #puts "# youube 480p", command_youtube

    #command_youtube = "mencoder \"mf://@tmp/timelapse/list.txt\" -mf fps=25:w=#{width}:h=#{height} -sws 9 -vf scale=#{width}:#{height} -aspect #{ratio} -ovc xvid -xvidencopts noqpel:nogmc:trellis:nocartoon:nochroma_me:chroma_opt:lumi_mask:max_iquant=7:max_pquant=7:max_bquant=7:bitrate=#{bitrate}:threads=120 -o video_1.avi -oac copy"
    #puts "# vimeo", command_vimeo

  end

end
#
## take some time, load images info and check sunrise/sunset
#process = true
#
#t = KickAssAwesomeTimelapseGenerator.new
#if process
#  t.import_files
#  t.save
#else
#  t.reload
#end
#
#t.generate_timelapse_script

