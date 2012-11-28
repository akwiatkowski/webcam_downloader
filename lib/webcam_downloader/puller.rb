$:.unshift(File.dirname(__FILE__))

require 'digest/md5'
require 'logger'

module WebcamDownloader
  class Puller

    #RSYNC_FLAGS = "avrL" # --archive keeps perms, owner and group
    RSYNC_FLAGS = "vrl"

    def self.commands(definitions, url, destination = '.', time_to = Time.now, months_before = 1)
      i = 0
      time_prefix = time_to - i * 30 * 24 * 3600
      time_prefix = time_prefix.strftime('%Y_%m')

      commands = Array.new
      definitions.each do |d|
        desc = d[:desc]
        source_url = "#{url}/pix/#{time_prefix}/#{desc}".gsub(/\/\//, "/")
        destination_path = File.join(destination, 'pix', time_prefix).gsub(/^\//, '')
        command = "rsync -#{RSYNC_FLAGS} -e ssh #{source_url} #{destination_path}"

        commands << command
        #puts command
      end

      return commands
    end

    def self.make_it_so(definitions, url, destination = '.', time_to = Time.now, months_before = 1)
      commands = commands(definitions, url, destination, time_to, months_before)
      f = File.new('tmp/_commands.sh', 'w')
      commands.each do |command|
        f.puts command
      end
      f.close

      system('bash tmp/_commands.sh')
    end

  end
end