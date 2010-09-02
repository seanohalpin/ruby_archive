class File
  class << self
    @@ruby_archive_file_class_bind = binding
    ONLY_ONE_DEEP = "Malformed archive location -- only one level deep supported (for now)"

    # Determines whether a specified location appears to be within an archive.
    # It first checks if the given location exists on the filesystem, and if
    # not check if there is an '!' mark in the filename.
    #
    # Returns an array of [archive_path, file_inside_archive] if location appears
    # to be in an archive, +false+ otherwise.
    def in_archive? path
      return false if File.ruby_archive_original_exist?(path)
      sp = path.split('!')
      return sp if sp.size == 2
      raise ArgumentError, ONLY_ONE_DEEP if sp.size > 2
      return false
    end

    # Automates creating class methods that operate on either normal files
    # or files within archives, given a symbol with the name of the method
    # and the index of the argument containing the file name.
    #
    # It performs tasks in the following order:
    # * alias the original method to ruby_archive_original_{method name},
    #   marks the alias as protected.
    # * overrides the class method so that it tries, in order:
    #    1. returns the result of the original class method if the given file exists
    #    2. returns the result of the original class method if an archive is not specified
    #    3. returns the result of the archive handler method if an archive is specified
    #
    # The current method of doing this is kind of ugly and involves 'eval',
    # but it works(tm).  This method is definitely a candidate for improvement.
    def forward_method_single method, min_arguments=1, path_arg_index=0
      alias_name = "ruby_archive_original_#{method}".intern
      eval_line = __LINE__; eval %{
        unless File.respond_to?(:#{alias_name})
          alias_method(:#{alias_name}, :#{method})
        end
        protected(:#{alias_name})

        define_method(:#{method}) do |*args|
          if (#{min_arguments} > 0 && args.size == 0)
            raise ArgumentError, "wrong number of arguments (0 for #{min_arguments})"
          end

          # grab args before and after the filepath
          args_before_path = nil
          if #{path_arg_index} == 0
            args_before_path = []
          else
            args_before_path = args[0..(#{path_arg_index - 1})]
          end
          path = args[#{path_arg_index}]
          args_after_path = args[(#{path_arg_index + 1})..(args.size-1)]
        
          # get file location info and forward it to the appropriate method
          location_info = File.in_archive?(path)
          if location_info == false
            return File.send(:#{alias_name},*args)
          else
            begin
              file_handler = RubyArchive.get(location_info[0]).file
              raise NotImplementedError unless file_handler.respond_to?(:#{method})
              args_to_send = args_before_path + [location_info[1]] + args_after_path
              return file_handler.send(:#{method},*args_to_send)
            rescue NotImplementedError
              raise NotImplementedError, "#{method} not implemented in handler for specified archive"
            end
          end
        end
      }, @@ruby_archive_file_class_bind, __FILE__, eval_line
    end
    #protected(:forward_method_single)  # -- protecting this method makes rubinius choke

    # See +forward_method_single+.  Does nearly the same thing, but assumes
    # the argument list ends with a list of files to operate on rather than
    # a single file to operate on.
    def forward_method_multi method, min_arguments=1, first_path_arg_index=0
      alias_name = "ruby_archive_original_#{method}".intern
      eval_line = __LINE__; eval %{
        unless File.respond_to?(:#{alias_name})
          alias_method(:#{alias_name}, :#{method})
        end
        protected(:#{alias_name})

        define_method(:#{method}) do |*args|
          if (#{min_arguments} > 0 && args.size == 0)
            raise ArgumentError, "wrong number of arguments (0 for #{min_arguments})"
          end

          # grab args before the list of filepaths, and the list of filepaths
          args_before_path = nil
          if #{first_path_arg_index} == 0
            args_before_path = []
          else
            args_before_path = args[0..(#{first_path_arg_index - 1})]
          end
          path_list = args[#{first_path_arg_index}..(args.size - 1)]

          path_list.each do |path|
            location_info = File.in_archive?(path)
            if location_info == false
              args_to_send = args_before_path + [path]
              File.send(:#{alias_name},*args_to_send)
              next
            else
              begin
                file_handler = RubyArchive.get(location_info[0]).file
                raise NotImplementedError unless file_handler.respond_to?(:#{method})
                args_to_send = args_before_path + [location_info[1]]
puts "sending #{method}\#{args_to_send.inspect}"
                file_handler.send(:#{method},*args_to_send)
                next
              rescue NotImplementedError
                raise NotImplementedError, "#{method} not implemented in handler for specified archive"
              end
            end         
          end
          return path_list.size
        end
      }, @@ruby_archive_file_class_bind, __FILE__, eval_line
    end
    #protected(:forward_method_multi)  # -- protecting this method makes rubinius choke

    unless File.respond_to?('ruby_archive_original_open')
      # Alias for the original +File::open+
      alias ruby_archive_original_open open
      protected(:ruby_archive_original_open)
    end

    # Open a file, either from the filesystem or from within an archive.
    # If the given path exists on the filesystem, it will be opened from
    # there.  Otherwise the path will be split by delimiter +!+ and
    # checked again.
    #
    # TODO: 'perm' is currently ignored by anything sent to an archive,
    # due to incompatibility with rubyzip.
    def open path,mode='r',perm=0666,&block # 0666 from io.c in MRI
      if File.ruby_archive_original_exist?(path)
        return File.ruby_archive_original_open(path,mode,perm,&block)
      end
      location_info = File.in_archive?(path)
      if location_info == false
        return File.ruby_archive_original_open(path,mode,perm,&block)
      else
        f = RubyArchive.get(location_info[0]).file.open(location_info[1],mode)
        return f if block.nil?
        begin
          return yield(f)
        ensure
          f.close
        end
      end
    end


    # Replacement for stock +File::read+
    def read name,length=nil,offset=nil
      ret = nil
      self.open(name) do |f|
        f.seek(offset) unless offset.nil?
        ret = f.read(length)
      end
      ret
    end

    File.forward_method_single(:atime)

    # basename does not need to be forwarded

    File.forward_method_single(:blockdev?)

    # catname does not need to be forwarded

    File.forward_method_single(:chardev?)

    File.forward_method_multi(:chmod,1,1)

    File.forward_method_multi(:chown,2,2)

    File.forward_method_single(:ctime)

    File.forward_method_multi(:delete,0,0)
    alias unlink delete

    File.forward_method_single(:directory?)

    # dirname does not need to be forwarded

    File.forward_method_single(:executable?)

    File.forward_method_single(:executable_real?)

    File.forward_method_single(:exist?)
    alias exists? exist? #(obsolete alias)

    # expand_path does not need to be forwarded

    # extname does not need to be forwarded

    File.forward_method_single(:file?)

    # fnmatch does not need to be forwarded

    File.forward_method_single(:ftype)

    File.forward_method_single(:grpowned?)

    # no replacement for identical right now

    # join does not need to be forwarded

    File.forward_method_multi(:lchmod,1,1)

    File.forward_method_multi(:lchown,2,2)

    #File.forward_method(:link

    File.forward_method_single(:lstat)

    File.forward_method_single(:mtime)

    File.forward_method_single(:owned?)

    File.forward_method_single(:pipe?)

    File.forward_method_single(:readable?)

    File.forward_method_single(:readable_real?)

    File.forward_method_single(:readlink)

    #File.forward_method(:rename

    File.forward_method_single(:setgid?)

    File.forward_method_single(:setuid?)

    File.forward_method_single(:size)

    File.forward_method_single(:size?)

    File.forward_method_single(:socket?)

    File.forward_method_single(:split)

    File.forward_method_single(:stat)

    File.forward_method_single(:sticky?)

    #File.forward_method(:symlink

    File.forward_method_single(:symlink?)

    #File.forward_method(:syscopy

    File.forward_method_single(:truncate)

    # umask does not need to be forwarded

    File.forward_method_multi(:utime,2,2)

    File.forward_method_single(:writable?)

    File.forward_method_single(:writable_real?)

    File.forward_method_single(:zero?)
  end
end
