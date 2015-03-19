require "cuba"
require "airplayer"

Cuba.use Rack::Session::Cookie, :secret => "__a_very_long_string__"

#Cuba.plugin Cuba::Safe

threads = []
controller = AirPlayer::Controller.new({device: 0})

dirroot = "/home/public/media/"

def browse(dirroot, dirstub)
      dirpath = "#{dirroot}#{dirstub}"
      res.write "<!DOCTYPE html>"
      res.write "<head><title>AirServe</title></head>"
      res.write "<body>"
      res.write "<ul>"
      Dir.foreach("#{dirpath}") do |item|
        next if item.start_with?('.')
        if File.directory?("#{dirpath}/#{item}")
          res.write "<li><a href='/browse#{dirstub}/#{item}'>#{item}</al></li><br />"
          next
        end
        res.write "<li><a href='/play#{dirstub}/#{item}'>#{item}</li><br />"
      end
      res.write "</ul>"
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
