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

    def images_html
      s = ""
      s += "<h1>Webcam downloader - #{Time.now}</h1>\n"
      s += "<h4>started at #{@downloader.started_at}</h4>\n"
      s += "<hr>\n"

      @downloader.webcams.each do |webcam|
        if u[:zero_size]
          s += "<h4>#{webcam.desc}</h4>\n"
          s += "<p style=\"font-size: 70%\">\n"
          s += "<span style=\"color: red\">NOT DOWNLOADED</span> \n"
          s += "<a href=\"#{u[:url]}\">#{u[:url]}</a><br>\n"
          s += "zero size count #{u[:zero_size_count]}, download count #{u[:download_count]}, download time cost #{u[:download_time_cost]}, last download time #{Time.at(u[:last_downloaded_time])}\n"
          s += "</p>\n"
        else
          s += "<h3>#{u[:desc]}</h3>\n"
          s += "<p>\n"
          s += "<a href=\"#{u[:url]}\">#{u[:url]}</a><br>\n"
          s += "download count #{u[:download_count]}, download time cost #{u[:download_time_cost]}, last download time #{Time.at(u[:last_downloaded_time])}\n"
          s += "</p>\n"

          img = u[:desc] + ".jpg"
          s += "<img src=\"#{img}\" style=\"max-width: 800px; max-height: 600px;\" />\n"
        end

        s += "<hr>\n"
      end

      s += "<h2>Time costs</h2>\n"


      f.close
      fs.close
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

          :max_cost => fl_to_s(webcam.max_cost),
          :max_download_cost => fl_to_s(webcam.max_download_cost),
          :max_process_cost => webcam.process_resize ? fl_to_s(webcam.max_process_cost) : "",

          :last_attempted_time_ago => Time.now.to_i - webcam.last_downloaded_temporary_at.to_i,
          :last_stored_time_ago => Time.now.to_i - webcam.latest_stored_at.to_i,

          :count_download => webcam.download_count,
          :count_zero_size => webcam.file_size_zero_count,
          :count_identical => webcam.file_identical_count,

          :file_size_last => webcam.stored_file_size_last,
          :file_size_avg => webcam.avg_file_size,
          :file_size_max => webcam.stored_file_size_max,
        }
      }
      tc.sort! { |a, b| b[:avg_cost] <=> a[:avg_cost] }

      keys = [
        [:desc, "desc"],
        [:process_flag, "proc?"],

        [:avg_cost, "avg TC[s]"],
        [:avg_download_cost, "a.down TC[s]"],
        [:avg_process_cost, "a.proc TC[s]"],

        [:last_cost, "last TC[s]"],
        [:last_download_cost, "l.down TC[s]"],
        [:last_process_cost, "l.proc TC[s]"],

        [:max_cost, "max TC[s]"],
        [:max_download_cost, "m.down TC[s]"],
        [:max_process_cost, "m.proc TC[s]"],

        [:last_attempted_time_ago, "attmp old[s]"],
        [:last_stored_time_ago, "stored old[s]"],

        [:count_download, "count"],
        [:count_zero_size, "c. size 0"],
        [:count_identical, "c. identical"],

        [:file_size_last, "last size [kB]"],
        [:file_size_avg, "avg size [kB]"],
        [:file_size_max, "max size [kB]"],
      ]

      s += "<table border=\"1\">\n"
      s += "<tr>\n"
      keys.each do |k|
        s += "<th>#{k[1]}</th>\n"
      end
      s += "</tr>\n"

      tc.each do |t|
        s += "<tr>\n"
        keys.each do |k|
          s += "<td>#{t[k[0]]}</td>\n"
        end
        s += "</tr>\n"
      end
      s += "</table>\n"

      return s
    end

    def fl_to_s(fl)
      (fl.to_f * 1000.0).round.to_f / 1000.0
    end

  end
end