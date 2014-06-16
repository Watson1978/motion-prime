module MotionPrime
  module DrawBackgroundMixin
    def draw_background_in_context(context = nil)
      context ||= UIGraphicsGetCurrentContext()
      options = draw_options
      rect, background_color, border_width, border_color, corner_radius, dashes_array = options.slice(:rect, :background_color, :border_width, :border_color, :corner_radius, :dashes).values

      return unless background_color || border_width > 0

      inset = border_width > 0 ? (border_width - 1 )*0.5 : 0
      rect = CGRectInset(rect, -inset, -inset)

      if dashes_array
        dashes = Pointer.new(:float, dashes_array.count)
        dashes_array.each_with_index { |length, i| dashes[i] = length }
      end

      if corner_radius > 0
        bezier_path = UIBezierPath.bezierPathWithRoundedRect rect, cornerRadius: corner_radius
        UIGraphicsPushContext(context)
        bezier_path.setLineDash(dashes, count: dashes_array.count, phase: 0) if dashes
        if border_width > 0
          bezier_path.lineWidth = border_width
          border_color.setStroke
          bezier_path.stroke
        end
        if background_color
          background_color.setFill
          bezier_path.fill
        end
        UIGraphicsPopContext()
      else
        if border_width > 0 && border_color
          CGContextSetLineDash(context, dashes_array.count, dashes, 0) if dashes
          CGContextSetLineWidth(context, border_width)
          CGContextSetStrokeColorWithColor(context, border_color.uicolor.cgcolor)
          CGContextStrokeRect(context, rect)
        end
        CGContextSetFillColorWithColor(context, background_color.uicolor.cgcolor) if background_color
        CGContextFillRect(context, rect) if background_color
      end
    end
  end
end