require 'digest/md5'

class WebCamDownloader
  attr_accessor :urls

  def initialize(_options={ })
    @options = _options

    # not used
    @max_size = 400_000

    # processing image
    @jpeg_quality = 77

    @sleep_interval = 5

    @dns_timeout = 2 # --dns-timeout
    @connect_timeout = 3 # --connect-timeout
    @read_timeout = 3 # --read-timeout

    Dir.mkdir('tmp') if not File.exist?('tmp')
    Dir.mkdir('data') if not File.exist?('data')

    # time cost of all cycles, for stats and optim. only
    @time_stats = Array.new
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

    urls.each_with_index do |u, i|
      f = "pix/#{u[:desc]}"
      Dir.mkdir(f) unless File.exists?(f)
    end
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
    u[:new_downloaded] = "pix/#{u[:desc]}/#{u[:desc]}_#{Time.now.to_i}.jpg"
    u[:new_downloaded_processed] = "pix/#{u[:desc]}/#{u[:desc]}_#{Time.now.to_i}_proc.jpg"


    # stored in other location for easier rsync usage
    if u[:resize] == true
      u[:new_downloaded] = u[:new_downloaded_pre_process]
    end
  end

  # Start downloading images
  def make_it_so
    prepare_directories

    j = 0
    loop do
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
          download_file(u[:url], u[:temporary])
          u[:download_count] = u[:download_count].to_i + 1 # nil safe
          u[:download_time_cost] = Time.now - time_pre
          u[:last_downloaded_time] = Time.now.to_i

          # check file size, remove empty files
          if remove_empty_file(u[:temporary]) == false
            # move image to downloaded
            puts "moving #{u[:temporary]} to #{u[:new_downloaded]}"
            `mv "#{u[:temporary]}" "#{u[:new_downloaded]}"`

            # remove if file is identical to downloaded before
            if remove_if_exist(u) == false
              # file wasn't removed
              #resize_down_image_if_needed(u)
              if u[:resize] == true
                proc_image(u)
                remove_proc_if_exist(u)
              end
            end
          end

          # create symlink for latest
          create_latest_symlink(u)

        end
      end

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

# remove image which file size is 0
  def remove_empty_file(f)
    if File.size(f) == 0
      puts "removing #{f}, file size = 0"
      `rm "#{f}"`
      return true
    else
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

  def digest_for_file(f)
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
    u[:process_time_cost] = Time.now - time_pre

    # remove original
    `rm #{u[:new_downloaded]}`
  end

# remove processed image which was already downloaded
  def remove_proc_if_exist(u)
    # calculate digest
    new_digest = digest_for_file(u[:new_proc_filename])
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

end
