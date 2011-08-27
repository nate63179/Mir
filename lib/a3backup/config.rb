

# The config class is used for storage of user settings and preferences releated to 
# S3 storage
module A3backup
  class UndefinedConfigValue < StandardError; end
    
  class Config
    
    def initialize(config_file)
      @config_file = config_file
      @settings, @database = nil, nil
    end
    
    # Validates configuration settings
    def valid?
      unless File.exist?(@config_file)
        A3backup.logger.error("Configuration file not found")
        return false
      end
      
      if File.directory?(@config_file)
        A3backup.logger.error("Received directory instead of settings file")
        return false
      end
      
      # This needs to be improved for fault tolerance
      File.open(@config_file) do |f|
        yml = YAML::load(f)
        if yml.key? "settings"
          @settings = OpenStruct.new yml["settings"]
          @settings.database = symbolize_keys(@settings.database)
          @settings.cloud_provider = symbolize_keys(@settings.cloud_provider)
        else
          A3backup.logger.error("Malformed config file")
          return false
        end
      end
      true
    end
    
    
        
    def method_missing(meth, *args, &block)
      val = @settings.send(meth)
      unless val.nil?
        val
      else
        raise UndefinedConfigValue
      end
    end
    
    private
      def symbolize_keys(hsh)
        symbolized = hsh.inject({}) do |opts, (k,v)|
          opts[(k.to_sym rescue k) || k] = v
          opts
        end
        symbolized
      end
    
  end
end