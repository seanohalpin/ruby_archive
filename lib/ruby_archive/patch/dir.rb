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
    # This code is basically +File.forward_method_multi+ adapted for Dir.glob and the like
    def forward_method_array method, min_arguments=1, array_index=0
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
          args_before_array = nil
          if #{array_index} == 0
            args_before_array = []
          else
            args_before_array = args[0..#{array_index - 1}]
          end
          args_after_array = args[#{array_index + 1}..(args.size - 1)]

          path_list = args[#{array_index}]

          results = []
          path_list.each do |path|
            location_info = File.in_archive?(path)
            if location_info == false
              args_to_send = args_before_array + [path] + args_after_array
              results += Dir.send(:#{alias_name},*args_to_send)
              next
            else
              begin
                dir_handler = RubyArchive.get(location_info[0]).dir
                raise NotImplementedError unless dir_handler.respond_to?(:#{method})
                args_to_send = args_before_array + [location_info[1]] + args_after_array
                get_array = dir_handler.send(:#{method},*args_to_send)
                results += get_array.map { |file| "\#{location_info[0]}!\#{file}" }
                next
              rescue NotImplementedError
                raise NotImplementedError, "#{method} not implemented in handler for specified archive"
              end
            end
          end
          return results
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
    def forward_method_unsupported method, min_arguments=1, path_args=[0], return_instead=:raise
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
              unless #{return_instead.inspect} == :raise
                warn "Dir.#{method} is not supported for files within archives"
                puts "#{return_instead.inspect}"
                return #{return_instead.inspect}
              end
              raise NotImplementedError, "Dir.#{method} is not supported for files within archives (yet)"
            end
          end
          
          Dir.send(:#{alias_name},*args)
        end
      }, @@ruby_archive_dir_class_bind, __FILE__, eval_line
    end
    #protected(:forward_method_unsupported)  # -- protecting this method makes rubinius choke

    Dir.forward_method_unsupported(:chdir)

    Dir.forward_method_unsupported(:chroot)

    Dir.forward_method_single(:delete)
    alias rmdir delete
    alias unlink delete

    Dir.forward_method_single(:entries)

    Dir.forward_method_unsupported(:foreach) # should be a target to support soon

    # getwd/pwd does not need to be forwarded

    Dir.forward_method_array(:glob,2,0) # should be a target to support soon
    def [](*glob); return Dir.glob(glob,0); end

    Dir.forward_method_single(:mkdir)

    Dir.forward_method_single(:open)

    # tmpdir does not need to be forwarded
  end
end
