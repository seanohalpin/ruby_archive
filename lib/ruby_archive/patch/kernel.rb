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
  private(:ruby_archive_original_kernel_open, :open)

  unless Kernel.respond_to?('ruby_archive_original_kernel_load',true)
    # Alias for the original +Kernel#load+
    alias ruby_archive_original_kernel_load load
    private(:ruby_archive_original_kernel_load)
  end

  def load filename,wrap=false
    # define errors to rescue original require from (exception for rubinius)
    rescue1 = rescue2 = LoadError
    rescue2 = Rubinius::CompileError if defined?(Rubinius::CompileError)

    # use original load if it works
    begin
      return ruby_archive_original_kernel_load(filename,wrap)
    rescue rescue1, rescue2
      puts 'failed original load'
      # otherwise, try our re-implementation of require
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
  end
  private(:load)

  # loads an extension given the _full path_
  def load_extension full_path
    orig_loaded_features = $LOADED_FEATURES.dup
    unless File.in_archive?(full_path)
      ruby_archive_original_kernel_require(full_path)
    else
      raise LoadError, "Can't load native extensions from archives (yet)"
    end
    $LOADED_FEATURES.replace(orig_loaded_features)
    return true
  end

  unless Kernel.respond_to?('ruby_archive_original_kernel_require',true)
    # Alias for the original +Kernel#require+
    alias ruby_archive_original_kernel_require require
  end

  def require file
    # define errors to rescue original require from (exception for rubinius)
    rescue1 = rescue2 = LoadError
    rescue2 = Rubinius::CompileError if defined?(Rubinius::CompileError)

    # use original require if it works
    begin
      return ruby_archive_original_kernel_require(file)
    rescue rescue1, rescue2
      # otherwise, try our re-implementation of require
      return false if $LOADED_FEATURES.include?(file)
      rbext = '.rb'
      dlext = ".#{Config::CONFIG['DLEXT']}"
      ext = File.extname(file)
      if ext == rbext || ext == dlext
        f = require_path_find(file)
        unless f == false
          return false if $LOADED_FEATURES.include?(f)
          load(f,false) if ext == rbext
          load_extension(f) if ext == dlext
          $LOADED_FEATURES << f
          return true
        end
      end
      
      # search for "file.rb"
      return false if $LOADED_FEATURES.include?("#{file}#{rbext}")
      f = require_path_find("#{file}#{rbext}")
      unless f == false
        return false if $LOADED_FEATURES.include?(f)
        load(f,false)
        $LOADED_FEATURES << f
        return true
      end

      # search for "file.so"
      return false if $LOADED_FEATURES.include?("#{file}#{dlext}")
      f = require_path_find("#{file}#{dlext}")
      unless f == false
        return false if $LOADED_FEATURES.include?(f)
        load_extension(f)
        $LOADED_FEATURES << f
        return true
      end
      
      raise LoadError, "no such file to load -- #{file}"
    end
  end
  private(:require)

  def require_path_find file
    $LOAD_PATH.each do |path|
      test = File.expand_path(file,path)
      return test if File.exist?(test)
    end
    return false
  end
  private(:require_path_find)
end
