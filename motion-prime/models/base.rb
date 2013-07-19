motion_require '../helpers/has_authorization'
module MotionPrime
  class BaseModel < NanoStore::Model
    class_attribute :sync_url
    class_attribute :sync_attributes
    class_attribute :_associations
    alias_method :attributes, :info
    include MotionPrime::HasAuthorization

    def sync_url
      self.class.sync_url.to_s.gsub(':id', id.to_s)
    end

    def model_name
      self.class.name.underscore
    end

    def new_record?
      id.blank?
    end

    def destroy(&block)
      use_callback = block_given?
      api_client.delete(sync_url) do
        block.call() if use_callback
      end
      delete
    end

    # fetch attributes from url
    def sync_with_url(url, &block)
      api_client.get(url) do |data|
        if data.present?
          sync_with_attributes(data, &block)
        end
      end
    end

    def update_with_url(url, &block)
      use_callback = block_given?
      post_data = { model_name => filtered_sync_attributes}
      api_client.send(id ? :put : :post, url, post_data) do |data|
        self.id ||= data['id']
        block.call() if use_callback
      end
    end

    # set attributes
    def sync_with_attributes(attrs, &block)
      attrs.each do |key, value|
        if respond_to?(:"sync_#{key}")
          self.send(:"sync_#{key}", value)
        elsif respond_to?(:"#{key}=")
          self.send(:"#{key}=", value)
        end
      end
      block.call(self) if block_given?
    end

    def sync!(sync_options = {}, &block)
      sync(sync_options.merge(save: true), &block)
    end

    # sync with url and
    # TODO: order of fetch/update should be based on updated time
    def sync(sync_options = {}, &block)
      use_callback = block_given?
      should_fetch = sync_options[:fetch]
      should_update = sync_options[:update]

      should_fetch = !new_record? if should_fetch.nil?
      should_update = new_record? if should_update.nil?

      sync_with_url self.sync_url do
        save if sync_options[:save]
        block.call if use_callback
      end if should_fetch
      update_with_url self.sync_url do
        save if sync_options[:save]
        block.call if use_callback
      end if should_update

      sync_associations(sync_options)
    end

    def sync_associations(sync_options = {})
      (self.class._associations || []).each do |key, options|
        sync_association(key, sync_options)
      end
    end

    def sync_association(key, sync_options = {}, &block)
      options = self.class._associations[key]
      return unless options[:sync_url]
      options[:type] == :many ?
      sync_has_many(key, options, sync_options, &block) :
      sync_has_one(key, options, sync_options, &block)
    end

    def sync_has_many(key, options = {}, sync_options = {}, &block)
      old_collection = self.send(key)
      use_callback = block_given?
      puts "SYNC: started sync for #{key} in #{self.class.name}"
      api_client.get(options[:sync_url]) do |data|
        if data.present?
          # Update/Create existing records
          data.each do |attributes|
            model = old_collection.detect{ |model| model.id == attributes[:id]}
            unless model
              model = key.singularize.to_s.classify.constantize.new
              self.send(:"#{key}_bag") << model
            end
            model.sync_with_attributes(attributes)
            model.save if sync_options[:save]
          end
          old_collection.each do |old_model|
            model = data.detect{ |model| model[:id] == old_model.id}
            unless model
              old_model.delete
            end
          end
          save if sync_options[:save]
          puts "SYNC: finished sync for #{key} in #{self.class.name}"
          block.call if use_callback
        else
          puts "SYNC ERROR: failed sync for #{key} in #{self.class.name}"
          block.call if use_callback
        end
      end
    end

    def sync_has_one(key, options = {}, &block)
      # TODO: add implementation
    end

    def inspect
      "#<#{self.class}:0x#{self.object_id.to_s(16)}> " + BW::JSON.generate(attributes)
    end

    # NOTE: .clear method doesn't work, using removeArray hack for now
    def _clear_bag(bag_name)
      bag = self.send(bag_name.to_sym)
      bag_copy = bag.to_a.clone
      bag - bag.to_a # this removes association from model
      bag_copy.each(&:delete) # this removes collection from db
    end

    def filtered_sync_attributes
      return attributes if self.class.sync_attributes.blank?
      attributes.reject do |key, value|
        self.class.sync_attributes.exclude?(key.to_sym)
      end
    end

    class << self
      def sync_url(url = nil)
        url ? self.sync_url = url : super
      end

      def sync_attributes(*attrs)
        attrs ? self.sync_attributes = attrs : super
      end

      def has_one(association_name, options = {})
        bag_name = "#{association_name.pluralize}_bag"
        self.bag bag_name.to_sym

        self._associations ||= {}
        self._associations[association_name] = options.merge(type: :one)

        define_method("#{association_name}=") do |value|
          self._clear_bag(bag_name)

          self.send(:"#{bag_name}") << value
          value
        end
        define_method("#{association_name}_attributes=") do |value|
          self._clear_bag(bag_name)

          association = association_name.classify.constantize.new
          association.sync_with_attributes(value)
          association.save
          self.send(:"#{bag_name}") << association
          association
        end
        define_method("#{association_name}") do
          self.send(:"#{bag_name}").to_a.first
        end
      end

      def has_many(association_name, options = {})
        bag_name = "#{association_name}_bag"
        self.bag bag_name.to_sym

        self._associations ||= {}
        self._associations[association_name] = options.merge(type: :many)

        define_method("#{association_name}_attributes=") do |value|
          self._clear_bag(bag_name)

          association = []
          value.each do |attrs|
            model = association_name.classify.constantize.new
            model.sync_with_attributes(attrs)
            association << model
          end
          self.send(:"#{bag_name}=", association)
          association
        end
        define_method("#{association_name}=") do |value|
          self._clear_bag(bag_name)
          self.send(:"#{bag_name}=", value)
        end
        define_method("#{association_name}") do
          self.send(:"#{bag_name}").to_a
        end
      end
    end
  end
end