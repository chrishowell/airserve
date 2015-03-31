require "cuba"
require "airplayer"
require "rest_client"
require "mustache"

#Cuba.use Rack::Session::Cookie, :secret => "__a_very_long_string__"

module URI
  remove_const :DEFAULT_PARSER
  unreserved = REGEXP::PATTERN::UNRESERVED
  DEFAULT_PARSER = Parser.new(:UNRESERVED => unreserved + "\\[\\]")
end

#Cuba.plugin Cuba::Safe

class Array
  def nice_sort
    sort_by { |item| item.to_s.split(/(\d+)/).map { |e| [e.to_i, e] } }
  end
end

DIR_ROOT = "/home/public/media/"
$controller = nil

def browse(e_dirstub)
  folders = []
  files = []
  dirpath = DIR_ROOT + URI.unescape(e_dirstub)
  Dir.foreach(dirpath) do |item|
    next if item.start_with?('.')
    filepath = "#{dirpath}/#{item}"
    if File.directory?(filepath)
      folders << item
      next
    end
    files << { "filename" => item, "title" => remove_extension(item) }
  end

  template = File.open("browse.mustache", "rb").read
  res.write Mustache.render(template, \
    :dirstub => e_dirstub, :folders => folders.nice_sort, :files => files.nice_sort)
end

def mustache(template, e_path, e_filename)

  filename = URI.unescape(e_filename)
  title = remove_extension(filename)
  path = URI.unescape(e_path)

  template = File.open(template, "rb").read

  Mustache.render(template, :path => path, :title => title, :filename => filename)
end

def remove_extension(title)
  ext = title.split(".").last
  title.to_s.chomp("." + ext)
end

def clone_extension(title, updated_title)
  ext = title.split(".").last
  updated_title + "." + ext
end

Cuba.define do

  on get do

    on root do
      res.redirect("/browse/")
    end

    on "browse/(.*)" do |e_dirstub|
      browse("/#{e_dirstub}")
    end

    on "play/(.*)/:title" do |e_path, e_title|
      $controller = AirPlayer::Controller.new({device: 0, progress: false})

      res.write mustache("play.mustache", e_path, e_title)

      full_path = URI.unescape(e_path + "/" + e_title)
      playlist = AirPlayer::Playlist.new()
      playlist.add(DIR_ROOT + full_path)
      playlist.entries do |media|
      Thread.new {
          $controller.play(media)
      }
      end
    end

    on "view/(.*)/:filename" do |e_path, e_filename|
      res.write mustache("view.mustache", e_path, e_filename)
    end

    on "pause/(.*)/:title" do |e_path, e_filename|
      if $controller.nil?
        res.redirect "/"
        next
      end
      
      res.write mustache("pause.mustache", e_path, e_filename)
      $controller.pause
    end

    on "resume/(.*)/:title" do |e_path, e_filename|
      if $controller.nil?
        res.redirect "/"
        next
      end

      res.write mustache("play.mustache", e_path, e_filename)
      $controller.resume
    end

  end

  on post do

    on "skip/(.*)" do |e_path|
      on param("mins") do |mins|
        if $controller.nil?
          res.redirect "/"
          next
        end

        seconds = mins.to_i * 60
        $controller.skip(seconds)
        res.redirect "/resume/" + e_path
      end
    end

    on "edit_title/(.*)/:title" do |e_path, e_filename|
      on param("updated_title") do |e_updated_title|
        if $controller.nil?
          res.redirect "/"
          next
        end

        path = URI.unescape(e_path)
        filename = URI.unescape(e_filename)
        full_path = DIR_ROOT + path + "/" + filename

        updated_title = URI.unescape(e_updated_title)
        updated_filename = clone_extension(filename, updated_title)
        updated_full_path = DIR_ROOT + path + "/" + updated_filename
        updated_stub_path = path + "/" + updated_filename

        File.rename(full_path, updated_full_path)

        res.redirect URI.escape("/view/" + updated_stub_path)
      end
    end
  end
end
