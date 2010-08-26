Dir.glob(File.expand_path('../patch/*.rb',__FILE__)).each { |mod| load(mod) }
