class WebCamDownloader
  attr_accessor :urls

  def initialize
    @max_size = 400_000

    @jpeg_quality = 82

    #@sleep_interval = 5*60
    @sleep_interval = 90
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
    command = "wget --referer=\"#{ref}\" --user-agent=\"#{agent}\" --load-cookies cookies.txt --keep-session-cookies --save-cookies cookies.txt \"#{url}\" -O#{dest}"
    puts command
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
      # superloop
      self.urls.each_with_index do |u, i|
        desc = u[:desc]
        u[:temporary] = "#{desc}_#{Time.now.to_i}.jpg"
        u[:now_downloaded] = image_store_path(u)

        if not u[:pre_url].nil?
          # download temporary and remove
          download_file(u[:pre_url], 'tmp.tmp')
          `rm tmp.tmp`
        end

        # download image
        download_file(u[:url], u[:temporary])

        # check file size, remove empty files
        if remove_empty_file(u[:temporary]) == false
          # move image to downloaded
          puts "moving #{u[:temporary]} to #{u[:now_downloaded]}"
          `mv "#{u[:temporary]}" "#{u[:now_downloaded]}"`

          # remove if file is identical to downloaded before
          if remove_if_exist(u) == false
            # file wasn't removed
            #resize_down_image_if_needed(u)
            resize_down_image(u) if u[:resize] == true
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
    f = File.new(u[:now_downloaded])
    u[:new_size] = File.size(u[:now_downloaded])
    u[:new_mtime] = f.mtime

    # compare only data in buffer because image can be processed
    if u[:old_size].nil? or u[:old_mtime].nil? or u[:old_downloaded].nil? or not File.exists?(u[:old_downloaded]) or
      not u[:old_size] == u[:new_size] or not u[:old_mtime] = u[:old_mtime]
      u[:old_size] = u[:new_size]
      u[:old_mtime] = u[:new_mtime]
      u[:old_downloaded] = u[:now_downloaded]

      return false
    else
      puts "removing identical new image #{u[:now_downloaded]} as #{u[:old_downloaded]}"
      `rm #{u[:now_downloaded]}`
      return true
    end
  end

  # some images are big
  def resize_down_image_if_needed(u)
    fs = File.size(u[:now_downloaded])
    if fs > @max_size
      resize_down_image(u)
    end
  end

  # resize down image
  def resize_down_image(u)
    # resizing
    puts "resizing image #{u[:now_downloaded]}"
    command = "convert \"#{u[:now_downloaded]}\" -resize '1920x1080>' -quality #{@jpeg_quality}% \"#{image_store_path_processed(u)}\""
    `#{command}`

    # remove original
    `rm #{u[:now_downloaded]}`
  end

end

wd = WebCamDownloader.new
wd.urls = [
  { :desc => "zakopane", :url => "http://www.zakopaneonline.eu/webcam/zakopane.jpg", :pre_url => "http://www.zol.pl/webcam/", :resize => false },
  { :desc => 'moko', :url => "http://kamery.topr.pl/moko/moko_01.jpg" },
  { :desc => 'goryczkowa', :url => "http://kamery.topr.pl/goryczkowa/gorycz.jpg" },
  { :desc => 'moko2', :url => "http://kamery.topr.pl/moko_TPN/moko_02.jpg" },
  { :desc => 'stawy', :url => "http://kamery.topr.pl/stawy1/stawy1.jpg" },
  { :desc => 'koscielisko', :url => "http://www.zakopaneonline.eu/webcam6/koscielisko.jpg" },
  { :desc => 'krupowki', :url => "http://www.zakopaneonline.eu/webcam9/krupowki.jpg" },
  { :desc => 'zakopianka', :url => "http://www.zakopaneonline.eu/webcam8/zakopianka.jpg" },
  { :desc => 'beskid1', :url => "http://www.kamera.zadzial.pl/cam_1.jpg" },
  { :desc => 'bukowina', :url => "http://www.zakopaneonline.eu/webcam4/bukowina.jpg" },
  { :desc => 'willa_kubik', :url => "http://www.zakopaneonline.eu/webcams/kubik.jpg" },
  { :desc => 'trzy_korony', :url => "http://www.pieninyportal.com/images/stories/webcamera/pieninyportal.jpg" },
  { :desc => 'niedzica', :url => "http://www.niedzica.pl/uploads/webcam/niedzica6.jpg" },
  { :desc => 'giewont_zakopane', :url => "http://z-ne.pl/kamery/giewont_zakopane.jpg" },
  { :desc => 'bisk', :url => "http://cedr.irsm.cas.cz/rinex/meteo/webcam_photo.php?station=bisk" },
  { :desc => 'bisk2', :url => "http://cedr.irsm.cas.cz/rinex/meteo/webcam_photo.php?station=bisk2" },
  { :desc => 'bisk3', :url => "http://cedr.irsm.cas.cz/rinex/meteo/webcam_photo.php?station=bisk3" },
  { :desc => 'bisk4', :url => "http://cedr.irsm.cas.cz/rinex/meteo/webcam_photo.php?station=bisk4" },
  { :desc => 'szyndzielnia', :url => "http://www.dalekieobserwacje.eu/wp-content/uploads/webcam_szyndzielnia/A-hi.jpg", :resize => true },
  { :desc => 'liwocz', :url => "http://www.dalekieobserwacje.eu/wp-content/uploads/webcam_liwocz/A-hi.jpg", :resize => true },
  { :desc => 'widnica', :url => "http://www.dalekieobserwacje.eu/wp-content/uploads/webcam_widnica/A-hi.jpg", :resize => true },
  { :desc => 'mikolow', :url => "http://www.dalekieobserwacje.eu/wp-content/uploads/webcam_mikolow/A-hi.jpg", :resize => true },

  # Śnieżka
  { :desc => 'sniezka0', :url => "http://kamery.humlnet.cz/images/webcams/snezka3/2048x1536.jpg", :resize => true },
  { :desc => 'sniezka1', :url => "http://kamery.humlnet.cz/images/webcams/snezka2/2048x1536.jpg", :resize => true },
  { :desc => 'sniezka2', :url => "http://kamery.humlnet.cz/images/webcams/snezka/2048x1536.jpg", :resize => true },

#{:desc => '', :url => ""},
]
wd.make_it_so

