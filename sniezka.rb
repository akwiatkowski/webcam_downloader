urls = [
    "http://kamery.humlnet.cz/images/webcams/snezka3/2048x1536.jpg",
    "http://kamery.humlnet.cz/images/webcams/snezka2/2048x1536.jpg",
    "http://kamery.humlnet.cz/images/webcams/snezka/2048x1536.jpg"
  ]
urls.each_with_index do |u,i|
  f = "sniezka_#{i}"
  Dir.mkdir(f) unless File.exists?(f)
end

j = 0
loop do

  urls.each_with_index do |u,i|
    f = "sniezka_#{i}_#{Time.now.to_i}.jpg"
    fn = "sniezka_#{i}/sniezka_#{i}_#{Time.now.to_i}.jpg"

    command = "wget \"#{u}\" -O#{f}"
    puts command
    `#{command}`
    `mv "#{f}" "#{fn}"`
  end

  puts "all is done, sleeping, stage #{j += 1}"
  sleep 120
end