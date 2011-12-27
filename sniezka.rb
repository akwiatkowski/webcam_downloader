#!/usr/bin/env ruby

# making a movie http://electron.mit.edu/~gsteele/ffmpeg/

j = 0
loop do
  urls = [
    "http://kamery.humlnet.cz/images/webcams/snezka3/2048x1536.jpg",
    "http://kamery.humlnet.cz/images/webcams/snezka2/2048x1536.jpg",
    "http://kamery.humlnet.cz/images/webcams/snezka/2048x1536.jpg"
  ]

  urls.each_with_index do |u,i|
    command = "wget \"#{u}\" -Osniezka_#{i}_#{Time.now.to_i}.jpg"
    puts command
    `#{command}`
  end

  puts "all is done, sleeping, stage #{j += 1}"
  sleep 120
end
