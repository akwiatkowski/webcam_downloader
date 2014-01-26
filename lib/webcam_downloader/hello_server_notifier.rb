class HelloServerNotifier
  NAME = "webcam_downloader"
  @@semaphore = Mutex.new

  def after_webcam_download(webcam)
    @@semaphore.synchronize do
      s = HelloServerClient::Service.find_or_initialize_by_name(NAME)
      h = s.value
      h ||= Hash.new

      # webcam hash
      wh = Hash.new
      wh[:data_per_day] = {
        _value: "%.2f" % webcam.data_per_day + " MB",
        _options: { klass: "blue" }
      }
      wh[:avg_cost] = {
        _value: "%.1f" % webcam.avg_cost + " s",
        _options: { klass: "red" }
      }
      wh[:last_cost] = {
        _value: "%.1f" % webcam.last_cost.to_s + " s",
        _options: { klass: "red" }
      }
      wh[:file_size_last] = {
        _value: "%.1f" % webcam.stored_file_size_last + " kB",
        _options: { klass: "teal" }
      }
      wh[:avg_file_size] = {
        _value: "%.1f" % webcam.avg_file_size + " kB",
        _options: { klass: "teal" }
      }
      wh[:last_attempted_time] = {
        _value: Time.at(webcam.last_downloaded_temporary_at.to_i).strftime("%Y-%m-%d %H:%M:%S"),
        _options: { klass: "green" }
      }
      wh[:download_count] = {
        _value: webcam.download_count,
        _options: { klass: "blue" }
      }
      wh[:identical_factor] = {
        _value: "%.2f" % webcam.identical_factor,
        _options: { klass: "brown" }
      }


      h[webcam.desc] = wh
      s.value = h
      s.save!
      s
    end
  end
end