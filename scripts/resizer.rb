`mkdir done`
`mkdir raw`

Dir.new('.').each do |f|
  if f =~ /(.*)_(\d+)\.jpg/
    sn = $1
    time = $2
    puts "#{sn} #{time}"

    command = "convert \"#{f}\" -resize '1920x1080>' -quality #{85}% \"done/#{sn}_#{time}_proc.jpg\""
    `#{command}`

    `mv #{f} raw/#{f}`
  end
end

