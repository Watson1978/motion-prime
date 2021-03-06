motion_require './_text_mixin'
module MotionPrime
  module ElementContentTextMixin
    include ElementTextMixin

    def content_text
      is_a?(ButtonElement) ? button_content_text : input_content_text
    end

    def content_font
      (is_a?(ButtonElement) ? button_content_font : input_content_font) || :system.uifont
    end

    def current_attributed_text
      attributed_text_for_text(content_text)
    end

    def attributed_text_for_text(text)
      options = {
        text: text,
        font: content_font,
        line_spacing: computed_options[:line_spacing],
        line_height: computed_options[:line_height]
      }
      computed_options[:html].present? ? html_string(options) : attributed_string(options)
    end

    def content_width
      @content_width = width_for_attributed_text(current_attributed_text)
    end

    def multiline_content_width
      unless computed_options[:width]
        Prime.logger.error "Please set element width for multiline content width calculation (`#{self.name}` in section `#{section.try(:name)}`)"
      end
      width_for_attributed_text(current_attributed_text, computed_options[:width] - content_padding_width)
    end

    def width_for_text(text)
      width_for_attributed_text(attributed_text_for_text(text))
    end

    def width_for_attributed_text(attributed_text, width = Float::MAX)
      min, max = computed_options[:min_width].to_f, computed_options[:max_width]
      return min if attributed_text.to_s.blank?

      rect = get_content_rect(attributed_text, width)
      [[rect.size.width.ceil, max].compact.min, min].max.ceil
    end

    def cached_content_width
      @content_width ||= content_width
    end

    def content_height
      @content_height = height_for_attributed_text(current_attributed_text)
    end

    def height_for_text(text)
      height_for_attributed_text(attributed_text_for_text(text))
    end

    def height_for_attributed_text(attributed_text)
      min, max = computed_options[:min_height].to_f, computed_options[:max_height]
      unless computed_options[:width]
        Prime.logger.error "Please set element width for content height calculation (`#{self.name}` in section `#{section.try(:name)}`)"
      end
      return min if attributed_text.to_s.blank?
      rect = get_content_rect(attributed_text, computed_options[:width] - content_padding_width)
      [[rect.size.height.ceil, max].compact.min, min].max.ceil
    end

    def cached_content_height
      @content_height ||= content_height
    end

    def attributed_text?
      computed_options.slice(:html, :line_spacing, :line_height, :underline, :fragment_color).any? || computed_options[:attributed_text_options]
    end

    protected
      def reset_computed_values
        @content_height = nil
        @content_width = nil
        super
      end

    private
      def get_content_rect(text, width)
        raise "Please set element width for content size calculation" unless width

        options = NSStringDrawingUsesLineFragmentOrigin
        if is_a?(TextViewElement)
          options |= NSStringDrawingUsesFontLeading | NSStringDrawingTruncatesLastVisibleLine
        end
        rect = text.boundingRectWithSize([width, Float::MAX], options: options, context:nil)
        rect.size.height += 1 # {font_size: 13, line_spacing: 2, number_of_lines: 2} computed height = 28, but we need 29 to fit the text
        rect
      end

      def button_content_text
        view ? view.titleLabel.text : computed_options[:title]
      end

      def button_content_font
        extract_font_from(computed_options[:title_label])
      end

      def input_content_text
        input_value_text.blank? ? input_placeholder_text : input_value_text
      end

      # TODO: normalize_object will not be required after refactoring computed options.
      def input_content_font
        font = input_value_text.blank? ? extract_font_from(computed_options, 'placeholder') : extract_font_from(computed_options)
        normalize_object(font, section || self)
      end

      # FIXME: does not work when #update_with_options is called
      def input_value_text
        view && !is_a?(DrawElement) ? view.text : (computed_options[:html] || computed_options[:text])
      end

      def input_placeholder_text
        computed_options[:placeholder]
      end
  end
end