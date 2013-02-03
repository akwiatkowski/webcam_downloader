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
      _output = File.join("latest", "pix", "#{webcam.desc}.jpg")

      #command = "ln -f X Y"
      command = "ln -sf \"../../#{_file}\" \"#{_output}\""
      `#{command}`

      @logger.debug("#{webcam.desc.to_s.yellow} - symlink to latest")
    end

    def after_loop_cycle
      file_image_html = File.new(File.join("latest", "index2_full.html"), "w")
      file_image_html.puts html_start
      file_image_html.puts images_html
      file_image_html.puts html_end
      file_image_html.close

      html_per_groups
      sorted_stats_html_save

      @logger.debug("Presentation - after cycle".on_red)
    end

    def html_per_groups
      groups = @downloader.webcams.collect { |w| w.group }.uniq

      groups.each do |group|
        file_image_html = File.new(File.join("latest", "index1_#{group}.html"), "w")
        file_image_html.puts html_start
        file_image_html.puts images_html(group)
        file_image_html.puts html_end
        file_image_html.close
      end
    end

    def images_html(group = nil)
      s = ""
      s += "<h1>Webcam downloader - #{Time.now}</h1>\n"
      s += "<h4>started at #{@downloader.started_at}</h4>\n"
      s += "<hr>\n"

      webcams = @downloader.webcams
      if group
        webcams = webcams.select { |w| w.group == group }
      end

      webcams.each do |webcam|
        s += "<h3>#{webcam.desc}</h3>\n"
        s += "<p>\n"
        s += "<a href=\"#{webcam.url}\">#{webcam.url}</a><br>\n"
        s += "</p>\n"

        img = "pix/" + webcam.desc + ".jpg"
        s += "<img src=\"#{img}\" style=\"max-width: 800px; max-height: 600px;\" />\n"

        s += html_table_from_webcam_hash([webcam.to_hash])

        s += "<hr>\n"
      end

      return s
    end

    def html_table_from_webcam_hash(tc)
      s = ""

      keys = [
        [:desc, "desc", { background: "66FF99" }],
        [:worker_id, "wrk"],
        [:process_flag, "proc?"],

        [:avg_cost, "avg TC[s]", { background: "FF3333" }],
        [:avg_download_cost, "a.down TC[s]", { background: "FF3333" }],
        [:avg_process_cost, "a.proc TC[s]", { background: "FF3333" }],

        [:last_cost, "last TC[s]", { background: "FF6600" }, { sum: true }],
        [:last_download_cost, "l.down TC[s]", { background: "FF6600" }, { sum: true }],
        [:last_process_cost, "l.proc TC[s]", { background: "FF6600" }, { sum: true }],

        [:max_cost, "max TC[s]", { background: "FF0066" }, { sum: true }],
        [:max_download_cost, "m.down TC[s]", { background: "FF0066" }, { sum: true }],
        [:max_process_cost, "m.proc TC[s]", { background: "FF0066" }, { sum: true }],

        [:last_attempted_time_ago, "attmp old[s]", { background: "99BBBB" }],
        [:last_stored_time_ago, "stored old[s]", { background: "99BBBB" }],
        [:will_be_downloaded_after, "will d. be after[s]", { background: "99BBBB" }],

        [:count_download, "count", { background: "CC9900" }, { sum: true }],
        [:count_zero_size, "c. size 0", { background: "CC9900" }, { sum: true }],
        [:count_identical, "c. identical", { background: "CC9900" }, { sum: true }],

        [:interval, "int", { background: "66CCCC" }],
        [:identical_factor, "ident. fact", { background: "66CCCC" }],

        [:file_size_last, "last size [kB]", { background: "009900" }, { sum: true }],
        [:file_size_pre_process_last, "l. pre-proc [kB]", { background: "009900" }, { sum: true }],
        [:file_size_avg, "avg size [kB]", { background: "009900" }, { sum: true }],
        [:file_size_max, "max size [kB]", { background: "009900" }, { sum: true }],
        [:data_per_day, "MB/day", { background: "44CC44" }, { sum: true }],
        [:data_per_month, "GB/m", { background: "44CC44" }, { sum: true }],

        [:html_info, "info"],
        [:group, "group"],
        [:desc, "desc", { background: "66FF99" }],
      ]

      s += "<table border=\"1\">\n"
      s += "<tr>\n"
      s += "<th>U</th>\n"
      keys.each do |k|
        s += "<th>#{k[1]}</th>\n"
      end
      s += "</tr>\n"

      tc.each do |t|
        s += "<tr>\n"
        img = "pix/" + t[:desc] + ".jpg"
        s += "<td><a href=\"#{img}\" target=\"_blank\">X</a></td>\n"
        keys.each do |k|
          if k[2] and k[2][:background]
            style = " style=\"background-color: #{k[2][:background]}\""
          end

          s += "<td class=\"hideextra\"#{style}>#{t[k[0]]}</td>\n"
        end
        s += "</tr>\n"
      end

      # summary
      s += "<tr>\n"
      s += "<th></th>\n"
      keys.each do |k|
        v = ""
        if k[3].kind_of?(Hash) and k[3][:sum]
          sum = 0.0

          tc.each do |t|
            sum += t[k[0]].to_f
          end

          v = fl_to_s(sum)
        end

        style = ""
        if k[2] and k[2][:background]
          style = " style=\"background-color: #{k[2][:background]}\""
        end

        s += "<th#{style}>#{v}</th>\n"
      end
      s += "</tr>\n"

      s += "</table>\n"

      return s
    end


    def sorted_stats_html_save
      # quite an overkill
      #orders = [
      #  :avg_cost, :desc, :worker_id, :last_cost, :max_cost,
      #  :last_attempted_time_ago, :count_download, :count_zero_size,
      #  :count_identical, :interval, :identical_factor, :file_size_avg
      #]
      orders = [
        :avg_cost, :last_attempted_time_ago, :identical_factor, :file_size_avg, :data_per_day
      ]

      orders.each do |o|
        fs = File.new(File.join("latest", "stats_#{o}.html"), "w")
        fs.puts html_start
        fs.puts(sorted_stats_html(@downloader.webcams, o))
        fs.puts html_end
        fs.close
      end
    end

    def sorted_stats_html(webcams = @downloader.webcams, order = :avg_cost)
      tc = webcams.collect { |webcam| webcam.to_hash }
      tc.sort! { |a, b| b[order] <=> a[order] }
      return html_table_from_webcam_hash(tc)
    end

    def html_start
      "
<html>
<head>
<style>
.hideextra { white-space: nowrap; overflow: hidden; text-overflow:ellipsis; }
</style>
</head>
<body>"
    end

    def html_end
      "
</body>
</html>"
    end

  end
end