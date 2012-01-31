urls = {
    :moko => "http://kamery.topr.pl/moko/moko_01.jpg",
    :goryczkowa => "http://kamery.topr.pl/goryczkowa/gorycz.jpg",
    :moko2 => "http://kamery.topr.pl/moko_TPN/moko_02.jpg",
    :stawy => "http://kamery.topr.pl/stawy1/stawy1.jpg"
  }
urls.keys.each_with_index do |u,i|
  f = "tatry_#{u}"
  Dir.mkdir(f) unless File.exists?(f)
end

j = 0
loop do

  urls.keys.each_with_index do |u,i|
    f = "tatry_#{u}_#{Time.now.to_i}.jpg"
    fn = "tatry_#{u}/#{u}_#{Time.now.to_i}.jpg"

    url = urls[u]

    command = "wget \"#{url}\" -O#{f}"
    puts command
    `#{command}`

    if File.size(f) > 0
      puts "moving #{f} to #{fn}"
      `mv "#{f}" "#{fn}"`
    else
      puts "removing #{f}, file size = 0"
      `rm "#{f}"`
    end
  end

  puts "all is done, sleeping, stage #{j += 1}"
  sleep 10*60
end
