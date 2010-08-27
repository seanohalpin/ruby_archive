class File
  class << self
    MY_BIND = binding
    ONLY_ONE_DEEP = "Malformed archive location -- only one level deep supported (for now)"

    unless File.respond_to?('original_open')
      # Alias for the original +File::open+
      alias original_open open
    end

    #private
    def forward_method method, path_arg_index
      #class << self
#      method = :'#{method}' ; path_arg_index = #{path_arg_index}
      aliased_name = "original_#{method}".intern
      
      alias_method(aliased_name,method)
      private(aliased_name)
      
      define_method(method) do |*args|
        args_before = args[0..(path_arg_index-1)]
        path = args[path_arg_index]
        args_after = args[(path_arg_index+1)..(args.size-1)]
        
        if File.original_exist?(path)
          return File.send(aliased_name,*args)
        end
        sp = path.split('!')
        if sp.size <= 1
          File.send(aliased_name,*args)
        elsif sp.size == 2
          args_to_send = args_before + [sp[1]] + args_after
          RubyArchive.get(sp[0]).file.send(method,*args_to_send)
          puts("sent file.#{method}("+args_to_send.join(',')+")")
        else
          raise ArgumentError, ONLY_ONE_DEEP
        end         
      end
      #end
    end

    public
    # Open a file, either from the filesystem or from within an archive.
    # If the given path exists on the filesystem, it will be opened from
    # there.  Otherwise the path will be split by delimiter +!+ and
    # checked again.
    #
    # TODO: 'perm' is currently ignored by anything sent to an archive,
    # due to incompatibility with rubyzip.
    def open path,mode='r',perm=0666,&block # 0666 from io.c in MRI
      if File.original_exist?(path)
        return File.original_open(path,mode,perm,&block)
      end
      sp = path.split('!')
      if sp.size <= 1
        return File.original_open(path,mode,perm,&block)
      elsif sp.size == 2
        f = RubyArchive.get(sp[0]).file.open(sp[1],mode) # perm ignored
        return f if block.nil?
        begin
          return yield(f)
        ensure
          f.close
        end
      else
        raise ArgumentError, ONLY_ONE_DEEP
      end
    end

    unless File.respond_to?('original_exist?')
      # Alias for the original +File::exist?+
      alias original_exist? exist?
    end

    # Determine if a file exists, either on the filesystem or within an
    # archive.  Returns +true+ if the named file exists, +false+ otherwise.
    def exist? path
      return true if File.original_exist?(path)
      sp = path.split('!')
      if sp.size <= 1
        return File.original_exist?(path)
      elsif sp.size == 2
        return RubyArchive.get(sp[0]).file.exist?(sp[1])
      else
        raise ArgumentError, ONLY_ONE_DEEP
      end
    end
    alias exists? exist? #(obsolete alias)

    #unless File.respond_to?('original_file?')
      # Alias for the original +File::file?+
    #  alias original_file? file?
    #end

    # Determine if a file exists, either on the filesystem or within an archive.
    # Returns +true+ if the named file exists and is a regular file, +false+ otherwise.
    #def file? path
    #  return true if File.original_file?(path)
    #  sp = path.split('!')
    #  if sp.size <= 1
    #    return File.original_file?(path)
    #  elsif sp.size == 2
    #    return RubyArchive.get(sp[0]).file.file?(sp[1])
    #  else
    #    raise ArgumentError, ONLY_ONE_DEEP
    #  end
    #end
    File.forward_method(:file?, 0)

    #unless File.respond_to?('original_directory?')
      # Alias for the original +File::directory?+
    #  alias original_directory? directory?
    #end

    # Determine if a directory exists, either on the filesystem or within an
    # archive.  Returns +true+ if the named file is a directory, +false+ otherwise.
    #def directory? path
    #  return true if File.original_directory?(path)
    #  sp = path.split('!')
    #  if sp.size <= 1
    #    return File.original_directory?(path)
    #  elsif sp.size == 2
    #    return RubyArchive.get(sp[0]).file.directory?(sp[1])
    #  else
    #    raise ArgumentError, ONLY_ONE_DEEP
    #  end
    #end
    File.forward_method(:directory?, 0)

    unless File.respond_to?('original_delete')
      # Alias for the original +File::delete+
      alias original_delete delete
    end

    # Deletes the named files, returning the number of names passed as arguments.
    # Raises an exception on any error.
    def delete(*files)
      files.each do |path|
        if File.original_exist?(path)
          File.original_delete(path)
          next
        end
        sp = path.split('!')
        if sp.size <= 1
          File.original_delete(path)
        elsif sp.size == 2
          RubyArchive.get(sp[0]).file.delete(sp[1])
        else
          raise ArgumentError, ONLY_ONE_DEEP
        end
      end
      return files.size
    end
    alias unlink delete

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
