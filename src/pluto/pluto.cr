require "../make-it-right"
require "pluto"

module MakeItRight
  # Given a pluto picture and it's origin exif orientation,
  # transform the picture as if the exif orientation was TOP_LEFT (which is the default, normal orientation)
  def self.straighten_pluto_picture(picture : Pluto::Image, orientation : MakeItRight::Orientation?)
    return picture if orientation.nil? || orientation.top_left?

    case picture
    when Pluto::ImageRGBA
      sources = {picture.red, picture.green, picture.blue, picture.alpha}
    when Pluto::ImageGA
      sources = {picture.grey, picture.alpha}
    else raise "Unknown picture type #{picture.class.name}"
    end

    w, h = picture.width, picture.height

    # Swap columns and rows
    if orientation.in?({MakeItRight::Orientation::LEFT_TOP,
                        MakeItRight::Orientation::RIGHT_TOP,
                        MakeItRight::Orientation::RIGHT_BOTTOM,
                        MakeItRight::Orientation::LEFT_BOTTOM})

      # In place non-square matrix transposition is a non trivial operation, so default to rebuilding an image.
      case picture
      when Pluto::ImageRGBA
        sources = {picture.red, picture.green, picture.blue, picture.alpha}
        outputs = {Array(UInt8).new(h * w, 0u8), Array(UInt8).new(h * w, 0u8), Array(UInt8).new(h * w, 0u8), Array(UInt8).new(h * w, 0u8)}
        picture = Pluto::ImageRGBA.new *outputs, h, w
      when Pluto::ImageGA
        sources = {picture.grey, picture.alpha}
        outputs	= {Array(UInt8).new(h * w, 0u8), Array(UInt8).new(h * w, 0u8)}
        picture = Pluto::ImageGA.new *outputs, h, w
      else raise "Unknown picture type #{picture.class.name}"
      end

      sources.zip outputs do |source, output|
        (0...h).each do |y|
          (0...w).each do |x|
            output[x * h + y] = source[y * w + x]
          end
        end
      end

      sources = outputs
      h,w = w,h
    end

    # In-place horizontal mirroring
    if orientation.in?({MakeItRight::Orientation::BOTTOM_RIGHT,
                        MakeItRight::Orientation::BOTTOM_LEFT,
                        MakeItRight::Orientation::LEFT_BOTTOM,
                        MakeItRight::Orientation::RIGHT_BOTTOM})
      sources.each do |source|
        (0...h).each do |y|
          (0...(w // 2)).each do |x|
            buf = source[(h - 1 - y) * w + w - 1 - x]
            source[(h - 1 - y) * w + w - 1 - x] = source[y * w + x]
            source[y * w + x] = buf
          end
        end
      end
    end

    # In-place vertical mirroring
    if orientation.in?({MakeItRight::Orientation::TOP_RIGHT,
                        MakeItRight::Orientation::BOTTOM_LEFT,
                        MakeItRight::Orientation::LEFT_BOTTOM,
                        MakeItRight::Orientation::RIGHT_TOP})
	    sources.each do |source|
        (0...h).each do |y|
          (0...(w // 2)).each do |x|
            buf = source[y * w + w - 1 - x]
            source[y * w + w - 1 - x] = source[y * w + x]
            source[y * w + x] = buf
          end
        end
      end
    end

    return picture
  end
end
