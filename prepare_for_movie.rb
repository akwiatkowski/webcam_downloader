require 'rubygems'
require 'solareventcalculator'
require 'yaml'

class KickAssAwesomeTimelapseGenerator

  PATH = '/home/olek/pliki.big/webcam_downloader/pulling/webcam_downloader'

  def initialize
    urls = YAML::load(File.open('defs.yml'))
    @defs = Array.new
    urls.each do |u|
      @defs += u[:array]
    end
  end

  attr_reader :defs

  def import_files
    # select only defs with coords
    us = defs.select { |u| not u[:coord].nil? and u[:coord][:enabled] == true and not u[:coord][:lat].nil? and not u[:coord][:lon].nil? }
    puts "Only #{us.size} webcams has coords from #{defs.size}"

    puts "Importing webcams"
    @stored_webcams = Hash.new

    us.each do |u|
      desc = u[:desc]
      # here will be Array of webcams
      @stored_webcams[desc] = Array.new
      not_stored_count = 0

      Dir[File.join(PATH, "pix", desc, "*.jpg")].each do |f|
        h = Hash.new
        h[:filename] = f
        # supa-dupa-lazy
        h[:time] = Time.at(f[/\d{4,20}/].to_i)

        # normally only day images are interesting
        # unless there is :night => true in defs

        if u[:night] or is_day_now?(u[:coord][:lat], u[:coord][:lon], h[:time])
          @stored_webcams[desc] << h
        else
          not_stored_count += 1
        end

      end

      # must be sorted
      @stored_webcams[desc] = @stored_webcams[desc].sort { |a, b| a[:time] <=> b[:time] }
      puts "Imported for #{desc} #{@stored_webcams[desc].size}, not imported #{not_stored_count}"
    end
  end

  def sunrise(lat, lon, time)
    #puts "#{lat} #{lon} #{time}"
    calc = SolarEventCalculator.new(time, BigDecimal.new(lat.to_s), BigDecimal.new(lon.to_s))
    return calc.compute_utc_civil_sunrise.localtime
  end

  def sunset(lat, lon, time)
    calc = SolarEventCalculator.new(time, BigDecimal.new(lat.to_s), BigDecimal.new(lon.to_s))
    return calc.compute_utc_civil_sunset.localtime
  end

  def is_day_now?(lat, lon, time)
    _sunrise = sunrise(lat, lon, time)
    _sunset = sunset(lat, lon, time)
    # puts "  #{_sunrise} - #{_sunset}"
    return (time >= _sunrise and time <= _sunset)
  end

  def save
    d = Hash.new
    d["@stored_webcams"] = @stored_webcams

    File.open('timelapse.yml', 'w') do |f|
      f.puts d.to_yaml
    end
    puts "Saved"
  end

  def reload
    d = YAML::load(File.open('timelapse.yml'))
    @stored_webcams = d["@stored_webcams"]
    puts "Loaded"
  end

  def generate_timelapse_script
    first_time = nil
    last_time = nil
    puts "Getting first and last time"

    @stored_webcams.keys.each do |k|
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

    width = 1280
    height = 720
    ratio = width.to_f / height.to_f
    bitrate = 6000

    command_youtube = "mencoder \"mf://@tmp/timelapse/list.txt\" -mf fps=25:w=#{width}:h=#{height} -sws 9 -vf scale=#{width}:#{height} -aspect #{ratio} -ovc xvid -xvidencopts noqpel:nogmc:trellis:nocartoon:nochroma_me:chroma_opt:lumi_mask:max_iquant=7:max_pquant=7:max_bquant=7:bitrate=#{bitrate}:threads=120 -o video_1.avi -oac copy"
    puts "# youtbe hd", command_youtube

    width = 854
    height = 480
    ratio = width.to_f / height.to_f
    bitrate = 4000

    command_vimeo = "mencoder \"mf://@tmp/timelapse/list.txt\" -mf fps=25:w=#{width}:h=#{height} -profile x264-vimeo -o video_vimeo.avi"
    puts "# youube 480p", command_youtube

    command_youtube = "mencoder \"mf://@tmp/timelapse/list.txt\" -mf fps=25:w=#{width}:h=#{height} -sws 9 -vf scale=#{width}:#{height} -aspect #{ratio} -ovc xvid -xvidencopts noqpel:nogmc:trellis:nocartoon:nochroma_me:chroma_opt:lumi_mask:max_iquant=7:max_pquant=7:max_bquant=7:bitrate=#{bitrate}:threads=120 -o video_1.avi -oac copy"
    puts "# vimeo", command_vimeo

  end

end

# take some time, load images info and check sunrise/sunset
process = true

t = KickAssAwesomeTimelapseGenerator.new
if process
  t.import_files
  t.save
else
  t.reload
end

t.generate_timelapse_script

