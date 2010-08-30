class File
  class << self
    @@ruby_archive_file_class_bind = binding
    ONLY_ONE_DEEP = "Malformed archive location -- only one level deep supported (for now)"

    unless File.respond_to?('original_open')
      # Alias for the original +File::open+
      alias original_open open
    end

    def forward_method method, path_arg_index = 0
      alias_name = "ruby_archive_original_#{method}".intern
      eval_line = __LINE__; eval %{
        unless File.respond_to?(:#{alias_name})
          alias_method(:#{alias_name}, :#{method})
        end
        protected(:#{alias_name})

        define_method(:#{method}) do |*args|
          args_before_path = nil
          if #{path_arg_index} == 0
            args_before_path = []
          else
            args_before_path = args[0..(#{path_arg_index - 1})]
          end
          path = args[#{path_arg_index}]
          args_after_path = args[(#{path_arg_index + 1})..(args.size-1)]
        
          if File.ruby_archive_original_exist?(path)
            return File.send(:#{alias_name},*args)
          end
          sp = path.split('!')
          if sp.size <= 1
            return File.send(:#{alias_name},*args)
          elsif sp.size == 2
            args_to_send = args_before_path + [sp[1]] + args_after_path
            return RubyArchive.get(sp[0]).file.send(:#{method},*args_to_send)
          else
            raise ArgumentError, ONLY_ONE_DEEP
          end         
        end
      }, @@ruby_archive_file_class_bind, __FILE__, eval_line
    end
    protected(:forward_method)

    # Open a file, either from the filesystem or from within an archive.
    # If the given path exists on the filesystem, it will be opened from
    # there.  Otherwise the path will be split by delimiter +!+ and
    # checked again.
    #
    # TODO: 'perm' is currently ignored by anything sent to an archive,
    # due to incompatibility with rubyzip.
    def open path,mode='r',perm=0666,&block # 0666 from io.c in MRI
      if File.ruby_archive_original_exist?(path)
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

    File.forward_method(:exist?,0)
    alias exists? exist? #(obsolete alias)

    File.forward_method(:file?, 0)

    File.forward_method(:directory?, 0)

    unless File.respond_to?('original_delete')
      # Alias for the original +File::delete+
      alias original_delete delete
    end

  end
end
