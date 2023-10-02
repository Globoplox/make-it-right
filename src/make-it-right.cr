require "./ifd"
require "./tag_types"
require "./ifd_tags"
require "./interoperability"
require "./tiff"
require "./jif"

# Reference http://www.fifi.org/doc/jhead/exif-e.html
# Another reference https://www.awaresystems.be/imaging/tiff/tifftags.html
# Another reference https://exiftool.org/TagNames/
module MakeItRight
  VERSION = {{ `shards version __DIR__`.chomp.stringify }}

  class Exception < ::Exception
  end

  class InterpretException < Exception
    def initialize(@cause : ::Exception, @tag : UInt16, @format : UInt16, @components : UInt32, @value : UInt32, @raw : Bytes?)
      super cause: @cause
    end

    def message
      <<-STR
      Could not interpet tag 0x#{@tag.to_s 16} 
        format: #{@format} 
        components: #{@components}
        value: 0x#{@value.to_s 16}
        raw_data: #{@raw.try { |raw| "0x#{raw.map(&.to_s 16).join}" } || "none"}
        cause: #{@cause.try(&.message) || "none"}
      STR
    end
  end
end
