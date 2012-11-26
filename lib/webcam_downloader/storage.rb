$:.unshift(File.dirname(__FILE__))

require 'digest/md5'

module WebcamDownloader
  class Storage

    def initialize(_options={ })
      @options = _options

      Dir.mkdir('tmp') unless File.exist?('tmp')
      Dir.mkdir('data') unless File.exist?('data')

    end

  end
end