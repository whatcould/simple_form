# frozen_string_literal: true
require 'active_support/core_ext/object/deep_dup'
require 'simple_form/map_type'
require 'simple_form/tags'

module SimpleForm
  class FormBuilder < ActionView::Helpers::FormBuilder
    attr_reader :template, :object_name, :object, :wrapper

    # When action is create or update, we still should use new and edit
    ACTIONS = {
      'create' => 'new',
      'update' => 'edit'
    }

    ATTRIBUTE_COMPONENTS = %i[html5 min_max maxlength minlength placeholder pattern readonly]

    extend MapType
    include SimpleForm::Inputs

    map_type :text, :hstore, :json, :jsonb,                        to: SimpleForm::Inputs::TextInput
    map_type :file,                                                to: SimpleForm::Inputs::FileInput
    map_type :string, :email, :search, :tel, :url, :uuid, :citext, to: SimpleForm::Inputs::StringInput
    map_type :password,                                            to: SimpleForm::Inputs::PasswordInput
    map_type :integer, :decimal, :float,                           to: SimpleForm::Inputs::NumericInput
    map_type :range,                                               to: SimpleForm::Inputs::RangeInput
    map_type :check_boxes,                                         to: SimpleForm::Inputs::CollectionCheckBoxesInput
    map_type :radio_buttons,                                       to: SimpleForm::Inputs::CollectionRadioButtonsInput
    map_type :rich_text_area,                                      to: SimpleForm::Inputs::RichTextAreaInput
    map_type :select,                                              to: SimpleForm::Inputs::CollectionSelectInput
    map_type :grouped_select,                                      to: SimpleForm::Inputs::GroupedCollectionSelectInput
    map_type :date, :time, :datetime,                              to: SimpleForm::Inputs::DateTimeInput
    map_type :country, :time_zone,                                 to: SimpleForm::Inputs::PriorityInput
    map_type :boolean,                                             to: SimpleForm::Inputs::BooleanInput
    map_type :hidden,                                              to: SimpleForm::Inputs::HiddenInput

    def self.discovery_cache
      @discovery_cache ||= {}
    end

    def initialize(*) #:nodoc:
      super
      @object   = convert_to_model(@object)
      @defaults = options[:defaults]
      @wrapper  = SimpleForm.wrapper(options[:wrapper] || SimpleForm.default_wrapper)
    end

    # Basic input helper, combines all components in the stack to generate
    # input html based on options the user define and some guesses through
    # database column information. By default a call to input will generate
    # label + input + hint (when defined) + errors (when exists), and all can
    # be configured inside a wrapper html.
    #
    # If a block is given, the contents of the block will replace the input
    # field that would otherwise be generated automatically. The content will
    # be given a label and wrapper div to make it consistent with the other
    # elements in the form.
    #
    # == Examples
    #
    #   # Imagine @user has error "can't be blank" on name
    #   simple_form_for @user do |f|
    #     f.input :name, hint: 'My hint'
    #   end
    #
    # This is the output html (only the input portion, not the form):
    #
    #     <label class="string required" for="user_name">
    #       <abbr title="required">*</abbr> Super User Name!
    #     </label>
    #     <input class="string required" id="user_name" maxlength="100"
    #        name="user[name]" type="text" value="Carlos" />
    #     <span class="hint">My hint</span>
    #     <span class="error">can't be blank</span>
    #
    # Each database type will render a default input, based on some mappings and
    # heuristic to determine which is the best option.
    #
    # You have some options for the input to enable/disable some functions:
    #
    #   as: allows you to define the input type you want, for instance you
    #          can use it to generate a text field for a date column.
    #
    #   required: defines whether this attribute is required or not. True
    #               by default.
    #
    # The fact SimpleForm is built in components allow the interface to be unified.
    # So, for instance, if you need to disable :hint for a given input, you can pass
    # hint: false. The same works for :error, :label and :wrapper.
    #
    # Besides the html for any component can be changed. So, if you want to change
    # the label html you just need to give a hash to :label_html. To configure the
    # input html, supply :input_html instead and so on.
    #
    # == Options
    #
    # Some inputs, as datetime, time and select allow you to give extra options, like
    # prompt and/or include blank. Such options are given in plainly:
    #
    #    f.input :created_at, include_blank: true
    #
    # == Collection
    #
    # When playing with collections (:radio_buttons, :check_boxes and :select
    # inputs), you have three extra options:
    #
    #   collection: use to determine the collection to generate the radio or select
    #
    #   label_method: the method to apply on the array collection to get the label
    #
    #   value_method: the method to apply on the array collection to get the value
    #
    # == Priority
    #
    # Some inputs, as :time_zone and :country accepts a :priority option. If none is
    # given SimpleForm.time_zone_priority and SimpleForm.country_priority are used respectively.
    #
    def input(attribute_name, options = {}, &block)
      options = @defaults.deep_dup.deep_merge(options) if @defaults

      input   = find_input(attribute_name, options, &block)
      wrapper = find_wrapper(input.input_type, options)

      wrapper.render input
    end
    alias :attribute :input

    # Creates a input tag for the given attribute. All the given options
    # are sent as :input_html.
    #
    # == Examples
    #
    #   simple_form_for @user do |f|
    #     f.input_field :name
    #   end
    #
    # This is the output html (only the input portion, not the form):
    #
    #     <input class="string required" id="user_name" maxlength="100"
    #        name="user[name]" type="text" value="Carlos" />
    #
    # It also support validation classes once it is configured.
    #
    #   # config/initializers/simple_form.rb
    #   SimpleForm.setup do |config|
    #     config.input_field_valid_class = 'is-valid'
    #     config.input_field_error_class = 'is-invalid'
    #   end
    #
    #   simple_form_for @user do |f|
    #     f.input_field :name
    #   end
    #
    # When the validation happens, the input will be rendered with
    # the class configured according to the validation:
    #
    # - when the input is valid:
    #
    #     <input class="is-valid string required" id="user_name" value="Carlos" />
    #
    # - when the input is invalid:
    #
    #     <input class="is-invalid string required" id="user_name" value="" />
    #
    def input_field(attribute_name, options = {})
      components = (wrapper.components.map(&:namespace) & ATTRIBUTE_COMPONENTS)

      options = options.dup
      options[:input_html] = options.except(:as, :boolean_style, :collection, :disabled, :label_method, :value_method, :prompt, *components)
      options = @defaults.deep_dup.deep_merge(options) if @defaults

      input      = find_input(attribute_name, options)
      wrapper    = find_wrapper(input.input_type, options)
      components = build_input_field_components(components.push(:input))

      SimpleForm::Wrappers::Root.new(components, wrapper.options.merge(wrapper: false)).render input
    end

    # Helper for dealing with association selects/radios, generating the
    # collection automatically. It's just a wrapper to input, so all options
    # supported in input are also supported by association. Some extra options
    # can also be given:
    #
    # == Examples
    #
    #   simple_form_for @user do |f|
    #     f.association :company          # Company.all
    #   end
    #
    #   f.association :company, collection: Company.all(order: 'name')
    #   # Same as using :order option, but overriding collection
    #
    # == Block
    #
    # When a block is given, association simple behaves as a proxy to
    # simple_fields_for:
    #
    #   f.association :company do |c|
    #     c.input :name
    #     c.input :type
    #   end
    #
    # From the options above, only :collection can also be supplied.
    #
    # Please note that the association helper is currently only tested with Active Record. Depending on the ORM you are using your mileage may vary.
    #
    def association(association, options = {}, &block)
      options = options.dup

      return simple_fields_for(*[association,
        options.delete(:collection), options].compact, &block) if block_given?

      raise ArgumentError, "Association cannot be used in forms not associated with an object" unless @object

      reflection = find_association_reflection(association)
      raise "Association #{association.inspect} not found" unless reflection

      options[:as] ||= :select
      options[:collection] ||= fetch_association_collection(reflection, options)

      attribute = build_association_attribute(reflection, association, options)

      input(attribute, options.merge(reflection: reflection))
    end

    # Creates a button:
    #
    #   form_for @user do |f|
    #     f.button :submit
    #   end
    #
    # It just acts as a proxy to method name given. We also alias original Rails
    # button implementation (3.2 forward (to delegate to the original when
    # calling `f.button :button`.
    #
    alias_method :button_button, :button
    def button(type, *args, &block)
      options = args.extract_options!.dup
      options[:class] = [SimpleForm.button_class, options[:class]].compact
      args << options
      if respond_to?(:"#{type}_button")
        send(:"#{type}_button", *args, &block)
      else
        send(type, *args, &block)
      end
    end

    # Creates an error tag based on the given attribute, only when the attribute
    # contains errors. All the given options are sent as :error_html.
    #
    # == Examples
    #
    #    f.error :name
    #    f.error :name, id: "cool_error"
    #
    def error(attribute_name, options = {})
      options = options.dup

      options[:error_html] = options.except(:error_tag, :error_prefix, :error_method)
      column      = find_attribute_column(attribute_name)
      input_type  = default_input_type(attribute_name, column, options)
      wrapper.find(:error).
        render(SimpleForm::Inputs::Base.new(self, attribute_name, column, input_type, options))
    end

    # Return the error but also considering its name. This is used
    # when errors for a hidden field need to be shown.
    #
    # == Examples
    #
    #    f.full_error :token #=> <span class="error">Token is invalid</span>
    #
    def full_error(attribute_name, options = {})
      options = options.dup

      options[:error_prefix] ||= if object.class.respond_to?(:human_attribute_name)
        object.class.human_attribute_name(attribute_name.to_s)
      else
        attribute_name.to_s.humanize
      end

      error(attribute_name, options)
    end

    # Creates a hint tag for the given attribute. Accepts a symbol indicating
    # an attribute for I18n lookup or a string. All the given options are sent
    # as :hint_html.
    #
    # == Examples
    #
    #    f.hint :name # Do I18n lookup
    #    f.hint :name, id: "cool_hint"
    #    f.hint "Don't forget to accept this"
    #
    def hint(attribute_name, options = {})
      options = options.dup

      options[:hint_html] = options.except(:hint_tag, :hint)
      if attribute_name.is_a?(String)
        options[:hint] = attribute_name
        attribute_name, column, input_type = nil, nil, nil
      else
        column      = find_attribute_column(attribute_name)
        input_type  = default_input_type(attribute_name, column, options)
      end

      wrapper.find(:hint).
        render(SimpleForm::Inputs::Base.new(self, attribute_name, column, input_type, options))
    end

    # Creates a default label tag for the given attribute. You can give a label
    # through the :label option or using i18n. All the given options are sent
    # as :label_html.
    #
    # == Examples
    #
    #    f.label :name                     # Do I18n lookup
    #    f.label :name, "Name"             # Same behavior as Rails, do not add required tag
    #    f.label :name, label: "Name"      # Same as above, but adds required tag
    #
    #    f.label :name, required: false
    #    f.label :name, id: "cool_label"
    #
    def label(attribute_name, *args)
      return super if args.first.is_a?(String) || block_given?

      options = args.extract_options!.dup
      options[:label_html] = options.except(:label, :label_text, :required, :as)

      column      = find_attribute_column(attribute_name)
      input_type  = default_input_type(attribute_name, column, options)
      SimpleForm::Inputs::Base.new(self, attribute_name, column, input_type, options).label
    end

    # Creates an error notification message that only appears when the form object
    # has some error. You can give a specific message with the :message option,
    # otherwise it will look for a message using I18n. All other options given are
    # passed straight as html options to the html tag.
    #
    # == Examples
    #
    #    f.error_notification
    #    f.error_notification message: 'Something went wrong'
    #    f.error_notification id: 'user_error_message', class: 'form_error'
    #
    def error_notification(options = {})
      SimpleForm::ErrorNotification.new(self, options).render
    end

    # Create a collection of radio inputs for the attribute. Basically this
    # helper will create a radio input associated with a label for each
    # text/value option in the collection, using value_method and text_method
    # to convert these text/value. You can give a symbol or a proc to both
    # value_method and text_method, that will be evaluated for each item in
    # the collection.
    #
    # == Examples
    #
    #   form_for @user do |f|
    #     f.collection_radio_buttons :options, [[true, 'Yes'] ,[false, 'No']], :first, :last
    #   end
    #
    #   <input id="user_options_true" name="user[options]" type="radio" value="true" />
    #   <label class="collection_radio_buttons" for="user_options_true">Yes</label>
    #   <input id="user_options_false" name="user[options]" type="radio" value="false" />
    #   <label class="collection_radio_buttons" for="user_options_false">No</label>
    #
    # It is also possible to give a block that should generate the radio +
    # label. To wrap the radio with the label, for instance:
    #
    #   form_for @user do |f|
    #     f.collection_radio_buttons(
    #       :options, [[true, 'Yes'] ,[false, 'No']], :first, :last
    #     ) do |b|
    #       b.label { b.radio_button + b.text }
    #     end
    #   end
    #
    # == Options
    #
    # Collection radio accepts some extra options:
    #
    #   * checked  => the value that should be checked initially.
    #
    #   * disabled => the value or values that should be disabled. Accepts a single
    #                 item or an array of items.
    #
    #   * collection_wrapper_tag   => the tag to wrap the entire collection.
    #
    #   * collection_wrapper_class => the CSS class to use for collection_wrapper_tag
    #
    #   * item_wrapper_tag         => the tag to wrap each item in the collection.
    #
    #   * item_wrapper_class       => the CSS class to use for item_wrapper_tag
    #
    #   * a block                  => to generate the label + radio or any other component.
    def collection_radio_buttons(method, collection, value_method, text_method, options = {}, html_options = {}, &block)
      SimpleForm::Tags::CollectionRadioButtons.new(@object_name, method, @template, collection, value_method, text_method, objectify_options(options), @default_options.merge(html_options)).render(&block)
    end

    # Creates a collection of check boxes for each item in the collection,
    # associated with a clickable label. Use value_method and text_method to
    # convert items in the collection for use as text/value in check boxes.
    # You can give a symbol or a proc to both value_method and text_method,
    # that will be evaluated for each item in the collection.
    #
    # == Examples
    #
    #   form_for @user do |f|
    #     f.collection_check_boxes :options, [[true, 'Yes'] ,[false, 'No']], :first, :last
    #   end
    #
    #   <input name="user[options][]" type="hidden" value="" />
    #   <input id="user_options_true" name="user[options][]" type="checkbox" value="true" />
    #   <label class="collection_check_boxes" for="user_options_true">Yes</label>
    #   <input name="user[options][]" type="hidden" value="" />
    #   <input id="user_options_false" name="user[options][]" type="checkbox" value="false" />
    #   <label class="collection_check_boxes" for="user_options_false">No</label>
    #
    # It is also possible to give a block that should generate the check box +
    # label. To wrap the check box with the label, for instance:
    #
    #   form_for @user do |f|
    #     f.collection_check_boxes(
    #       :options, [[true, 'Yes'] ,[false, 'No']], :first, :last
    #     ) do |b|
    #       b.label { b.check_box + b.text }
    #     end
    #   end
    #
    # == Options
    #
    # Collection check box accepts some extra options:
    #
    #   * checked  => the value or values that should be checked initially. Accepts
    #                 a single item or an array of items. It overrides existing associations.
    #
    #   * disabled => the value or values that should be disabled. Accepts a single
    #                 item or an array of items.
    #
    #   * collection_wrapper_tag   => the tag to wrap the entire collection.
    #
    #   * collection_wrapper_class => the CSS class to use for collection_wrapper_tag. This option
    #                                 is ignored if the :collection_wrapper_tag option is blank.
    #
    #   * item_wrapper_tag         => the tag to wrap each item in the collection.
    #
    #   * item_wrapper_class       => the CSS class to use for item_wrapper_tag
    #
    #   * a block                  => to generate the label + check box or any other component.
    def collection_check_boxes(method, collection, value_method, text_method, options = {}, html_options = {}, &block)
      SimpleForm::Tags::CollectionCheckBoxes.new(@object_name, method, @template, collection, value_method, text_method, objectify_options(options), @default_options.merge(html_options)).render(&block)
    end

    # Extract the model names from the object_name mess, ignoring numeric and
    # explicit child indexes.
    #
    # Example:
    #
    # route[blocks_attributes][0][blocks_learning_object_attributes][1][foo_attributes]
    # ["route", "blocks", "blocks_learning_object", "foo"]
    #
    def lookup_model_names #:nodoc:
      @lookup_model_names ||= begin
        child_index = options[:child_index]
        names = object_name.to_s.scan(/(?!\d)\w+/).flatten
        names.delete(child_index) if child_index
        names.each { |name| name.gsub!('_attributes', '') }
        names.freeze
      end
    end

    # The action to be used in lookup.
    def lookup_action #:nodoc:
      @lookup_action ||= begin
        action = template.controller && template.controller.action_name
        return unless action
        action = action.to_s
        ACTIONS[action] || action
      end
    end

    private

    def fetch_association_collection(reflection, options)
      options.fetch(:collection) do
        relation = reflection.klass.all

        if reflection.respond_to?(:scope) && reflection.scope
          if reflection.scope.parameters.any?
            relation = reflection.klass.instance_exec(object, &reflection.scope)
          else
            relation = reflection.klass.instance_exec(&reflection.scope)
          end
        else
          order = reflection.options[:order]
          conditions = reflection.options[:conditions]
          conditions = object.instance_exec(&conditions) if conditions.respond_to?(:call)

          relation = relation.where(conditions) if relation.respond_to?(:where) && conditions.present?
          relation = relation.order(order) if relation.respond_to?(:order)
        end

        relation
      end
    end

    def build_association_attribute(reflection, association, options)
      case reflection.macro
      when :belongs_to
        (reflection.respond_to?(:options) && reflection.options[:foreign_key]) || :"#{reflection.name}_id"
      when :has_one
        raise ArgumentError, ":has_one associations are not supported by f.association"
      else
        if options[:as] == :select || options[:as] == :grouped_select
          html_options = options[:input_html] ||= {}
          html_options[:multiple] = true unless html_options.key?(:multiple)
        end

        # Force the association to be preloaded for performance.
        if options[:preload] != false && object.respond_to?(association)
          target = object.send(association)
          target.to_a if target.respond_to?(:to_a)
        end

        :"#{reflection.name.to_s.singularize}_ids"
      end
    end

    # Find an input based on the attribute name.
    def find_input(attribute_name, options = {}, &block)
      column     = find_attribute_column(attribute_name)
      input_type = default_input_type(attribute_name, column, options)

      if block_given?
        SimpleForm::Inputs::BlockInput.new(self, attribute_name, column, input_type, options, &block)
      else
        find_mapping(input_type).new(self, attribute_name, column, input_type, options)
      end
    end

    # Attempt to guess the better input type given the defined options. By
    # default always fallback to the user :as option, or to a :select when a
    # collection is given.
    def default_input_type(attribute_name, column, options)
      return options[:as].to_sym if options[:as]
      custom_type = find_custom_type(attribute_name.to_s) and return custom_type
      return :select             if options[:collection]

      input_type = column.is_a?(ActiveRecord::Encryption::EncryptedAttributeType) ? :string : column.try(:type)
      case input_type
      when :timestamp
        :datetime
      when :string, :citext, nil
        case attribute_name.to_s
        when /(?:\b|\W|_)password(?:\b|\W|_)/  then :password
        when /(?:\b|\W|_)time_zone(?:\b|\W|_)/ then :time_zone
        when /(?:\b|\W|_)country(?:\b|\W|_)/   then :country
        when /(?:\b|\W|_)email(?:\b|\W|_)/     then :email
        when /(?:\b|\W|_)phone(?:\b|\W|_)/     then :tel
        when /(?:\b|\W|_)url(?:\b|\W|_)/       then :url
        else
          file_method?(attribute_name) ? :file : (input_type || :string)
        end
      else
        input_type
      end
    end

    def find_custom_type(attribute_name)
      SimpleForm.input_mappings.find { |match, type|
        attribute_name =~ match
      }.try(:last) if SimpleForm.input_mappings
    end

    # Internal: Try to discover whether an attribute corresponds to a file or not.
    #
    # Most upload Gems add some kind of attributes to the ActiveRecord's model they are included in.
    # This method tries to guess if an attribute belongs to some of these Gems by checking the presence
    # of their methods using `#respond_to?`.
    #
    # Note: This does not support multiple file upload inputs, as this is very application-specific.
    #
    # The order here was chosen based on the popularity of Gems:
    #
    # - `#{attribute_name}_attachment` - ActiveStorage >= `5.2` and Refile >= `0.2.0` <= `0.4.0`
    # - `remote_#{attribute_name}_url` - Refile >= `0.3.0` and CarrierWave >= `0.2.2`
    # - `#{attribute_name}_attacher` - Refile >= `0.4.0` and Shrine >= `0.9.0`
    # - `#{attribute_name}_file_name` - Paperclip ~> `2.0` (added for backwards compatibility)
    #
    # Returns a Boolean.
    def file_method?(attribute_name)
      @object.respond_to?("#{attribute_name}_attachment") ||
        @object.respond_to?("#{attribute_name}_attachments") ||
        @object.respond_to?("remote_#{attribute_name}_url") ||
        @object.respond_to?("#{attribute_name}_attacher") ||
        @object.respond_to?("#{attribute_name}_file_name")
    end

    def find_attribute_column(attribute_name)
      if @object.respond_to?(:type_for_attribute) && @object.has_attribute?(attribute_name)
        @object.type_for_attribute(attribute_name.to_s)
      elsif @object.respond_to?(:column_for_attribute) && @object.has_attribute?(attribute_name)
        @object.column_for_attribute(attribute_name)
      end
    end

    def find_association_reflection(association)
      if @object.class.respond_to?(:reflect_on_association)
        @object.class.reflect_on_association(association)
      end
    end

    # Attempts to find a mapping. It follows the following rules:
    #
    # 1) It tries to find a registered mapping, if succeeds:
    #    a) Try to find an alternative with the same name in the Object scope
    #    b) Or use the found mapping
    # 2) If not, fallbacks to #{input_type}Input
    # 3) If not, fallbacks to SimpleForm::Inputs::#{input_type}Input
    def find_mapping(input_type)
      discovery_cache[input_type] ||=
        if mapping = self.class.mappings[input_type]
          mapping_override(mapping) || mapping
        else
          camelized = "#{input_type.to_s.camelize}Input"
          attempt_mapping_with_custom_namespace(camelized) ||
            attempt_mapping(camelized, Object) ||
            attempt_mapping(camelized, self.class) ||
            raise("No input found for #{input_type}")
        end
    end

    # Attempts to find a wrapper mapping. It follows the following rules:
    #
    # 1) It tries to find a wrapper for the current form
    # 2) If not, it tries to find a config
    def find_wrapper_mapping(input_type)
      if options[:wrapper_mappings] && options[:wrapper_mappings][input_type]
        options[:wrapper_mappings][input_type]
      else
        SimpleForm.wrapper_mappings && SimpleForm.wrapper_mappings[input_type]
      end
    end

    def find_wrapper(input_type, options)
      if name = options[:wrapper] || find_wrapper_mapping(input_type)
        name.respond_to?(:render) ? name : SimpleForm.wrapper(name)
      else
        wrapper
      end
    end

    # If cache_discovery is enabled, use the class level cache that persists
    # between requests, otherwise use the instance one.
    def discovery_cache
      if SimpleForm.cache_discovery
        self.class.discovery_cache
      else
        @discovery_cache ||= {}
      end
    end

    def mapping_override(klass)
      name = klass.name
      if name =~ /^SimpleForm::Inputs/
        input_name = name.split("::").last
        attempt_mapping_with_custom_namespace(input_name) ||
          attempt_mapping(input_name, Object)
      end
    end

    def attempt_mapping(mapping, at)
      return if SimpleForm.inputs_discovery == false && at == Object

      at.const_get(mapping) if at.const_defined?(mapping)
    end

    def attempt_mapping_with_custom_namespace(input_name)
      SimpleForm.custom_inputs_namespaces.each do |namespace|
        if (mapping = attempt_mapping(input_name, namespace.constantize))
          return mapping
        end
      end

      nil
    end

    def build_input_field_components(components)
      components.map do |component|
        if component == :input
          SimpleForm::Wrappers::Leaf.new(component, build_input_field_options)
        else
          SimpleForm::Wrappers::Leaf.new(component)
        end
      end
    end

    def build_input_field_options
      input_field_options = {}
      valid_class         = SimpleForm.input_field_valid_class
      error_class         = SimpleForm.input_field_error_class

      if error_class.present?
        input_field_options[:error_class] = error_class
      end

      if valid_class.present?
        input_field_options[:valid_class] = valid_class
      end

      input_field_options
    end
  end
end
