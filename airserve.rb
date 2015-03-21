require "cuba"
require "airplayer"
require "rest_client"
require "mustache"

Cuba.use Rack::Session::Cookie, :secret => "__a_very_long_string__"

#Cuba.plugin Cuba::Safe

threads = []
#controller = AirPlayer::Controller.new({device: 0})

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

  template = File.open("browse.mustache", "rb").read
  res.write Mustache.render(template, \
    :dirstub => dirstub, :folders => folders.sort, :files => files.sort)
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
          controller.pause #should go!
        }

        template = File.open("play.mustache", "rb").read
        res.write Mustache.render(template, :title => decoded_title)
      end
    end

    on "browse/(.*)" do |dirstub|
      browse(dirroot, "/#{dirstub}")
    end

    on "pause" do
      RestClient.post "192.168.0.10:7000/rate?value=0.000000", {}
      res.write "<a href='/resume'>Resume</a>"
    end

    on "resume" do
      RestClient.post "192.168.0.10:7000/rate?value=1.000000", {}
      res.write "<a href='/pause'>Pause</a>"
    end

    #on "skip?{.*}" do |mins|
    #  seconds = mins * 60
    #  RestClient.post "192.168.0.10:7000/scrub?position=#{seconds}", {}
    #  res.write "<a href='/pause'>Pause</a>"
    #end

  end
end
