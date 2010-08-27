module RubyArchive
  # RubyArchive::Handler
  class Handler
    # Should return true if the class can handle the given location as an
    # archive.  Returns false otherwise.  The default implementation always
    # returns false, this must be overridden in your subclasses.
    #
    # This method must NOT raise an exception.
    def self.handles? location
      false
    end

    # Should return a normalized version of the location specified.
    # +File.expand_path+ works well in many cases, and is provided as the
    # default.
    def self.normalize_path location
      File.expand_path(location)
    end

    # Initialize a handler object for the location given.  The default
    # implementation raises a +NotImplementedError+.
    #
    # Your implementation needs to set +@name+ to identify the archive
    def initialize location
      raise NotImplementedError, "Cannot initialize a handler of class #{self.class}"
    end

    # Close the handler.  This will be executed when +RubyArchive::close_all_archives+
    # is executed, or at_exit
    #
    # Should always return nil
    def close
      nil
    end

    # Should return a +File+-like object for the archive.  The default
    # implementation raises a +NotImplentedError+, must be overridden.
    def file
      raise NotImplementedError, "Cannot retrieve a file object for class #{self.class}"
    end

    # Should return a +Dir+-like object for the archive (optional)
    # Should return +nil+ if not supported.
    def dir
      nil
    end

    # reader for +@name+, which should be set in +initialize+
    attr_reader :name

    def inspect
      "<#{self.class}:#{self.name}>"
    end
  end
end
