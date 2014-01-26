class HelloServerNotifier
  NAME = "webcam_downloader"
  @@semaphore = Mutex.new

  def after_webcam_download(webcam)
    #return after_webcam_download_hash(webcam)
    return after_webcam_download_array(webcam)
  end

  def after_webcam_download_hash(webcam)
    @@semaphore.synchronize do
      s = HelloServerClient::Service.find_or_initialize_by_name(NAME)
      h = s.value

      if h.kind_of?(Array)
        h = nil
      end
      if h.nil?
        h = Hash.new
      end

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
      wh[:last_file_size] = {
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

  def after_webcam_download_array(webcam)
    @@semaphore.synchronize do
      s = HelloServerClient::Service.find_or_initialize_by_name(NAME)
      h = s.value
      h ||= Hash.new
      if h["_header"].nil?
        h["_header"] = %w{desc data_per_day cost file_size last_attempt count}
      end

      data_array = h["_data"]
      if data_array.nil?
        data_array = Array.new
      end

      wh = Hash.new
      wh["desc"] = webcam.desc
      wh[:data_per_day] = {
        _value: "%.2f" % webcam.data_per_day + " MB",
        _options: { klass: "blue" }
      }
      wh[:cost] = {
        _value: "%.1f" % webcam.last_cost.to_s + " s",
        _options: { klass: "red" },
        _subvalue: "%.1f" % webcam.avg_cost + " s",
      }
      wh[:file_size] = {
        _value: "%.1f" % webcam.stored_file_size_last + " kB",
        _options: { klass: "teal" },
        _subvalue: "%.1f" % webcam.avg_file_size + " kB"
      }
      wh[:last_attempt] = {
        _value: Time.at(webcam.last_downloaded_temporary_at.to_i).strftime("%Y-%m-%d %H:%M:%S"),
        _options: { klass: "green" }
      }
      wh[:count] = {
        _value: webcam.download_count,
        _options: { klass: "blue" }
      }

      data_array = data_array.delete_if { |r| r["desc"] == webcam.desc }
      data_array << wh
      data_array = data_array.sort { |a, b| a["desc"] <=> b["desc"] }
      h["_data"] = data_array

      s.value = h
      s.save!
      s
    end
  end
end