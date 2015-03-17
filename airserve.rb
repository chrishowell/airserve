require "cuba"
require "airplayer"

Cuba.use Rack::Session::Cookie, :secret => "__a_very_long_string__"

#Cuba.plugin Cuba::Safe

threads = []
controller = AirPlayer::Controller.new({device: 0})

dirroot = "/home/public/media/"

Cuba.define do

  # only GET requests
  on get do

    # /
    on root do
      res.write "<!DOCTYPE html>"
      res.write "<head><title>Movies</title></head>"
      res.write "<body>"
      res.write "<ul>"
      Dir.foreach("#{dirroot}/Movies/") do |item|
        next if item.start_with?('.')
        res.write "<a href='/play/#{item}' /><li>#{item}</li><br />"
      end
      res.write "</ul>"
      res.write "</body>"
    end

    # /about
    on "play/:title" do |title|
      decoded_title = URI.unescape(title)
      #controller = AirPlayer::Controller.new({device: 0})
      playlist = AirPlayer::Playlist.new()
      playlist.add("#{dirroot}/Movies/#{decoded_title}")
      playlist.entries do |media|
        threads << Thread.new {
          controller.play(media)
          controller.pause
        }
        res.write "Playing #{decoded_title}<br />"
	res.redirect "/"
        #res.write "<a href='/pause'>pause</a>"
      end
    end

    #on "pause" do
    #  res.write "Pausing"
    #  #controller.pause
    #  @player.stop
    #  res.write "Paused"
    #end

  end
end
