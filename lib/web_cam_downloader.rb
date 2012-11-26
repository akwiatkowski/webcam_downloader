require 'digest/md5'

class WebCamDownloader
  attr_accessor :urls

  def initialize(_options={ })
    @options = _options

    # processing image
    @jpeg_quality = 88

    @sleep_interval = 5

    @dns_timeout = 2 # --dns-timeout
    @connect_timeout = 3 # --connect-timeout
    @read_timeout = 10 # --read-timeout

    Dir.mkdir('tmp') if not File.exist?('tmp')
    Dir.mkdir('data') if not File.exist?('data')

    # time cost of all cycles, for stats and optim. only
    @time_stats = Array.new
    @started_at = Time.now
  end

  def verbose?
    @options[:verbose]
  end

  # Prepare directories for images
  def prepare_directories
    f = 'pix'
    Dir.mkdir(f) unless File.exists?(f)
    # latest
    Dir.mkdir('latest') unless File.exists?('latest')

    prepare_monthly_directories
  end

  def prepare_monthly_directories
    mp = Time.now.strftime('%Y_%m')
    return if @monthly_prefix == mp

    # monthly dir
    f = "pix/#{mp}"
    Dir.mkdir(f) unless File.exists?(f)

    # dir per webcam
    urls.each_with_index do |u, i|
      f = "pix/#{mp}/#{u[:desc]}"
      Dir.mkdir(f) unless File.exists?(f)
    end

    @monthly_prefix = mp
  end

  # Download file/image using wget
  def download_file(url, dest, options = { })
    ref = options[:ref] || url
    agent = options[:agent] || "Internet Explorer 8.0"
    command = "wget --dns-timeout=#{@dns_timeout} --connect-timeout=#{@connect_timeout} --read-timeout=#{@read_timeout} --quiet --referer=\"#{ref}\" --user-agent=\"#{agent}\" --load-cookies data/cookies.txt --keep-session-cookies --save-cookies data/cookies.txt \"#{url}\" -O#{dest}"
    puts command if verbose?
    `#{command}`
  end

  def image_set_paths(u)
    u[:temporary] = "tmp/#{u[:desc]}_#{u[:desc]}_#{Time.now.to_i}.jpg.tmp"
    u[:new_downloaded_pre_process] = "tmp/#{u[:desc]}_#{u[:desc]}_#{Time.now.to_i}_pre_proc.jpg.tmp"
    u[:new_downloaded] = "pix/#{@monthly_prefix}/#{u[:desc]}/#{u[:desc]}_#{Time.now.to_i}.jpg"
    u[:new_downloaded_processed] = "pix/#{@monthly_prefix}/#{u[:desc]}/#{u[:desc]}_#{Time.now.to_i}_proc.jpg"

    # stored in other location for easier rsync usage
    if u[:resize] == true
      u[:new_downloaded] = u[:new_downloaded_pre_process]
    end
  end

  # sort files in proper dirs
  def relocate_files
    _count = 0
    _interval = 100

    Dir['./**/*.jpg'].each do |f|
      res = relocate_filename(f)
      count += 1 if res == true

      if (_count % _interval) == 0
        puts "moved #{_count} files"
      end
    end

    puts "done #{_count} files"
  end

  # sort files in proper dirs
  def relocate_files2(path = 'pix')
    _count = 0
    _interval = 100

    self.urls.each_with_index do |u, i|
      base_path = File.join(path, u[:desc])
      puts "processing #{u[:desc]}"
      Dir[File.join(base_path, "*.jpg")].each do |f|
        res = relocate_filename(f)
        _count += 1 if res == true

        if (_count % _interval) == 0
          puts "moved #{_count} files"
        end
      end
    end
  end

  def relocate_filename(f)
    if f =~ /\/latest\//
      # symlink - ignore
    elsif f =~ /\/([^\/]+)_(\d+)(_proc)*\.jpg/
      # proper filename
      if $1.size > 0 and $2.size > 0
        fh = { filename: f, desc: $1, time: Time.at($2.to_i), proc: $3 }

        dn = "pix/#{fh[:time].strftime('%Y_%m')}"
        Dir.mkdir(dn) unless File.exists?(dn)
        dn = "pix/#{fh[:time].strftime('%Y_%m')}/#{fh[:desc]}"
        Dir.mkdir(dn) unless File.exists?(dn)

        file_from = fh[:filename]
        file_to = "#{dn}/#{fh[:desc]}_#{fh[:time].to_i}#{fh[:proc]}.jpg"

        if File.absolute_path(file_from) == File.absolute_path(file_to)
          # do nothing
        else
          command = "mv \"#{file_from}\" \"#{file_to}\" "
          res = `#{command}`
          if res.size > 0
            puts res, command
          else
            return true
          end
        end
      else
        puts "ERROR1 #{f}"
        return false
      end
    else
      puts "ERROR2 #{f}"
      return false
    end
  end

