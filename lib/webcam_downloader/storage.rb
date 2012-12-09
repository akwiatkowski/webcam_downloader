$:.unshift(File.dirname(__FILE__))

require 'digest/md5'
require 'fileutils'

module WebcamDownloader
  class Storage

    DIRS = %w(tmp data pix latest) + [File.join('latest', 'pix')]

    def initialize(_downloader, _options = { })
      @downloader = _downloader
      @options = _options

      @logger = @downloader.logger
      @descs = Array.new

      prepare_file_structure
    end

    attr_accessor :descs

    def prepare_file_structure
      DIRS.each do |d|
        Dir.mkdir(d) unless File.exist?(d)
      end
    end

    def prepare_monthly_directories
      mp = Time.now.strftime('%Y_%m')
      return if @monthly_prefix == mp

      @logger.debug("Prepare monthly directories for #{mp}".on_red)

      # monthly dir
      f = File.join("pix", mp)
      Dir.mkdir(f) unless File.exists?(f)

      # dir per webcam
      @descs.each do |desc|
        f = File.join("pix", mp, desc)
        Dir.mkdir(f) unless File.exists?(f)
      end

      @monthly_prefix = mp

      @logger.debug("Prepare monthly directories for #{mp} - finished")
    end

    def set_paths_for_webcam(webcam)
      webcam.path_temporary = File.join('tmp', "tmp_" + webcam.desc + Time.now.to_i.to_s + ".jpg.tmp")
      webcam.path_temporary_processed = File.join('tmp', "tmp_" + webcam.desc + Time.now.to_i.to_s + "_proc.jpg.tmp")
      webcam.path_store = File.join("pix", @monthly_prefix, webcam.desc, "#{webcam.desc}_#{Time.now.to_i}.jpg")
      # webcam.path_store_processed = File.join("pix", @monthly_prefix, webcam.desc, "#{webcam.desc}_#{Time.now.to_i}_proc.jpg")

      @logger.debug("Set paths for #{webcam.desc.to_s.yellow}, store path #{webcam.path_store.to_s.green}")
      @logger.debug(" Temp path  #{webcam.path_temporary}")
      @logger.debug(" Store path #{webcam.path_store.to_s.light_green}")
    end

    # move to storage
    def store_temporary_image(webcam)
      if File.exists?(webcam.path_temporary)
        File.rename(webcam.path_temporary, webcam.path_store)
        @logger.info("Stored #{webcam.desc.to_s.yellow} (id #{webcam.webcam_id}, worker #{webcam.worker_id.to_s.red}), from #{webcam.path_temporary} to #{webcam.path_store.to_s.green}")
        return true
      else
        @logger.info("Not stored #{webcam.desc.to_s.yellow}, file #{webcam.path_temporary} not exists")
        return false
      end
    end

    #def empty_temporary_dir
    #  # WARNING
    #  #FileUtils.rm_rf("tmp/.", secure: true)
    #  raise 'very bad'
    #end

  end
end