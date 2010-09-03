if defined?(Zip::ZipFile)
  $stderr.puts "RubyArchive requires its own version of rubyzip. A copy of rubyzip has already been loaded. This may lead to unpredictable problems."
else
  $LOAD_PATH.unshift(File.expand_path('../rubyzip',__FILE__))
  require File.expand_path('../rubyzip/zip/zipfilesystem',__FILE__)
end

module RubyArchive::Handlers
  class ZipHandler < RubyArchive::Handler
    ZIP_MAGIC = "\x50\x4B\x03\x04"

    # Checks the magic of the given file to check if it's a zip file
    def self.handles? location
      # use normalized location because Zip::ZipFile.open does not expand '~'
      normalized_location = RubyArchive::Handler::normalize_path(location)
      return false unless File.file?(normalized_location)
      return false unless File.read(normalized_location, ZIP_MAGIC.length) == ZIP_MAGIC
      return true
    end

    def initialize location
      # use normalized location because Zip::ZipFile.open does not expand '~'
      normalized_location = RubyArchive::Handler::normalize_path(location)
      @zipfs = Zip::ZipFile.open(normalized_location)
      @name = normalized_location
    end

    def close
      @zipfs.close
    end

    def file
      @zipfs.file
    end

    def dir
      @zipfs.dir
    end
  end
end

RubyArchive.add_handler_class(RubyArchive::Handlers::ZipHandler)
