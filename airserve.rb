require "cuba"
require "airplayer"
require "rest_client"
require "mustache"

Cuba.use Rack::Session::Cookie, :secret => "__a_very_long_string__"

#Cuba.plugin Cuba::Safe

class Array
  def nice_sort
    sort_by { |item| item.to_s.split(/(\d+)/).map { |e| [e.to_i, e] } }
  end
end

dirroot = "/home/public/media/"
controller = AirPlayer::Controller.new({device: 0, progress: false})

def browse(dirroot, e_dirstub)
  folders = []
  files = []
  dirpath = dirroot + URI.unescape(e_dirstub)
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
    :dirstub => e_dirstub, :folders => folders.nice_sort, :files => files.nice_sort)
end

def mustache(template, e_path, e_title)

  title = URI.unescape(e_title)
  path = URI.unescape(e_path)

  template = File.open(template, "rb").read

  Mustache.render(template, :path => path, :title => title)
end

def preserve_extension(title, updated_title)
  old_ext = title.split(".").last
  new_ext = updated_title.split(".").last
  if old_ext != new_ext
    updated_title = updated_title + "." + old_ext
  end
  updated_title
end

Cuba.define do

  on get do

    on root do
      browse(dirroot, "")
    end

    on "browse/(.*)" do |e_dirstub|
      browse(dirroot, "/#{e_dirstub}")
    end

    on "play/(.*)/:title" do |e_path, e_title|

      res.write mustache("play.mustache", e_path, e_title)

      full_path = URI.unescape(e_path + "/" + e_title)
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

    on "view/(.*)/:title" do |e_path, e_title|
      res.write mustache("view.mustache", e_path, e_title)
    end

    on "pause/(.*)/:title" do |e_path, e_title|
      res.write mustache("pause.mustache", e_path, e_title)
      controller.pause
    end

    on "resume/(.*)/:title" do |e_path, e_title|
      res.write mustache("play.mustache", e_path, e_title)
      controller.resume
    end

  end

  on post do

    on "skip/(.*)" do |e_path|
      on param("mins") do |mins|

        seconds = mins.to_i * 60
        controller.skip(seconds)
        res.redirect "/resume/" + e_path
      end
    end

    on "edit_title/(.*)/:title" do |e_path, e_title|
      on param("updated_title") do |e_updated_title|

        path = URI.unescape(e_path)
        title = URI.unescape(e_title)
        full_path = dirroot + path + "/" + title

        updated_title = preserve_extension(title, URI.unescape(e_updated_title))
        updated_full_path = dirroot + path + "/" + updated_title
        updated_stub_path = path + "/" + updated_title

        File.rename(full_path, updated_full_path)

        res.redirect URI.escape("/view/" + updated_stub_path)
      end
    end
  end
end
