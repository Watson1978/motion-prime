motion_require '../draw.rb'
module MotionPrime
  class LabelDrawElement < DrawElement
    include ElementContentTextMixin
    include ElementTextMixin
    include DrawBackgroundMixin

    def draw_options
      options = computed_options
      text = (options[:html] || options[:text]).to_s.gsub(/\A[\n\r]+/, '')
      text_color = (options[:text_color] || :black).uicolor
      font = (extract_font_from(options) || :system).uifont

      text_alignment_name = options.fetch(:text_alignment, :left)
      text_alignment = text_alignment_name.nstextalignment

      default_break_mode = options[:size_to_fit] ? :word_wrap : :tail_truncation
      line_break_mode_name = options.fetch(:line_break_mode, default_break_mode)
      line_break_mode = line_break_mode_name.uilinebreakmode

      top_left_corner = CGPointMake(frame_inner_left, frame_inner_top)
      if options[:number_of_lines].to_i.zero?
        inner_rect = CGRectMake(*top_left_corner.to_a, frame_width, frame_height)
      end
      super.merge({
        text: text,
        is_html: options[:html].present?,
        text_color: text_color,
        font: font,
        text_alignment_name: text_alignment_name,
        text_alignment: text_alignment,
        line_break_mode_name: line_break_mode_name,
        line_break_mode: line_break_mode,
        line_spacing: options[:line_spacing],
        line_height: options[:line_height],
        underline: options[:underline],
        fragment_color: options[:fragment_color],
        fragment_font: options[:fragment_font],
        top_left_corner: top_left_corner,
        inner_rect: inner_rect
      })
    end

    def draw_in(rect)
      super
      draw_in_context(UIGraphicsGetCurrentContext())
    end

    # using hack for bug described here: http://stackoverflow.com/questions/19232850/nsattributedstring-drawinrect-disappears-when-the-frame-is-offset
    # TODO: check it in iOS 7.1 and remove CGContext manuplations (pass innerRect/topLeftCorner) if fixed
    def draw_in_context(context)
      return if computed_options[:hidden]
      size_to_fit_if_needed
      set_text_position

      draw_background_in_context(context)

      UIGraphicsPushContext(context)
      options = draw_options
      if options.slice(:is_html, :line_spacing, :line_height, :underline, :force_attributed, :fragment_color, :fragment_font).any?
        prepared_text = options[:is_html] ? html_string(options) : attributed_string(options)

        CGContextSaveGState(context)
        if options[:inner_rect]
          rect = options[:inner_rect]
          CGContextTranslateCTM(context, *rect.origin.to_a)
          prepared_text.drawInRect(CGRectMake(0, 0, *rect.size.to_a))
        else
          CGContextTranslateCTM(context, *options[:top_left_corner].to_a)
          prepared_text.drawAtPoint(CGPointMake(0, 0))
        end
        CGContextRestoreGState(context)
      else
        # regular string
        prepared_text = options[:text]
        options[:text_color].set
        if options[:inner_rect]
          prepared_text.drawInRect(options[:inner_rect],
            withFont: options[:font],
            lineBreakMode: options[:line_break_mode],
            alignment: options[:text_alignment])
        else
          prepared_text.drawAtPoint(options[:top_left_corner], withFont: options[:font])
        end
      end
      UIGraphicsPopContext()
    end

    def default_padding_for(side)
      return super unless side.to_s == 'top'
      @padding_top || 0
    end

    def size_to_fit_if_needed
      if original_options[:size_to_fit]
        computed_options[:width] = cached_content_outer_width unless original_options[:width]
        computed_options[:height] = cached_content_outer_height unless original_options[:height]
        reset_computed_values
      elsif original_options.slice(:width, :left, :right).values.none?
        computed_options[:width] = cached_content_outer_width unless original_options[:width]
        reset_computed_values
      elsif original_options.slice(:height, :top, :bottom).values.none?
        computed_options[:height] = cached_content_outer_height unless original_options[:height]
        reset_computed_values
      end
    end

    def set_text_position
      # FIXME: there is a bug when overriding this method for custom fonts (adjust @padding_top), you must set 'padding' to 0
      if original_options.slice(:padding_top, :padding_bottom, :padding, :size_to_fit).values.none?
        computed_options[:width] ||= frame_width
        frame_height = computed_options[:height] || frame_outer_height
        content_height = cached_content_height
        content_height = frame_height if content_height > frame_height
        @padding_top = (frame_height - content_height)/2
        # @padding_top += 1 unless @padding_top.zero?
      end
    end

    def original_options
      @_original_options ||= computed_options.clone
    end
  end
end
