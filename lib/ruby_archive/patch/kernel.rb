module Kernel
  class << self
    unless Kernel.respond_to?('open_pipe')
      # Alias for the original +Kernel::open+
      alias open_pipe open
    end

    def open path,mode='r',perm=0666,&block
      if path[0] == '|'[0]
        return open_pipe(path,mode,&block)
      else
        return File::open(path,mode,perm,&block)
      end
    end
  end

  unless Kernel.respond_to?('original_kernel_open',true)
    # Alias for the original +Kernel#open+
    alias original_kernel_open open
  end

  def open name,*rest,&block
    Kernel::open(name,*rest,&block)
  end
  
  private :original_kernel_open, :open

  unless Kernel.respond_to?('original_kernel_load',true)
    # Alias for the original +Kernel#load+
    alias original_kernel_load load
  end

  def ruby_archive_load filename,wrap=false
    $LOAD_PATH.each do |path|
      full_path = File.expand_path(filename,path)

      to_eval = nil
      begin
        to_eval = File.read(full_path)
      rescue Exception
        next
      end

      if wrap
        Module.new.instance_eval(to_eval,full_path)
      else
        eval(to_eval,TOPLEVEL_BINDING,full_path)
      end
      return true

    end
    raise LoadError, "no such file to load -- #{filename}"
  end

  alias load ruby_archive_load
end