# Start downloading images
  def make_it_so
    prepare_directories

    j = 0
    loop do
      # super monthly separation
      prepare_monthly_directories

      pre_loop_time = Time.now

      # super loop
      self.urls.each_with_index do |u, i|
        if (Time.now.to_i - u[:last_downloaded_time].to_i >= u[:interval].to_i)

          desc = u[:desc]
          image_set_paths(u)

          if not u[:pre_url].nil?
            # download temporary and remove
            download_file(u[:pre_url], 'tmp/tmp.tmp')
            `rm tmp/tmp.tmp`
          end

          # download image
          time_pre = Time.now
          generate_url(u)
          download_file(u[:url], u[:temporary])
          u[:download_count] = u[:download_count].to_i + 1 # nil safe
          u[:download_time_cost] = Time.now - time_pre
          u[:download_time_cost_total] = u[:download_time_cost_total].to_f + u[:download_time_cost]
          u[:last_downloaded_time] = Time.now.to_i

          # check file size, remove empty files
          if remove_empty_file(u[:temporary], u) == false
            # move image to downloaded
            puts "moving #{u[:temporary]} to #{u[:new_downloaded]}"
            `mv "#{u[:temporary]}" "#{u[:new_downloaded]}"`

            # remove if file is identical to downloaded before
            if remove_if_exist(u) == false
              # file wasn't removed
              if u[:resize] == true
                proc_image(u)
                remove_proc_if_exist(u)
              end

              mark_file_size(u)
            end
          end

          # create symlink for latest
          create_latest_symlink(u)

        end
      end

      create_html_page

      # add time stat
      @time_stats << (Time.now - pre_loop_time)

      # write some debug information
      File.open('data/debug.yaml', "w") do |fd|
        fd.write(self.urls.to_yaml)
      end

      File.open('data/time_stats.yaml', "w") do |fd|
        fd.write(@time_stats.to_yaml)
      end

      puts "all is done, sleeping, stage #{j += 1}"
      sleep @sleep_interval
    end


  end

  # Generate url using current time
  def generate_url(u)
    return if u[:url_schema].nil?

    t = Time.now.to_i
    # webcams store image every :time_modulo interval
    if u[:time_modulo]
      t -= t % u[:time_modulo]
    end

    # time offset
    if u[:time_offset]
      t += u[:time_offset].to_i
      t -= u[:time_modulo]
    end

    u[:url] = Time.at(t).strftime(u[:url_schema])
    puts "generated url #{u[:url]}"
    return u[:url]
  end

# remove image which file size is 0
  def remove_empty_file(f, u)
    s = File.size(f)
    if s == 0
      u[:zero_size_count] = u[:zero_size_count].to_i + 1
      u[:zero_size] = true
      puts "removing #{f}, file size = 0"
      `rm "#{f}"`
      return true
    else
      u[:zero_size] = false
      return false
    end
  end

