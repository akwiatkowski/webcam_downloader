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
      file_image_html = File.new( File.join("latest", "index2.html"), "w")
      file_stats_html = File.new( File.join("latest", "stats.html"), "w")

      file_image_html.puts images_html
      file_stats_html.puts stats_html

      file_image_html.close
      file_stats_html.close

      @logger.debug("Presentation - after cycle")
    end

    def images_html
      s = ""
      s += "<h1>Webcam downloader - #{Time.now}</h1>\n"
      s += "<h4>started at #{@downloader.started_at}</h4>\n"
      s += "<hr>\n"

      @downloader.webcams.each do |webcam|
        s += "<h3>#{webcam.desc}</h3>\n"
        s += "<p>\n"
        s += "<a href=\"#{webcam.url}\">#{webcam.url}</a><br>\n"
        s += "</p>\n"

        img = webcam.desc + ".jpg"
        s += "<img src=\"#{img}\" style=\"max-width: 800px; max-height: 600px;\" />\n"

        s += html_table_from_webcam_hash([webcam.to_hash])

        s += "<hr>\n"
      end

      return s
    end

    def html_table_from_webcam_hash(tc)
      s = ""

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


    def stats_html
      tc = @downloader.webcams.collect { |webcam| webcam.to_hash }
      tc.sort! { |a, b| b[:avg_cost] <=> a[:avg_cost] }
      return html_table_from_webcam_hash(tc)
    end

  end
end