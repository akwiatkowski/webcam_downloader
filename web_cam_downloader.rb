require 'digest/md5'

class WebCamDownloader
  attr_accessor :urls

  def initialize
    # not used
    @max_size = 400_000

    # processing image
    @jpeg_quality = 82

    @sleep_interval = 60
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
    command = "wget --quiet --referer=\"#{ref}\" --user-agent=\"#{agent}\" --load-cookies cookies.txt --keep-session-cookies --save-cookies cookies.txt \"#{url}\" -O#{dest}"
    #puts command
    `#{command}`
  end

  def image_store_path(u)
    u[:store_path] = "pix/#{u[:desc]}/#{u[:desc]}_#{Time.now.to_i}.jpg"
  end

  def image_store_path_processed(u)
    u[:store_path] = "pix/#{u[:desc]}/#{u[:desc]}_#{Time.now.to_i}_proc.jpg"
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
          u[:temporary] = "#{desc}_#{Time.now.to_i}.jpg"
          u[:new_filename] = image_store_path(u)

          if not u[:pre_url].nil?
            # download temporary and remove
            download_file(u[:pre_url], 'tmp.tmp')
            `rm tmp.tmp`
          end

          # download image
          download_file(u[:url], u[:temporary])
          u[:last_downloaded_time] = Time.now.to_i

          # check file size, remove empty files
          if remove_empty_file(u[:temporary]) == false
            # move image to downloaded
            puts "moving #{u[:temporary]} to #{u[:new_filename]}"
            `mv "#{u[:temporary]}" "#{u[:new_filename]}"`

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
    f = File.new(u[:new_filename])
    u[:new_digest] = Digest::MD5.hexdigest(File.read(u[:new_filename]))
    u[:new_size] = File.size(u[:new_filename])
    u[:new_mtime] = f.mtime

    # compare only data in buffer because image can be processed
    # :ignore_mtime - dont check mtime, only file size
    if u[:old_size].nil? or u[:old_mtime].nil? or u[:old_downloaded].nil? or not File.exists?(u[:old_downloaded]) or
      not u[:old_size] == u[:new_size] or not u[:old_digest] == u[:new_digest]

      u[:old_size] = u[:new_size]
      u[:old_mtime] = u[:new_mtime]
      u[:old_downloaded] = u[:new_filename]
      u[:old_digest] = u[:new_digest]

      return false
    else
      puts "removing identical new image #{u[:new_filename]} as #{u[:old_downloaded]}"
      `rm #{u[:new_filename]}`
      return true
    end
  end

  # some images are big
  def resize_down_image_if_needed(u)
    fs = File.size(u[:new_filename])
    if fs > @max_size
      proc_image(u)
    end
  end

  def digest_for_file(f)
    Digest::MD5.hexdigest(File.read(f))
  end

  # resize down image
  def proc_image(u)
    # resizing
    puts "resizing image #{u[:new_filename]}"
    u[:new_proc_filename] = image_store_path_processed(u)
    command = "convert \"#{u[:new_filename]}\" -resize '1920x1080>' -quality #{@jpeg_quality}% \"#{u[:new_proc_filename]}\""
    `#{command}`

    # remove original
    `rm #{u[:new_filename]}`

  end

  # remove processed image which was already downloaded
  def remove_proc_if_exist(u)
    # calculate digest
    u[:new_proc_digest] = digest_for_file(u[:new_proc_filename])
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

