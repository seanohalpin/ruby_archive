class File
  class << self
    unless File.respond_to?('open_from_filesystem')
      # Alias for the original +File::open+
      alias open_from_filesystem open
    end

    # Open a file, either from the filesystem or from within an archive.
    # If the given path exists on the filesystem, it will be opened from
    # there.  Otherwise the path will be split by delimiter +!+ and
    # checked again.
    #
    # TODO: 'perm' is currently ignored by anything sent to an archive,
    # due to incompatibility with rubyzip.
    def open path,mode='r',perm=0666,&block # 0666 from io.c in MRI
      if File.exist?(path)
        return File.open_from_filesystem(path,mode,perm,&block)
        return f if block.nil?
        begin
          return yield(f)
        ensure
          f.close
        end
      end
      sp = path.split('!')
      if sp.size <= 1
        return File.open_from_filesystem(path,mode,perm,&block)
        return f if block.nil?
        begin
          return yield(f)
        ensure
          f.close
        end
      elsif sp.size == 2
        f = RubyArchive.get(sp[0]).file.open(sp[1],mode) # perm ignored
        return f if block.nil?
        begin
          return yield(f)
        ensure
          f.close
        end
      else
        raise ArgumentError, "Malformed archive location -- only one level deep supported (for now)"
      end
    end

    # Replacement for stock +File::new+, simply calling new +File::open+
    #def new path,mode=nil,perm=nil
    #  open(path,mode,perm)
    #end

    # Replacement for stock +File::read+
    def read name,length=nil,offset=nil
      ret = nil
      self.open(name) do |f|
        f.seek(offset) unless offset.nil?
        ret = f.read(length)
      end
      ret
    end
  end
end
