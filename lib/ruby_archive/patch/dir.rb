class Dir
  class << self
    @@ruby_archive_dir_class_bind = binding

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
    #
    # This code is heavily duplicated from +File.forward_method_single+ - I would like
    # to make the same code work in two different places but couldn't quickly find
    # a way.
    def forward_method_single method, min_arguments=1, path_arg_index=0, on_load_error=nil
      alias_name = "ruby_archive_original_#{method}".intern
      eval_line = __LINE__; eval %{
        unless Dir.respond_to?(:#{alias_name})
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
            return Dir.send(:#{alias_name},*args)
          else
            begin
              dir_handler = RubyArchive.get(location_info[0]).dir
              raise NotImplementedError unless dir_handler.respond_to?(:#{method})
              args_to_send = args_before_path + [location_info[1]] + args_after_path
              return dir_handler.send(:#{method},*args_to_send)
            rescue LoadError
              raise if #{on_load_error.inspect}.nil?
              return #{on_load_error.inspect}
            rescue NotImplementedError
              raise NotImplementedError, "#{method} not implemented in handler for specified archive"
            end
          end
        end
      }, @@ruby_archive_dir_class_bind, __FILE__, eval_line
    end
    #protected(:forward_method_single)  # -- protecting this method makes rubinius choke

    # See +forward_method_single+.  Does nearly the same thing, but assumes
    # the argument list ends with a list of files to operate on rather than
    # a single file to operate on.
    #
    # This code is heavily duplicated from +File.forward_method_multi+ - I would like
    # to make the same code work in two different places but couldn't quickly find
    # a way.
    def forward_method_multi method, min_arguments=1, first_path_arg_index=0
      alias_name = "ruby_archive_original_#{method}".intern
      eval_line = __LINE__; eval %{
        unless Dir.respond_to?(:#{alias_name})
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
              Dir.send(:#{alias_name},*args_to_send)
              next
            else
              begin
                dir_handler = RubyArchive.get(location_info[0]).dir
                raise NotImplementedError unless dir_handler.respond_to?(:#{method})
                args_to_send = args_before_path + [location_info[1]]
                dir_handler.send(:#{method},*args_to_send)
                next
              rescue NotImplementedError
                raise NotImplementedError, "#{method} not implemented in handler for specified archive"
              end
            end         
          end
          return path_list.size
        end
      }, @@ruby_archive_dir_class_bind, __FILE__, eval_line
    end
    #protected(:forward_method_multi)  # -- protecting this method makes rubinius choke

    # Marks a function as unsupported by archives.  path_args should be an array
    # of argument indices containing filepaths to check.
    #
    # This code is heavily duplicated from +File.forward_method_unsupported+ - I would like
    # to make the same code work in two different places but couldn't quickly find
    # a way.
    def forward_method_unsupported method, min_arguments=1, path_args=[0]
      alias_name = "ruby_archive_original_#{method}".intern
      eval_line = __LINE__; eval %{
        unless Dir.respond_to?(:#{alias_name})
          alias_method(:#{alias_name}, :#{method})
        end
        protected(:#{alias_name})

        define_method(:#{method}) do |*args|
          if (#{min_arguments} > 0 && args.size == 0)
            raise ArgumentError, "wrong number of arguments (0 for #{min_arguments})"
          end

          # grab args before the list of filepaths, and the list of filepaths
          #{path_args.inspect}.each do |i|
            if File.in_archive?(args[i]) != false
              raise NotImplementedError, "Dir.#{method} is not supported for files within archives (yet)"
            end
          end
          
          Dir.send(:#{alias_name},*args)
        end
      }, @@ruby_archive_dir_class_bind, __FILE__, eval_line
    end
    #protected(:forward_method_multi)  # -- protecting this method makes rubinius choke

#    unless File.respond_to?('ruby_archive_original_open')
      # Alias for the original +File::open+
#      alias ruby_archive_original_open open
#      protected(:ruby_archive_original_open)
#    end

    # Open a file, either from the filesystem or from within an archive.
    # If the given path exists on the filesystem, it will be opened from
    # there.  Otherwise the path will be split by delimiter +!+ and
    # checked again.
    #
    # TODO: 'perm' is currently ignored by anything sent to an archive,
    # due to incompatibility with rubyzip.
#    def open path,mode='r',perm=0666,&block # 0666 from io.c in MRI
#      if File.ruby_archive_original_exist?(path)
#        return File.ruby_archive_original_open(path,mode,perm,&block)
#      end
#      location_info = File.in_archive?(path)
#      if location_info == false
#        return File.ruby_archive_original_open(path,mode,perm,&block)
#      else
#        f = RubyArchive.get(location_info[0]).file.open(location_info[1],mode)
#        return f if block.nil?
#        begin
#          return yield(f)
#        ensure
#          f.close
#        end
#      end
#    end


    # Replacement for stock +File::read+
#    def read name,length=nil,offset=nil
#      ret = nil
#      self.open(name) do |f|
#        f.seek(offset) unless offset.nil?
#        ret = f.read(length)
#      end
#      ret
#    end

    Dir.forward_method_unsupported(:chdir)

    Dir.forward_method_unsupported(:chroot)

    Dir.forward_method_single(:delete)
    alias rmdir delete
    alias unlink delete

    Dir.forward_method_single(:entries)

    Dir.forward_method_unsupported(:foreach) # should be a target to support soon

    # getwd/pwd does not need to be forwarded

    Dir.forward_method_unsupported(:glob) # should be a target to support soon
    def [](glob); return Dir.glob(glob); end

    Dir.forward_method_single(:mkdir)

    Dir.forward_method_single(:open)

    # tmpdir does not need to be forwarded
  end
end
