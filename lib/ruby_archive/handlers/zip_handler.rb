unless defined?(Zip::ZipFile)
  begin
    require 'zip/zipfilesystem'
  rescue LoadError
    if $VERBOSE
      warn "RubyArchive::Handlers::ZipHandler -- rubyzip not found, using builtin copy"
    end
    $LOAD_PATH << File.expand_path("../rubyzip",__FILE__)
    require 'zip/zipfilesystem'
  end
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
