require "cuba"
require "airplayer"

Cuba.use Rack::Session::Cookie, :secret => "__a_very_long_string__"

#Cuba.plugin Cuba::Safe

threads = []
controller = AirPlayer::Controller.new({device: 0})

dirroot = "/home/public/media/"

def browse(dirroot, dirstub)
  folders = []
  files = []
  dirpath = dirroot + dirstub
  Dir.foreach(dirpath) do |item|
    next if item.start_with?('.')
    filepath = "#{dirpath}/#{item}"
    if File.directory?(filepath)
      folders << item
      next
    end
    files << item
  end

  folders = folders.sort
  files = files.sort

  res.write "<!DOCTYPE html>"
  res.write "<head><title>AirServe</title></head>"
  res.write "<body>"
  res.write "  <ul>"
  folders.each do |folder|
    res.write "    <li><a href='/browse#{dirstub}/#{folder}'>#{folder}</al></li><br />"
  end
  files.each do |file|
    res.write "    <li><a href='/play#{dirstub}/#{file}'>#{file}</li><br />"
  end
  res.write "  </ul>"
  res.write "</body>"
end

Cuba.define do

  # only GET requests
  on get do

    # /
    on root do
      browse(dirroot, "")
    end

    # /about
    on "play/(.*)" do |title|
      decoded_title = URI.unescape(title)
      controller = AirPlayer::Controller.new({device: 0})
      playlist = AirPlayer::Playlist.new()
      playlist.add(dirroot + decoded_title)
      playlist.entries do |media|
        threads << Thread.new {
          controller.play(media)
          controller.pause
        }
        res.write "Playing #{decoded_title}<br />"
        #res.redirect "/"
      end
    end

    on "browse/(.*)" do |dirstub|
      browse(dirroot, "/#{dirstub}")
    end

    #on "pause" do
    #  res.write "Pausing"
    #  #controller.pause
    #  @player.stop
    #  res.write "Paused"
    #end

  end
end
