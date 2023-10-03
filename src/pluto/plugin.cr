require "pluto"
require "pluto/format/jpeg"
require "./pluto"

{% for includer in Pluto::Format::JPEG.includers %}
  {% next unless includer.class? && !includer.abstract? %}

  class {{includer}} < Pluto::Image
    def self.from_jpeg(image_data : Bytes) : self
      picture = previous_def image_data
	    tiff_metadata = MakeItRight.from_jif IO::Memory.new image_data
	    MakeItRight.straighten_pluto_picture(picture, tiff_metadata.try &.orientation).as self
    end
  end
{% end %}
