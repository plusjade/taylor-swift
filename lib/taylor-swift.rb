require "taylor-swift/query"
require "taylor-swift/utils"
require "taylor-swift/settings"

module TaylorSwift
  class << self; attr_accessor :redis end
  
  StorageDeliminator = ":"
  ValidResourceTypes = [:items, :tags, :users]
  
  # These are instance methods that get included on all 3 models.
  #
  module Base

    def self.included(model)
      model.extend(ClassMethods)
    end

    # Record everything needed to make user<->rep tag associations.
    # We use redis to store associations and counts relative to those associations.
    #
    # Notes:
    #   TaylorSwift.redis.sadd returns bool for singular value additions.
    #   Bool value reflects whether the insertion was newly added.
    #
    def taylor_tag(*args)
      args << self
      data = {}
      args.each { |o| data[TaylorSwift::Settings.models.key(o.class)] = o }

      # Add ITEM to the USER'S total ITEM data relative to TAG
      is_new_tag_on_item_for_user = (TaylorSwift.redis.sadd data[:users].storage_key(:tag, data[:tags].taylor_resource_identifier, :items), data[:items].taylor_resource_identifier)

      TaylorSwift.redis.multi do
        # Add ITEM to the USERS's total ITEM data.
        TaylorSwift.redis.sadd data[:users].storage_key(:items), data[:items].taylor_resource_identifier

        # Add USER to the ITEM's total USER data
        TaylorSwift.redis.sadd data[:items].storage_key(:users), data[:users].taylor_resource_identifier

        # Add USER to the TAG's total USER data.
        TaylorSwift.redis.sadd data[:tags].storage_key(:users), data[:users].taylor_resource_identifier

        # Add ITEM to the TAG's total ITEM data.
        TaylorSwift.redis.sadd data[:tags].storage_key(:items), data[:items].taylor_resource_identifier

        if is_new_tag_on_item_for_user
          # Increment the USER's TAG count for TAG
          TaylorSwift.redis.zincrby data[:users].storage_key(:tags), 1, data[:tags].taylor_resource_identifier

          # Increment the ITEM's TAG count for TAG
          TaylorSwift.redis.zincrby data[:items].storage_key(:tags), 1, data[:tags].taylor_resource_identifier
        end

        # Add TAG to total TAG data
        TaylorSwift.redis.zincrby data[:tags].class.storage_key(:tags) , 1, data[:tags].taylor_resource_identifier

      end

      # Add TAG to USER's tag data relative to ITEM
      # (this is kept in a dictionary to save memory)
      tags_array = data[:users].taylor_get(:tags, :via => data[:items], :with_scores => false)
      tags_array.push(data[:tags].taylor_resource_identifier).uniq!
      TaylorSwift.redis.hset data[:users].storage_key(:items, :tags), data[:items].taylor_resource_identifier, ActiveSupport::JSON.encode(tags_array)

    end

    # Record everything needed to remove user<->item tag associations.
    # We use redis to store associations and counts relative to those associations.
    #
    # Notes:
    #   TaylorSwift.redis.srem returns bool for singular value additions.
    #   Bool value reflects whether the the key exist before it was removed.
    #
    def taylor_untag(*args)
      args << self
      data = {}
      args.each { |o| data[TaylorSwift::Settings.models.key(o.class)] = o }

      # Remove ITEM from the USER'S total ITEM data relative to TAG
      was_removed_tag_on_item_for_user = (TaylorSwift.redis.srem data[:users].storage_key(:tag, data[:tags].taylor_resource_identifier, :items), data[:items].taylor_resource_identifier)

      TaylorSwift.redis.multi do
        # Remove ITEM from the USERS's total ITEM data.
        TaylorSwift.redis.srem data[:users].storage_key(:items), data[:items].taylor_resource_identifier

        # Remove USER from the ITEM's total USER data
        TaylorSwift.redis.srem data[:items].storage_key(:users), data[:users].taylor_resource_identifier

        # Remove USER from the TAG's total USER data.
        TaylorSwift.redis.srem data[:tags].storage_key(:users), data[:users].taylor_resource_identifier

        # Remove ITEM from the TAG's total ITEM data.
        TaylorSwift.redis.srem data[:tags].storage_key(:items), data[:items].taylor_resource_identifier
      end

      if was_removed_tag_on_item_for_user
        # Decrement the USER's TAG count for TAG
        if(TaylorSwift.redis.zincrby data[:users].storage_key(:tags), -1, data[:tags].taylor_resource_identifier).to_i <= 0
          TaylorSwift.redis.zrem data[:users].storage_key(:tags), data[:tags].taylor_resource_identifier
        end

        # Decrement the ITEM's TAG count for TAG
        if (TaylorSwift.redis.zincrby data[:items].storage_key(:tags), -1, data[:tags].taylor_resource_identifier).to_i <= 0
          TaylorSwift.redis.zrem data[:items].storage_key(:tags), data[:tags].taylor_resource_identifier
        end
      end

      # Decrement TAG count in TAG data
      if (TaylorSwift.redis.zincrby data[:tags].class.storage_key(:tags), -1, data[:tags].taylor_resource_identifier).to_i <= 0
        TaylorSwift.redis.zrem data[:tags].class.storage_key(:tags), data[:tags].taylor_resource_identifier
      end

      # REMOVE TAG from USER's tag data relative to ITEM
      # (this is kept in a dictionary to save memory)
      tags_array = data[:users].taylor_get(:tags, :via => data[:items], :with_scores => false)
      tags_array.delete(data[:tags].taylor_resource_identifier)
      TaylorSwift.redis.hset data[:users].storage_key(:items, :tags), data[:items].taylor_resource_identifier, ActiveSupport::JSON.encode(tags_array)
    end

    # This is the main and recommended public interface for querying resources. 
    # Note:
    #   This method's Instance type determines the implied *scope* for this query.
    #
    # @param [:users, :items, :tags] response_type
    #   Type of resource we expect to return.
    # @param [Hash] conditions 
    #   Optional hash of conditions for filtering, limits, etc.
    #
    # @return [Array]
    # Returns and array of resource_identifiers of the type "response_type"
    #
    # @example
    #
    #   This will get all tags made by @user.
    #     @user.taylor_get(:tags)
    #    
    #   This will get the top 10 tags made by user on @item
    #     @user.taylor_get(:tags, :via => @item, :limit => 10) 
    #
    # Please see TaylorSwift::Query.dispatch for further documentation.
    #
    def taylor_get(response_type, conditions={})
      conditions[:scope] = self
      TaylorSwift::Query.dispatch(response_type, conditions)
    end

    # Create and return the storage key for the calling resource.
    # Namespace and scoping field is applied.
    #
    def storage_key(*args)
      args.map! { |v|
        TaylorSwift::Settings.get(:namespaces, v, false) || v
      }.unshift(self.taylor_resource_identifier)
      
      self.class.storage_key(*args)
    end

    # Return the field we are scoping on for this model instance.
    #
    def taylor_resource_identifier
      self.send TaylorSwift::Settings.get(:identifiers, TaylorSwift::Utils.get_type(self))
    end


    module ClassMethods

      def tell_taylor_swift(resource_type, opts={})
        if ValidResourceTypes.include?(resource_type.to_sym)
          TaylorSwift::Settings.set(:models, resource_type, self)
          TaylorSwift::Settings.set(:identifiers, resource_type, opts[:identifier].to_s)
          TaylorSwift::Settings.set(:namespaces, resource_type, opts[:namespace]) if opts[:namespace]
        else
          raise "Invalid Resource type. Can only use: #{ValidResourceTypes.inspect}"
        end
      end

      # This is the class-level public interface for querying resources.
      # Note: 
      #   This method's Class determines the implied *response_type* for this query.
      #
      # @param [:users, :items, :tags] response_type
      #   Type of resource we expect to return.
      # @param [Hash] conditions 
      #   Optional hash of conditions for filtering, limits, etc.
      #
      # @return [Array]
      # Returns an array of resource_identifiers of the type *response_type*
      #
      # @example
      #
      #   This will get all tags.
      #     Tag.taylor_get
      #    
      #   This will get the top 10 tags on this @item
      #     Tag.taylor_get(:via => @item, :limit => 10) 
      #
      # Please see TaylorSwift::Query.dispatch for further documentation.
      #
      def taylor_get(conditions={})
        conditions[:scope] = self
        TaylorSwift::Query.dispatch(TaylorSwift::Utils.get_type(self), conditions)
      end

      # Create and return the storage for the calling class.
      # Note the keys are namepsaced with the calling class resource_type.
      #
      def storage_key(*args)
        args.unshift(
        TaylorSwift::Settings.get(:namespaces, TaylorSwift::Utils.get_type(self)),
        ).map! { |v| 
          v.to_s.gsub(StorageDeliminator, "") 
        }.join(StorageDeliminator)
      end

    end # ClassMethods


  end # Base


  
end # TaylorSwift
