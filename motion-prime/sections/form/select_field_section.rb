module MotionPrime
  class SelectFieldSection < BaseFieldSection
    element :label, type: :label do
      default_label_options
    end
    element :button, type: :button do
      options[:button] || {}
    end
    element :arrow, type: :image do
      options[:arrow] || {}
    end
    element :error_message, type: :error_message, text: proc { |field| field.observing_errors? and field.all_errors.join("\n") }

    after_element_render :button, :bind_select_button

    def bind_select_button
      view(:button).on :touch_down do
        form.send(options[:action]) if options[:action]
      end
    end

    def value
      view(:button).title
    end
  end
end