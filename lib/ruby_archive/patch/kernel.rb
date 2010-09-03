require 'rbconfig'

module Kernel
  class << self
    unless Kernel.respond_to?('ruby_archive_original_open')
      # Alias for the original +Kernel::open+
      alias ruby_archive_original_open open
      protected(:ruby_archive_original_open)
    end

    def open path,mode='r',perm=0666,&block
      if path[0] == '|'[0]
        return ruby_archive_original_open(path,mode,&block)
      else
        return File::open(path,mode,perm,&block)
      end
    end
  end

  unless Kernel.respond_to?('ruby_archive_original_kernel_open',true)
    # Alias for the original +Kernel#open+
    alias ruby_archive_original_kernel_open open
  end

  def open name,*rest,&block
    Kernel::open(name,*rest,&block)
  end
  
  private :ruby_archive_original_kernel_open, :open

  unless Kernel.respond_to?('ruby_archive_original_kernel_load',true)
    # Alias for the original +Kernel#load+
    alias ruby_archive_original_kernel_load load
    private(:ruby_archive_original_kernel_load)
  end

  def load filename,wrap=false
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
  private(:load)

  unless Kernel.respond_to?('ruby_archive_original_kernel_require',true)
    # Alias for the original +Kernel#require+
    alias ruby_archive_original_kernel_require require
  end

  def load_path_find file
    $LOAD_PATH.each do |path|
      test = File.expand_path(file,path)
      return test if File.exist?(test)
    end
    return false
  end
  private(:load_path_find)

  # loads an extension given the _full path_
  def load_extension full_path
    unless File.in_archive?(full_path)
      ruby_archive_original_kernel_require(full_path)
    end
  end

  def require file
    return false if $LOADED_FEATURES.include?(file)
    rbext = '.rb'
    dlext = ".#{Config::CONFIG['DLEXT']}"
    ext = File.extname(file)
    if ext == rbext || ext == dlext
      f = load_path_find(file)
      unless f == false
        return false if $LOADED_FEATURES.include?(f)
        load(f,false) if ext == rbext
        load_extension(f) if ext == dlext
        $LOADED_FEATURES << f
        return true
      end
    end

    return false if $LOADED_FEATURES.include?("#{file}#{rbext}")
    # search for "file.rb"
    f = load_path_find("#{file}#{rbext}")
    unless f == false
      return false if $LOADED_FEATURES.include?(f)
      load(f,false)
      $LOADED_FEATURES << f
      return true
    end

    return false if $LOADED_FEATURES.include?("#{file}#{dlext}")
    # search for "file.so"
    f = load_path_find("#{file}#{dlext}")
    unless f == false
      return false if $LOADED_FEATURES.include?(f)
      return load_extension(f)
      $LOADED_FEATURES << f
      return true
    end

    raise LoadError, "no such file to load -- #{file}"
  end
  private(:require)
end
