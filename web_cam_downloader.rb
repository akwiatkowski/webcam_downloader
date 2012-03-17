require 'digest/md5'

class WebCamDownloader
  attr_accessor :urls

  def initialize(_options={})
    @options = _options

    # not used
    @max_size = 400_000

    # processing image
    @jpeg_quality = 82

    @sleep_interval = 5

    @dns_timeout = 4 # --dns-timeout
    @connect_timeout = 5 # --connect-timeout
    @read_timeout = 10 # --read-timeout

    Dir.mkdir('tmp') if not File.exist?('tmp')
    Dir.mkdir('data') if not File.exist?('data')
  end

  def verbose?
    @options[:verbose]
  end

  # Prepare directories for images
  def prepare_directories
    f = 'pix'
    Dir.mkdir(f) unless File.exists?(f)

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
    u[:store_path_pre_process] = "tmp/#{u[:desc]}_#{u[:desc]}_#{Time.now.to_i}_pre_proc.jpg.tmp"
    u[:store_path] = "pix/#{u[:desc]}/#{u[:desc]}_#{Time.now.to_i}.jpg"
    u[:store_path_processed] = "pix/#{u[:desc]}/#{u[:desc]}_#{Time.now.to_i}_proc.jpg"
    

    # stored in other location for easier rsync usage
    if u[:resize] == true
      u[:store_path] = u[:store_path_pre_process]
    end
  end

  # Start downloading images
  def make_it_so
    prepare_directories

    j = 0
    loop do
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
          download_file(u[:url], u[:temporary])
          u[:last_downloaded_time] = Time.now.to_i

          # check file size, remove empty files
          if remove_empty_file(u[:temporary]) == false
            # move image to downloaded
            puts "moving #{u[:temporary]} to #{u[:store_path]}"
            `mv "#{u[:temporary]}" "#{u[:store_path]}"`

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

        end
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

  # remove image which was already downloaded
  def remove_if_exist(u)
    f = File.new(u[:store_path])
    u[:new_digest] = Digest::MD5.hexdigest(File.read(u[:store_path]))
    u[:new_size] = File.size(u[:store_path])
    u[:new_mtime] = f.mtime

    # compare only data in buffer because image can be processed
    # :ignore_mtime - dont check mtime, only file size
    if u[:old_size].nil? or u[:old_mtime].nil? or u[:old_downloaded].nil? or not File.exists?(u[:old_downloaded]) or
      not u[:old_size] == u[:new_size] or not u[:old_digest] == u[:new_digest]

      u[:old_size] = u[:new_size]
      u[:old_mtime] = u[:new_mtime]
      u[:old_downloaded] = u[:store_path]
      u[:old_digest] = u[:new_digest]

      return false
    else
      puts "removing identical new image #{u[:store_path]} as #{u[:old_downloaded]}"
      `rm #{u[:store_path]}`
      return true
    end
  end

  # some images are big
  def resize_down_image_if_needed(u)
    fs = File.size(u[:store_path])
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
    puts "resizing image #{u[:store_path]}"
    u[:new_proc_filename] = u[:store_path_processed]
    command = "convert \"#{u[:store_path]}\" -resize '1920x1080>' -quality #{@jpeg_quality}% \"#{u[:new_proc_filename]}\""
    `#{command}`

    # remove original
    `rm #{u[:store_path]}`
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
      return
    else
      # a new file
      u[:old_proc_digest] = u[:new_proc_digest]
      return
    end
  end

end