# create symlink for "latest"
  def create_latest_symlink(u)
    _file = u[:old_downloaded]
    _file = u[:old_proc_filename] if u[:resize]
    if _file.to_s =~ /\.jpg$/i
      _file = "#{_file}"
      _output = "latest/#{u[:desc]}.jpg"

      # if something go wrong, we
      #command = "ln -f \"#{_file}\" \"#{_output}\""
      command = "ln -sf \"../#{_file}\" \"#{_output}\""
      `#{command}`
    end
  end

  def create_html_page
    f = File.new(File.join('latest', 'index2.html'), 'w')
    fs = File.new(File.join('latest', 'stats.html'), 'w')
    f.puts "<h1>Webcam downloader - #{Time.now}</h1>\n"
    f.puts "<h4>started at #{@started_at}</h4>\n"
    f.puts "<hr>\n"

    urls.each do |u|
      if u[:zero_size]
        f.puts "<h4>#{u[:desc]}</h4>\n"
        f.puts "<p style=\"font-size: 70%\">\n"
        f.puts "<span style=\"color: red\">NOT DOWNLOADED</span> \n"
        f.puts "<a href=\"#{u[:url]}\">#{u[:url]}</a><br>\n"
        f.puts "zero size count #{u[:zero_size_count]}, download count #{u[:download_count]}, download time cost #{u[:download_time_cost]}, last download time #{Time.at(u[:last_downloaded_time])}\n"
        f.puts "</p>\n"
      else
        f.puts "<h3>#{u[:desc]}</h3>\n"
        f.puts "<p>\n"
        f.puts "<a href=\"#{u[:url]}\">#{u[:url]}</a><br>\n"
        f.puts "download count #{u[:download_count]}, download time cost #{u[:download_time_cost]}, last download time #{Time.at(u[:last_downloaded_time])}\n"
        f.puts "</p>\n"

        img = u[:desc] + ".jpg"
        f.puts "<img src=\"#{img}\" style=\"max-width: 800px; max-height: 600px;\" />\n"
      end

      f.puts "<hr>\n"
    end

    f.puts "<h2>Time costs</h2>\n"
    tc = urls.collect { |u|
      count = u[:download_count]
      count = 1 if count.to_i == 0

      process_count = u[:process_count]
      process_count = 1 if process_count.to_i == 0

      fs_count = u[:file_size_count]
      fs_count = 1 if fs_count.to_i == 0

      avg_download_time_cost = (u[:download_time_cost_total].to_f / count.to_f)
      avg_process_time_cost = (u[:process_time_cost_total].to_f / process_count.to_f)
      sum_full_cost = avg_download_time_cost + avg_process_time_cost

      {
        :desc => u[:desc],

        :last_cost => fl_to_s(u[:download_time_cost].to_f + u[:process_time_cost].to_f),
        :last_download_cost => fl_to_s(u[:download_time_cost].to_f),
        :last_process_cost => u[:resize] ? fl_to_s(u[:process_time_cost].to_f) : "",

        :last_attempted_time_ago => Time.now.to_i - u[:last_downloaded_time].to_i,

        :avg_cost => fl_to_s(sum_full_cost),
        :avg_download_cost => fl_to_s(avg_download_time_cost),
        :avg_process_cost => u[:resize] ? fl_to_s(avg_process_time_cost) : "",

        :process_flag => u[:resize] ? "T" : "-",
        :count => u[:download_count],
        :fail_count => u[:zero_size_count],
        :process_count => u[:process_count],

        :file_size_last => u[:file_size_last],
        :file_size_avg => fl_to_s(u[:file_size_total].to_f / fs_count.to_f),
      }
    }
    tc.sort! { |a, b| b[:avg_cost] <=> a[:avg_cost] }

    keys = [
      [:desc, "desc"],
      [:process_flag, "proc?"],
      [:avg_cost, "avg TC[s]"],
      [:avg_download_cost, "a.down TC[s]"],
      [:avg_process_cost, "a.proc TC[s]"],
      [:last_attempted_time_ago, "old [s]"],
      [:last_cost, "last TC[s]"],
      [:last_download_cost, "l.down TC[s]"],
      [:last_process_cost, "l.proc TC[s]"],
      [:count, "count"],
      [:process_count, "p.count"],
      [:fail_count, "failed(0)"],

      [:file_size_last, "size last"],
      [:file_size_avg, "size avg"],
    ]

    f.puts "<table border=\"1\">\n"
    fs.puts "<table border=\"1\">\n"
    f.puts "<tr>\n"
    fs.puts "<tr>\n"
    keys.each do |k|
      f.puts "<th>#{k[1]}</th>\n"
      fs.puts "<th>#{k[1]}</th>\n"
    end
    f.puts "</tr>\n"
    fs.puts "</tr>\n"

    tc.each do |t|
      f.puts "<tr>\n"
      fs.puts "<tr>\n"
      keys.each do |k|
        f.puts "<td>#{t[k[0]]}</td>\n"
        fs.puts "<td>#{t[k[0]]}</td>\n"
      end
      f.puts "</tr>\n"
      fs.puts "</tr>\n"
    end
    f.puts "</table>\n"
    fs.puts "</table>\n"

    f.close
    fs.close
  end

  def fl_to_s(fl)
    (fl.to_f * 1000.0).round.to_f / 1000.0
  end

