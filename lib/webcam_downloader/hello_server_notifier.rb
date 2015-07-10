class HelloServerNotifier
  NAME = "webcam_downloader"
  @@semaphore = Mutex.new

  def after_webcam_download(webcam)
    return # temporary disabled

    @@semaphore.synchronize do
      s = HelloServerClient::Notification.find_or_initialize_by_name(NAME)
      s.detail_header = %w{desc data_per_day cost file_size last_attempt count}

      details = s.details
      details ||= Array.new

      webcam_detail = [
        webcam.desc,
        "%.2f" % webcam.data_per_day + " MB", # data_per_day
        { # cost
          value: "%.1f" % webcam.last_cost.to_s + " s",
          klass: "red",
          subvalue: "%.1f" % webcam.avg_cost + " s",
        },
        {
          value: "%.1f" % webcam.stored_file_size_last + " kB",
          klass: "teal",
          subvalue: "%.1f" % webcam.avg_file_size + " kB"
        },
        {
          value: Time.at(webcam.last_downloaded_temporary_at.to_i).strftime("%Y-%m-%d %H:%M:%S"),
          klass: "green"
        },
        {
          value: webcam.download_count,
          klass: "blue"
        }
      ]

      details = details.delete_if { |r| r[0] == webcam.desc }
      details << webcam_detail
      details = details.sort { |a, b| a[0] <=> b[0] }

      s.details = details

      # summaries
      @@total_downloaded_size = 0.0 unless defined? @@total_downloaded_size
      @@total_downloaded_size += webcam.stored_file_size_last.to_f
      @@total_downloaded_count = 0 unless defined? @@total_downloaded_count
      @@total_downloaded_count += 1
      @@run_at = Time.now unless defined? @@run_at

      seconds_from_start = Time.now - @@run_at
      daily_usage = 0.0
      if seconds_from_start > 5
        daily_usage = ((@@total_downloaded_size.to_f / 1024.0) / seconds_from_start.to_f) * 24.0 * 3600.0
      end

      summaries = [
        ["last_downloaded_desc", webcam.desc],
        ["last_downloaded_at", Time.at(webcam.last_downloaded_temporary_at.to_i).strftime("%Y-%m-%d %H:%M:%S")],
        ["run_at", @@run_at.strftime("%Y-%m-%d %H:%M:%S")],
        ["total_downloaded_size", "%.4f GB" % (@@total_downloaded_size / (1024.0 ** 2))],
        ["daily_usage", "%.2f MB" % daily_usage],
        ["total_downloaded_count", @@total_downloaded_count],
      ]

      #
      s.summary_header = nil
      s.summaries = summaries

      s.save!
      s
    end
  end
end