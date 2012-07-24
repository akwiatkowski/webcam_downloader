require 'digest/md5'

def clean_directory(d)
  path = File.join('pix', d)
  to_delete = Array.new
  files = Array.new

  Dir.new(path).each do |f|
    if not File.directory? File.join('pix', d, f)
      file_path = File.join(path, f)
      begin
        time = f[/(\d{5,20})/].to_i
      rescue
        puts f
        exit
      end

      files << {
        :path => path,
        :file_name => f,
        :size => File.size(file_path),
        :digest => Digest::MD5.hexdigest(File.read(file_path)),
        :time => time
      }
    end
  end

  files.each do |f|
    s = files.select { |g| g[:digest] == f[:digest] and g[:size] == f[:size] and not f[:time].nil? and f[:time] < g[:time] }
    to_delete += s.collect { |t| File.join(t[:path], t[:file_name]) }
  end

  #puts files.inspect
  to_delete = to_delete.uniq.sort
  puts "# processed #{d} - to delete #{to_delete.size}, after delete #{files.size - to_delete.size}"

  fd = File.new('delete.sh','a')
  to_delete.each do |df|
    fd.puts "rm \"#{df}\""
  end
  fd.close

  return to_delete
end

`rm delete.sh`

Dir.new('pix').each do |d|
  to_delete = Array.new
  if not d == '.' and not d == '..'
    to_delete += clean_directory(d)
  end
end