# remove image which was already downloaded
  def remove_if_exist(u)
    f = File.new(u[:new_downloaded])
    u[:new_digest] = Digest::MD5.hexdigest(File.read(u[:new_downloaded]))
    u[:new_size] = File.size(u[:new_downloaded])
    u[:new_mtime] = f.mtime

    # compare only data in buffer because image can be processed
    # :ignore_mtime - dont check mtime, only file size
    if u[:old_size].nil? or u[:old_mtime].nil? or u[:old_downloaded].nil? or not File.exists?(u[:old_downloaded]) or
      not u[:old_size] == u[:new_size] or not u[:old_digest] == u[:new_digest]

      u[:old_size] = u[:new_size]
      u[:old_mtime] = u[:new_mtime]
      u[:old_downloaded] = u[:new_downloaded]
      u[:old_digest] = u[:new_digest]

      return false
    else
      puts "removing identical new image #{u[:new_downloaded]} as #{u[:old_downloaded]}"
      `rm #{u[:new_downloaded]}`
      u[:remove_identical_count] = u[:remove_identical_count].to_i + 1 # nil safe
      return true
    end
  end

# some images are big
  def resize_down_image_if_needed(u)
    fs = File.size(u[:new_downloaded])
    if fs > @max_size
      proc_image(u)
    end
  end

  def file_digest(f)
    begin
      Digest::MD5.hexdigest(File.read(f))
    rescue
      nil
    end
  end

# resize down image
  def proc_image(u)
    # resizing
    puts "resizing image #{u[:new_downloaded]}"
    u[:new_proc_filename] = u[:new_downloaded_processed]
    command = "convert \"#{u[:new_downloaded]}\" -resize '1920x1080>' -quality #{@jpeg_quality}% \"#{u[:new_proc_filename]}\""
    time_pre = Time.now
    `#{command}`
    u[:process_count] = u[:process_count].to_i + 1
    u[:process_time_cost] = Time.now - time_pre
    u[:process_time_cost_total] = u[:process_time_cost_total].to_f + u[:process_time_cost]

    # remove original
    `rm #{u[:new_downloaded]}`
  end

# remove processed image which was already downloaded
  def remove_proc_if_exist(u)
    # calculate digest
    new_digest = file_digest(u[:new_proc_filename])
    u[:new_proc_digest] = new_digest if not new_digest.nil?
    # check with old digest
    if u[:old_proc_digest] == u[:new_proc_digest]
      # remove new file and return
      puts "removing processed identical #{u[:new_proc_filename]}, digests are equal"
      `rm #{u[:new_proc_filename]}`
      u[:remove_identical_count] = u[:remove_identical_count].to_i + 1 # nil safe
      return
    else
      # a new file
      u[:old_proc_digest] = u[:new_proc_digest]
      u[:old_proc_filename] = u[:new_proc_filename]

      return
    end
  end

  def mark_file_size(u)
    if u[:resize]
      file = u[:new_proc_filename]
    else
      file = u[:new_downloaded]
    end

    u[:file_size_count] = u[:file_size_count].to_i + 1
    u[:file_size_last] = File.size(file) / 1024
    u[:file_size_total] = u[:file_size_total].to_i + u[:file_size_last]
  end

  def self.load_and_flatten_definitions(file)
    urls = YAML::load(File.open(file))
    flat_urls = Array.new
    urls.each do |u|
      flat_urls += u[:array]
    end
    # just for dev
    #flat_urls = flat_urls[0..5]
    return flat_urls
  end

end
