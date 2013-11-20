motion_require './table.rb'
motion_require '../helpers/has_style_chain_builder'
module MotionPrime
  class FormSection < TableSection
    include HasStyleChainBuilder

    # MotionPrime::FormSection is container for Field Sections.
    # Forms are located inside Screen and can contain multiple Field Sections.
    # On render, each field will be added to parent screen.

    # == Basic Sample
    # class MyLoginForm < MotionPrime::FormSection
    #   field :email, label: { text: 'E-mail' },  input: { placeholder: 'Your E-mail' }
    #   field :submit, title: 'Login', type: :submit
    #
    #   def on_submit
    #     email = view("email:input").text
    #     puts "Submitted email: #{email}"
    #   end
    # end
    #

    class_attribute :text_field_limits, :text_view_limits
    class_attribute :fields_options, :section_header_options
    attr_accessor :fields, :field_indexes, :keyboard_visible, :rendered_views, :section_headers

    def table_data
      if @groups_count == 1
        fields.values
      else
        section_indexes = []
        fields.inject([]) do |result, (key, field)|
          section = self.class.fields_options[key][:group].to_i

          section_indexes[section] ||= 0
          result[section] ||= []
          result[section][section_indexes[section]] = field
          section_indexes[section] += 1
          result
        end
      end
    end

    def form_styles
      base_styles = [:base_form]
      base_styles << :base_form_with_sections unless flat_data?
      item_styles = [name.to_sym]
      {common: base_styles, specific: item_styles}
    end

    def field_styles(field)
      suffixes = [:field]
      if field.is_a?(BaseFieldSection)
        suffixes << field.class.name.demodulize.underscore.gsub(/\_section$/, '')
      end

      styles = {
        common: build_styles_chain(form_styles[:common], suffixes),
        specific: build_styles_chain(form_styles[:specific], suffixes)
      }

      if field.respond_to?(:container_styles) && field.container_styles.present?
        styles[:specific] += Array.wrap(field.container_styles)
      end
      styles
    end

    def header_styles(header)
      suffixes = [:header, :"#{header.name}_header"]
      styles = {
        common: build_styles_chain(form_styles[:common], suffixes),
        specific: build_styles_chain(form_styles[:specific], suffixes)
      }

      if header.respond_to?(:container_styles) && header.container_styles.present?
        styles[:specific] += Array.wrap(header.container_styles)
      end
      styles
    end

    def render_table
      init_form_fields
      reset_data_stamps
      options = {
        styles: form_styles.values.flatten,
        delegate: self,
        dataSource: self,
        style: (UITableViewStyleGrouped unless flat_data?)}
      self.table_element = screen.table_view(options)
    end

    def render_cell(index, table)
      field = rows_for_section(index.section)[index.row]
      screen.table_view_cell styles: field_styles(field).values.flatten, reuse_identifier: cell_name(table, index), parent_view: table_view do |cell_view|
        field.cell_view = cell_view if field.respond_to?(:cell_view)
        field.render(to: screen)
      end
    end

    def reload_cell(section)
      field = section.name.to_sym
      index = field_indexes[field].split('_').map(&:to_i)
      path = NSIndexPath.indexPathForRow(index.last, inSection: index.first)
      # path = table_view.indexPathForRowAtPoint(section.cell.center) # do not use indexPathForCell here as field may be invisibe
      table_view.beginUpdates
      section.cell.removeFromSuperview

      fields[field] = load_field(self.class.fields_options[field])

      @data = nil
      set_data_stamp(field_indexes[field])
      table_view.reloadRowsAtIndexPaths([path], withRowAnimation: UITableViewRowAnimationNone)
      table_view.endUpdates
    end

    def reset_data_stamps
      set_data_stamp(self.field_indexes.values)
    end

    # Returns element based on field name and element name
    #
    # Examples:
    #   form.element("email:input")
    #
    # @param String name with format "fieldname:elementname"
    # @return MotionPrime::BaseElement element
    def element(name)
      field_name, element_name = name.split(':')
      if element_name.present?
        field(field_name).element(element_name.to_sym)
      else
        super(field_name)
      end
    end

    # Returns field by name
    #
    # Examples:
    #   form.field(:email)
    #
    # @param String field name
    # @return MotionPrime::BaseFieldSection field
    def field(field_name)
      self.fields[field_name.to_sym]
    end

    def fields_hash
      fields.to_hash
    end

    def register_elements_from_section(section)
      self.rendered_views ||= {}
      section.elements.values.each do |element|
        self.rendered_views[element.view] = {element: element, section: section}
      end
    end

    # Set focus on field cell
    #
    # Examples:
    #   form.focus_on(:title)
    #
    # @param String field name
    # @return MotionPrime::BaseFieldSection field
    def focus_on(field_name, animated = true)
      # unfocus other field
      data.flatten.each do |item|
        item.blur
      end
      # focus on field
      field(field_name).focus
    end

    def set_height_with_keyboard
      return if keyboard_visible
      self.table_view.height -= KEYBOARD_HEIGHT_PORTRAIT
      self.keyboard_visible = true
    end

    def set_height_without_keyboard
      return unless keyboard_visible
      self.table_view.height += KEYBOARD_HEIGHT_PORTRAIT
      self.keyboard_visible = false
    end

    def keyboard_will_show
      current_inset = table_view.contentInset
      current_inset.bottom = KEYBOARD_HEIGHT_PORTRAIT + (self.table_element.computed_options[:bottom_content_offset] || 0)
      table_view.contentInset = current_inset
    end

    def keyboard_will_hide
      current_inset = table_view.contentInset
      current_inset.bottom = self.table_element.computed_options[:bottom_content_offset] || 0
      table_view.contentInset = current_inset
    end

    # ALIASES
    def on_input_change(text_field); end
    def on_input_edit(text_field); end
    def on_input_return(text_field)
      text_field.resignFirstResponder
    end;
    def textFieldShouldReturn(text_field)
      on_input_return(text_field)
    end
    def textFieldDidBeginEditing(text_field)
      on_input_edit(text_field)
    end

    def textView(text_view, shouldChangeTextInRange:range, replacementText:string)
      limit = (self.class.text_view_limits || {}).find do |field_name, limit|
        view("#{field_name}:input")
      end.try(:last)
      return true unless limit
      allow_string_replacement?(text_view, limit, range, string)
    end

    def textField(text_field, shouldChangeCharactersInRange:range, replacementString:string)
      limit = (self.class.text_field_limits || {}).find do |field_name, limit|
        view("#{field_name}:input")
      end.try(:last)
      return true unless limit
      allow_string_replacement?(text_field, limit, range, string)
    end

    def allow_string_replacement?(target, limit, range, string)
      if string.length.zero? || (range.length + limit - target.text.length) >= string.length
        true
      else
        target.text.length < limit
      end
    end

    def load_field(field)
      klass = "MotionPrime::#{field[:type].classify}FieldSection".constantize
      klass.new(field.merge(form: self))
    end

    def render_field?(name, options)
      condition = options.delete(:if)
      if condition.nil?
        true
      elsif condition.is_a?(Proc)
        self.instance_eval(&condition)
      else
        condition
      end
    end

    def render_header(section)
      return unless options = self.class.section_header_options.try(:[], section)
      self.section_headers[section] ||= BaseHeaderSection.new(options.merge(form: self))
    end

    def header_for_section(section)
      self.section_headers ||= []
      self.section_headers[section] || render_header(section)
    end

    def tableView(table, viewForHeaderInSection: section)
      return unless header = header_for_section(section)
      wrapper = MotionPrime::BaseElement.factory(:view, styles: header_styles(header).values.flatten, parent_view: table_view)
      wrapper.render(to: screen) do |cell_view|
        header.cell_view = cell_view if header.respond_to?(:cell_view)
        header.render(to: screen)
      end
    end

    def tableView(table, heightForHeaderInSection: section)
      header_for_section(section).try(:container_height) || 0
    end

    class << self
      def field(name, options = {}, &block)
        options[:name] = name
        options[:type] ||= :string
        options[:block] = block
        self.fields_options ||= {}
        self.fields_options[name] = options
        self.fields_options[name]
      end

      def group_header(name, options)
        options[:name] = name
        self.section_header_options ||= []
        section = options.delete(:id)
        self.section_header_options[section] = options
      end

      def limit_text_field_length(name, limit)
        self.text_field_limits ||= {}
        self.text_field_limits[name] = limit
      end
      def limit_text_view_length(name, limit)
        self.text_view_limits ||= {}
        self.text_view_limits[name] = limit
      end
    end

    private
      def init_form_fields
        self.fields = {}
        self.field_indexes = {}
        index = 0
        (self.class.fields_options || []).each do |key, field|
          next unless render_field?(key, field)
          @groups_count = [@groups_count || 1, field[:group].to_i + 1].max
          self.fields[key] = load_field(field)
          self.field_indexes[key] = "#{field[:group].to_i}_#{index}"
          index += 1
        end
      end
  end
end