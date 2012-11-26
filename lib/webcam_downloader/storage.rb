$:.unshift(File.dirname(__FILE__))

require 'digest/md5'

module WebcamDownloader
  class Storage

    def initialize(_downloader, _options = { })
      @downloader = _downloader
      @options = _options

      prepare_file_structure
    end

    def prepare_file_structure
      %w(tmp data pix latest).each do |d|
        Dir.mkdir(d) unless File.exist?(d)
      end
    end

    def prepare_monthly_directories(desc_array = [])
      mp = Time.now.strftime('%Y_%m')
      return if @monthly_prefix == mp

      # monthly dir
      f = File.join("pix", mp)
      Dir.mkdir(f) unless File.exists?(f)

      # dir per webcam
      desc_array.each do |desc|
        f = File.join("pix", mp, desc)
        Dir.mkdir(f) unless File.exists?(f)
      end

      @monthly_prefix = mp
    end

    def set_paths_for_webcam(webcam)
      webcam.path_temporary = File.join('tmp', "tmp_" + webcam.desc + Time.now.to_i.to_s + ".jpg.tmp")
      webcam.path_temporary_processed = File.join('tmp', "tmp_" + webcam.desc + Time.now.to_i.to_s + "_proc.jpg.tmp")
      webcam.path_store = File.join("pix", @monthly_prefix, webcam.desc, "#{webcam.desc}_#{Time.now.to_i}.jpg")
      # webcam.path_store_processed = File.join("pix", @monthly_prefix, webcam.desc, "#{webcam.desc}_#{Time.now.to_i}_proc.jpg")
    end

  end
end