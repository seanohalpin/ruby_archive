load File.expand_path('../ruby_archive/patch.rb',__FILE__)

module RubyArchive
  class Handler
    # ruby_archive/handler.rb
    load File.expand_path('../ruby_archive/handler.rb',__FILE__)
  end

  module Handlers
    # ruby_archive/handlers/*.rb
    # loaded at end of file
  end

  @@handlers ||= []
  # Adds an archive handler to the list used.  Provided handler must be a
  # subclass of +RubyArchive::Handler+
  def self.add_handler_class handler_class
    unless (handler_class.is_a? Class) && (handler_class <= RubyArchive::Handler)
      raise TypeError, "#{handler_class} is not a RubyArchive::Handler"
    end
    @@handlers << handler_class
    true
  end

  # Finds the appropriate +RubyArchive::Handler+ subclass for a given location.
  # Returns nil if no supported handler found.
  def self.find_handler_class location
    @@handlers.each do |h|
      return h if h.handles?(location)
    end
    return nil
  end

  @@loaded_archives ||= {}
  # Retrieves an archive from the loaded_archives cache, or automatically
  # loads the archive.  Returns the archive on success.  Returns nil if
  # archive is not available and autoload is false.  Raises +LoadError+
  # if autoload is attempted and fails.
  def self.get location, autoload=true
    @@handlers.each do |h|
      normalized = h.normalize_path(location)
      return @@loaded_archives[normalized] if @@loaded_archives.has_key?(normalized)
    end
    return load(location) if autoload
    nil
  end

  # Loads the specified archive location.  Returns the handler object on
  # success.  Raises +LoadError+ if no handler can be found or it does not
  # exist.  May also raise exceptions passed along by creating the handler.
  def self.load location
    handler_class = find_handler_class(location)
    if handler_class.nil?
      raise LoadError, "No handler found or does not exist for archive -- #{location}"
    end
    archive = handler_class.new(location)
    @@loaded_archives[archive.name] = archive
  end

end

# load builtin handlers
Dir.glob(
         File.expand_path('../ruby_archive/handlers/*.rb',__FILE__)
          ).each { |file| load(file,false) }
