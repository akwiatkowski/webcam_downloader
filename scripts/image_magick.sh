# some commands for resizing

#http://www.imagemagick.org/script/command-line-options.php#resize
#http://www.imagemagick.org/Usage/formats/#jpg
cp orig.jpg copy.jpg
#convert copy.jpg -resize '1920x1080^' -crop '1920x1080x0x0' -quality 70% copy2.jpg
#convert copy.jpg -resize '1920x1080^' -gravity Center -crop '1920x1080' -quality 70% copy2.jpg
#convert copy.jpg -resize '1920x1080^' -gravity Center -shave '0x180' -quality 70% copy2.jpg
convert copy.jpg -adaptive-resize '1920x1080^' -gravity Center -shave '0x180' -quality 70% copy2.jpg
