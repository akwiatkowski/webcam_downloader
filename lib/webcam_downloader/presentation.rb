$:.unshift(File.dirname(__FILE__))

module WebcamDownloader
  class Presentation

    def initialize(_downloader, _options = { })
      @downloader = _downloader
      @options = _options
      @logger = @downloader.logger
    end

    def after_image_store(webcam)
      _file = webcam.path_store
      _output = File.join("latest", "#{webcam.desc}.jpg")

      #command = "ln -f \"#{_file}\" \"#{_output}\""
      command = "ln -sf \"../#{_file}\" \"#{_output}\""
      `#{command}`

      @logger.debug("#{webcam.desc} - symlink to latest")
    end

    def after_loop_cycle
      @logger.debug("Presentation - after cycle")
    end

    def stats_html
      s = ""

      tc = @downloader.webcams.collect { |webcam|
        {
          :desc => webcam.desc,
          :process_flag => webcam.process_resize ? "T" : "-",

          :avg_cost => fl_to_s(webcam.avg_cost),
          :avg_download_cost => fl_to_s(webcam.avg_download_cost),
          :avg_process_cost => webcam.process_resize ? fl_to_s(webcam.avg_process_cost) : "",

          :last_cost => fl_to_s(webcam.last_cost),
          :last_download_cost => fl_to_s(webcam.last_download_cost),
          :last_process_cost => webcam.process_resize ? fl_to_s(webcam.last_process_cost) : "",

          #

          :last_cost => fl_to_s(u[:download_time_cost].to_f + u[:process_time_cost].to_f),
          :last_download_cost => fl_to_s(u[:download_time_cost].to_f),
          :last_process_cost => u[:resize] ? fl_to_s(u[:process_time_cost].to_f) : "",

          :last_attempted_time_ago => Time.now.to_i - u[:last_downloaded_time].to_i,


          :avg_download_cost => fl_to_s(avg_download_time_cost),
          :avg_process_cost => u[:resize] ? fl_to_s(avg_process_time_cost) : "",


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
    end


    def stats_html_old
      s = ""

      tc = @downloader.webcams.collect { |webcam|
        count = webcam.download_count
        count = 1 if count.to_i == 0

        process_count = webcam.process_count
        process_count = 1 if process_count.to_i == 0

        fs_count = webcam.zero_size_count
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
    end

  end
end