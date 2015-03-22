require "cuba"
require "airplayer"
require "rest_client"
require "mustache"

Cuba.use Rack::Session::Cookie, :secret => "__a_very_long_string__"

#Cuba.plugin Cuba::Safe

dirroot = "/home/public/media/"
controller = AirPlayer::Controller.new({device: 0, progress: false})

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

def mustache(template, path, title)
  decoded_title = URI.unescape(title)
  decoded_path = URI.unescape(path)
  template = File.open(template, "rb").read
  return Mustache.render(template, :path => decoded_path, :title => decoded_title)
end

Cuba.define do

  # only GET requests
  on get do

    # /
    on root do
      browse(dirroot, "")
    end

    # /about
    on "play/(.*)/:title" do |path, title|

      res.write mustache("play.mustache", path, title)

      full_path = URI.unescape(path) + "/" + URI.unescape(title)
      playlist = AirPlayer::Playlist.new()
      playlist.add(dirroot + full_path)
      playlist.entries do |media|
      Thread.new {
        begin
          controller.play(media)
        rescue
          controller = AirPlayer::Controller.new({device: 0, progress: false})
          controller.play(media)
        end
      }
      end
    end

    on "browse/(.*)" do |dirstub|
      browse(dirroot, "/#{dirstub}")
    end

    on "view/(.*)/:title" do |path, title|
      res.write mustache("view.mustache", path, title)
    end

    on "pause/(.*)/:title" do |path, title|
      res.write mustache("pause.mustache", path, title)
      controller.pause
    end

    on "resume/(.*)/:title" do |path, title|
      res.write mustache("play.mustache", path, title)
      controller.resume
    end

  end

  on post do

    on "skip/(.*)" do |e_path|
      on param("mins") do |mins|
        print "Number of mins" + mins + "\n"
        seconds = mins.to_i * 60
        print "Number of seconds " + seconds.to_s + "\n"
        controller.skip(seconds)
        res.redirect "/resume/" + e_path
      end

      on true do
        res.write "time not provided"
      end
    end

    on "edit_title/(.*)/:title" do |e_path, e_title|
      on param("updated_title") do |e_updated_title|

        title = URI.unescape(e_title)
        path = URI.unescape(e_path)
        updated_title = URI.unescape(e_updated_title)

        old_ext = title.split(".").last
        new_ext = updated_title.split(".").last
        if old_ext != new_ext
          updated_title = updated_title + "." + old_ext
        end
        File.rename(dirroot + path + "/" + title, dirroot + path + "/" + updated_title)
        res.redirect URI.escape("/view/" + path + "/" + updated_title)
      end
    end
  end
end
