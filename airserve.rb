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
  dirpath = dirroot + URI.unescape(dirstub)
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
  res.write "<head>"
  res.write "<title>AirServe #{dirstub}</title>"
  res.write "<style>body {margin: 0;background-color:lightgray} ul {padding: 0; margin:0} .item {display:block;padding:8px;background-color:gray;margin:1px} a {color:white;text-decoration:none} .folder {font-weight:bold}</style>"
  res.write "<meta name='viewport' content='user-scalable=no,width=device-width'>"
  #res.write "<meta name='apple-mobile-web-app-capable' content='yes'>"
  #res.write "<meta name='apple-mobile-web-app-status-bar-style' content='black'>"
  res.write"</head>"
  res.write "<body>"
  res.write "  <ul>"
  folders.each do |folder|
    res.write "    <a href='/browse#{dirstub}/#{folder}'><li class='item folder'>#{folder}</li></a>"
  end
  files.each do |file|
    res.write "    <a href='/play#{dirstub}/#{file}'><li class='item file'>#{file}</li></a>"
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