wd = WebCamDownloader.new
wd.urls = [
  # Tatry
  { :desc => "zakopane", :url => "http://www.zakopaneonline.eu/webcam/zakopane.jpg", :pre_url => "http://www.zol.pl/webcam/", :interval => 3*60 },
  { :desc => 'moko', :url => "http://kamery.topr.pl/moko/moko_01.jpg", :interval => 3*60 },
  { :desc => 'goryczkowa', :url => "http://kamery.topr.pl/goryczkowa/gorycz.jpg", :interval => 3*60 },
  { :desc => 'moko2', :url => "http://kamery.topr.pl/moko_TPN/moko_02.jpg", :interval => 3*60 },
  { :desc => 'stawy', :url => "http://kamery.topr.pl/stawy1/stawy1.jpg", :interval => 3*60 },
  { :desc => 'koscielisko', :url => "http://www.zakopaneonline.eu/webcam6/koscielisko.jpg", :interval => 3*60 },
  { :desc => 'krupowki', :url => "http://www.zakopaneonline.eu/webcam9/krupowki.jpg", :interval => 3*60 },
  { :desc => 'zakopianka', :url => "http://www.zakopaneonline.eu/webcam8/zakopianka.jpg", :interval => 3*60 },
  { :desc => 'beskid1', :url => "http://www.kamera.zadzial.pl/cam_1.jpg", :interval => 3*60 },
  { :desc => 'bukowina', :url => "http://www.zakopaneonline.eu/webcam4/bukowina.jpg", :interval => 3*60 },
  { :desc => 'willa_kubik', :url => "http://www.zakopaneonline.eu/webcams/kubik.jpg", :interval => 3*60 },
  { :desc => 'giewont_zakopane', :url => "http://z-ne.pl/kamery/giewont_zakopane.jpg", :interval => 3*60 },

  # Misc
  { :desc => 'trzy_korony', :url => "http://www.pieninyportal.com/images/stories/webcamera/pieninyportal.jpg", :interval => 2*60 },
  { :desc => 'niedzica', :url => "http://www.niedzica.pl/uploads/webcam/niedzica6.jpg", :interval => 2*60 },
  { :desc => 'bisk', :url => "http://cedr.irsm.cas.cz/rinex/meteo/webcam_photo.php?station=bisk", :interval => 2*60 },
  { :desc => 'bisk2', :url => "http://cedr.irsm.cas.cz/rinex/meteo/webcam_photo.php?station=bisk2", :interval => 2*60 },
  { :desc => 'bisk3', :url => "http://cedr.irsm.cas.cz/rinex/meteo/webcam_photo.php?station=bisk3", :interval => 2*60 },
  { :desc => 'bisk4', :url => "http://cedr.irsm.cas.cz/rinex/meteo/webcam_photo.php?station=bisk4", :interval => 2*60 },

  # Dalekieobserwacje
  { :desc => 'skrzyczne', :url => "http://www.dalekieobserwacje.eu/wp-content/uploads/webcam_skrzyczne/A-hi.jpg", :resize => true, :interval => 4*60 },
  { :desc => 'szyndzielnia', :url => "http://www.dalekieobserwacje.eu/wp-content/uploads/webcam_szyndzielnia/A-hi.jpg", :resize => true, :interval => 4*60 },
  { :desc => 'liwocz', :url => "http://www.dalekieobserwacje.eu/wp-content/uploads/webcam_liwocz/A-hi.jpg", :resize => true, :interval => 4*60 },
  { :desc => 'widnica', :url => "http://www.dalekieobserwacje.eu/wp-content/uploads/webcam_widnica/A-hi.jpg", :resize => true, :interval => 4*60 },
  { :desc => 'mikolow', :url => "http://www.dalekieobserwacje.eu/wp-content/uploads/webcam_mikolow/A-hi.jpg", :resize => true, :interval => 4*60 },

  # Śnieżka
  { :desc => 'sniezka0', :url => "http://kamery.humlnet.cz/images/webcams/snezka3/2048x1536.jpg", :resize => true, :interval => 2*60 },
  { :desc => 'sniezka1', :url => "http://kamery.humlnet.cz/images/webcams/snezka2/2048x1536.jpg", :resize => true, :interval => 2*60 },
  { :desc => 'sniezka2', :url => "http://kamery.humlnet.cz/images/webcams/snezka/2048x1536.jpg", :resize => true, :interval => 2*60 },

#{:desc => '', :url => ""},
]
wd.make_it_so

