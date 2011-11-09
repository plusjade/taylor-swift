module TaylorSwift

  module Settings

    @@resource_settings = {
      :models => {
        :items => "", 
        :tags  => "", 
        :users => ""
      },
      :namespaces => {
        :items => "ITEMS", 
        :tags  => "TAGS", 
        :users => "USERS" 
      },
      :identifiers => {
        :items => "", 
        :tags  => "", 
        :users => ""
      }
    }

    def self.models
      @@resource_settings[:models]
    end
    
    def self.namespaces
      @@resource_settings[:namespaces]
    end
    
    def self.identifiers
      @@resource_settings[:identifiers]
    end
    
    def self.get(setting, resource_type, strict = true)
      setting = @@resource_settings[setting.to_sym][resource_type]
      if setting.nil? && strict != false
        raise "Failed to get TaylorSwift::Settings => setting:'#{setting}', resource_type: '#{resource_type}'." 
      end

      setting
    end

    def self.set(setting, resource_type, value)
      @@resource_settings[setting.to_sym][resource_type.to_sym] = value
    end

  end # Settings
  
end # TaylorSwift
