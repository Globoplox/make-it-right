# JPEG is an encoding.
# JIF is a container file format.
# JPEG images data are stored in JIF files. They are named jpg/jpeg because some fucker thought it would be funny.
# TIFF is an image file format that is stupid and can actually contain basically anything encoded in whatever way.
# TIFF file are not related to JIF.
# JIF has extension: JFIF. They are very often confused.
# EXIF is an 'whatever' thing that is built upon TIFF (or kindof), that is used to store tags about stuff.
# EXIF can be used with JIF, and to do so it put a TIFF (without actual picture (or maybe one actually lol it depends)) into the JIF.
# Theoritically, you shouldn't be able to have a JIF that has both JFIF and EXIF as extension because they have poorly designed specifications,
# but everyone agreed to ignore those.
# The result of all this is that when you find a `.jpg` file, it can kind of follows JIF JFIF TIFF EXIF sepc/standard/file-format AT THE SAME TIME.
# BUT WAIT IT CAN GO DEEPER
# A JIF (&| JFIF) JPEG file can TIFF (and maybe EXIF), and that TIFF may contain, as a thumbnail, not raw data but an
# actual JPEG, which can be a JFIF TOO
# YOU CAN HAVE A JPEG EXIF STANDARD THAT CONTAIN A JFIF IN ITS TIFF
# This is so wrong
# Maybe one day I will find a jpeg whose thumbnail has a thumbnail and I wont even be surprised.
# Probably the thumbnail's thumbnail will be a picture of a very nicely caligraphied "Fuck You"
# And because it's a mess everything you will find online about will be confused, confusing and contains errors.
# And even if we try very hard not to care, we are kindof forced to.
# Because one of the thing EXIF does is that it can include a tag that sya that the image should be displayed in a different oritentation
# that it actually is.
# And if you fail to follows those very large, messy, often stupid, redondant-maybe-incompatible-may-contradict-themselves-and-each-other specifications
# you might end-up displaying the image in a different way than other.
# This cause a wide area of furstrating bugs and discussions.
# Most image manipulation library for the backend wont have direct support of this.
# Most way to share image file will cause changes to the image file format, sometimes normalizing the picture, which may actually help until it doesn't and the issue get event harder to understand and fix.
# This piece of code hope to be a stupid-simple helper for reading/resetting the orientation tag of a jpeg picture, if any.
# Reference http://www.fifi.org/doc/jhead/exif-e.html
# Another reference https://www.awaresystems.be/imaging/tiff/tifftags.html
# Another reference https://exiftool.org/TagNames/
# (They all periodically contradict each other, and sometimes even themselves)
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

  enum Orientation
    TOP_LEFT     = 1
    TOP_RIGHT    = 2
    BOTTOM_RIGHT = 3
    BOTTOM_LEFT  = 4
    LEFT_TOP     = 5
    RIGHT_TOP    = 6
    RIGHT_BOTTOM = 7
    LEFT_BOTTOM  = 8
  end

  enum Unit
    NONE       = 1
    INCH       = 2
    CENTIMETER = 3

    def self.from_thumbnail(value)
      case value
      when 1 then INCH
      when 2 then CENTIMETER
      else        UNKNOWN
      end
    end
  end

  enum ExposureProgram
    MANUAL            = 1
    NORMAL            = 2
    APERTURE_PRIORITY = 3
    SHUTTER_PRIORITY  = 4
    CREATIVE          = 5
    ACTION            = 6
    PORTRAIT          = 7
    LANDSCAPE         = 8
  end

  enum MeteringMode
    AVERAGE                 =   1
    CENTER_WEIGHTED_AVERAGE =   2
    SPOT                    =   3
    MULTI_SPOT              =   4
    MULTI_SEGMENT           =   5
    PARTIAL                 =   6
    OTHER                   = 255
  end

  enum LightSource
    DAYLIGHT         =   1
    FLUORESCENT      =   2
    TUNGSTEN         =   3
    FLASH            =  10
    STANDARD_LIGHT_A =  17
    STANDARD_LIGHT_B =  18
    STANDARD_LIGHT_C =  19
    D55              =  20
    D65              =  21
    D75              =  22
    OTHER            = 255
  end

  struct Flash
    enum Fired
      FIRED     = 0b0
      NOT_FIRED = 0b1
    end

    enum Strobe
      NO_STROBE_DETECTION_FEATURE = 0b00
      RESERVED                    = 0b01
      NOT_DETECTED                = 0b10
      DETECTED                    = 0b11
    end

    enum Mode
      UNKNOWN                       = 0b00
      COMPULSTORY_FLASH_FIRING      = 0b01
      COMPULSTORY_FLASH_SUPPRESSION = 0b10
      AUTO                          = 0b11
    end

    enum FlashFunctionality
      PRESENT = 0b0
      ABSENT  = 0b1
    end

    enum RedEyeReduction
      PRESENT = 0b0
      ABSENT  = 0b1
    end

    property fired : Fired
    property strobe : Strobe
    property mode : Mode
    property functionality : FlashFunctionality
    property red_eye : RedEyeReduction

    def initialize(value)
      @fired = Fired.from_value value & 0b1
      @strobe = Strobe.from_value value >> 1 & 0b11
      @mode = Mode.from_value value >> 3 & 0b11
      @functionality = FlashFunctionality.from_value value >> 5 & 0b1
      @red_eye = RedEyeReduction.from_value value >> 6 & 0b1
    end

    def to_s(io)
      io << "fired: "
      fired.to_s io
      io << "; strobe: "
      strobe.to_s io
      io << "; mode: "
      mode.to_s io
      io << "; functionality: "
      functionality.to_s io
      io << "; red_eye: "
      red_eye.to_s io
    end
  end

  enum ColorSpace
    SRGB         =     1
    UNCALIBRATED = 65535
  end

  enum SensingMethod
    UNDEFINED               = 1
    ONE_CHIP_COLOR_AREA     = 2
    TWO_CHIP_COLOR_AREA     = 3
    THREE_CHIP_COLOR_AREA   = 4
    COLOR_SEQUENTIAL_AREA   = 5
    TRILINEAR               = 7
    COLOR_SEQUENTIAL_LINEAR = 8
  end

  enum Compression
    NONE          =     1
    CCITTRLE      =     2
    CCITTFAX3     =     3
    CCITTFAX4     =     4
    LZW           =     5
    OJPEG         =     6
    JPEG          =     7
    NEXT          = 32766
    CCITTRLEW     = 32771
    PACKBITS      = 32773
    THUNDERSCAN   = 32809
    IT8CTPAD      = 32895
    IT8LW         = 32896
    IT8MP         = 32897
    IT8BL         = 32898
    PIXARFILM     = 32908
    PIXARLOG      = 32909
    DEFLATE       = 32946
    ADOBE_DEFLATE =     8
    DCS           = 32947
    JBIG          = 34661
    SGILOG        = 34676
    SGILOG24      = 34677
    JP2000        = 34712
  end

  enum PhotometricInterpretation
    MONOCHROME = 1
    RGB        = 2
    YCBCR      = 6
  end

  enum ExposureMode
    AUTO_EXPOSURE   = 0
    MANUAL_EXPOSURE = 1
    AUTO_BRACKET    = 2
  end

  enum WhiteBalance
    AUTO   = 0
    MANUAL = 1
  end

  enum SceneType
    STANDARD  = 0
    LANDSCAPE = 1
    PORTRAIT  = 2
    NIGHT     = 3
  end

  enum GainControl
    NONE           = 0
    LOW_GAIN_UP    = 1
    HIGH_GAIN_UP   = 2
    LOW_GAIN_DOWN  = 3
    HIGH_GAIN_DOWN = 4
  end

  enum Contrast
    NORMAL = 0
    SOFT   = 1
    HARD   = 2
  end

  enum Saturation
    NORMAL = 0
    LOW    = 1
    HIGH   = 2
  end

  enum Sharpness
    NORMAL = 0
    SOFT   = 1
    HARD   = 2
  end

  enum DistanceRange
    MACRO   = 1
    CLOSE   = 2
    DISTANT = 3
  end

  struct Rational(T)
    property numerator : T
    property denominator : T

    def initialize(@numerator, @denominator)
    end

    def to_s(io)
      @numerator.to_s io
      io << '/'
      @denominator.to_s io
    end
  end

  class UserComment
    UNDEFINED = Bytes[0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00]
    ASCII     = Bytes[0x41, 0x53, 0x43, 0x49, 0x49, 0x00, 0x00, 0x00]
    UNICODE   = Bytes[0x55, 0x4e, 0x49, 0x43, 0x4f, 0x44, 0x45, 0x00]
    JIS       = Bytes[0x4a, 0x49, 0x53, 0x00, 0x00, 0x00, 0x00, 0x00]

    def self.from_value(value : Bytes)
      encoding = {
        ASCII,
        UNICODE,
        JIS,
        UNDEFINED,
      }.find &.== value[0...8]
      raise Exception.new "Encoding unrecognized #{value[0, 8]}" unless encoding
      new encoding, String.new value[8...(value.size - 1)][0...(value.index 0u8)]
    end

    property encoding : Bytes
    property value : String

    def initialize(@encoding, @value)
    end

    def to_s(io)
      io << @value
    end
  end

  def self.from_jif(path : String | Path) : Tiff?
    File.open path do |io|
      from_jif io, close: true
    end
  end

  # Extract tags from a JIF file.
  def self.from_jif(io : IO, close = false) : Tiff?
    # Parse the JIF searching for the APP1 marker, ingoring everything else.
    marker = io.read_bytes UInt16, IO::ByteFormat::BigEndian
    raise Exception.new "Not a JIF file" unless marker == 0xffd8 # JIF SOI marker (start  of image)
    loop do
      marker = io.read_bytes UInt16, IO::ByteFormat::BigEndian
      case marker
      when 0xffe1
        # JIF APP1 marker, kind of an extension slot where the TIFF file containing the EXIF data is located.
        # But because god hate us, there may be multiple APP1 block
        # Usually one for exif, one for xmp. We need to read
        # See below for the size and - 2 explaination.
        size = io.read_bytes UInt16, IO::ByteFormat::BigEndian
        # Now check if this is EXIF or XMP:
        # EXIF header is 0x45786966 (big endian)
        # XMP header is "http://ns.adobe.com/xap/1.0/\x00"
        is_it_exif = io.read_bytes UInt32, IO::ByteFormat::BigEndian
        if is_it_exif == 0x45786966
          io.skip 2 # There shoud be 2 null bytes
          # Now here are the TIFF file embedding the actual EXIF stuff
          app1_copy = Bytes.new size - 2
          io.read app1_copy
          io.close if close # Closing the file descriptor early
          return Tiff.new app1_copy
        else
          # This is likely XMP. We could parse it easely but who care.
          # Skip it, accounting that we parsed the size and 4 addition byte
          io.skip size - 2 - 4
        end
      when 0xffd9, 0xffda
        # JIF EOI marker (end of image)
        # ot JIF SOS (start of scan)
        # SOS mark the beginning of raw data and it doesnt declare the acutal size in any meaningful way
        # Anyway there is no hope of finding APPn marker after there.
        break
      else
        # Any other marker should have a size after the marker, that allows us to skip to the next marker
        size = io.read_bytes UInt16, IO::ByteFormat::BigEndian
        io.skip size - 2 # The size include the bytes used to store the size, hence the - 2
      end
    end
  end

  def self.from_tiff(path : String | Path) : Tiff?
    File.open path do |io|
      Tiff.new io.getb_to_end
    end
  end

  # Given a *input_jif* JIF file, produce a copy of this JIF into *output_jif*
  # With the exif data from *main* inserted or replacing the exif data of *input_jif*
  def self.patch_jif(tiff : Tiff, input_jif : IO, output_jif : IO)
    # Read and write SOI
    marker = input_jif.read_bytes UInt16, IO::ByteFormat::BigEndian
    raise Exception.new "Not a JIF file" unless marker == 0xffd8 # JIF SOI marker (start  of image)
    marker.to_io output_jif, IO::ByteFormat::BigEndian

    # We write the EXIF data.
    0xffe1u16.to_io output_jif, IO::ByteFormat::BigEndian
    exif_size_offset = output_jif.pos # This is incorrect
    0x0000u16.to_io output_jif, IO::ByteFormat::BigEndian

    # Exif header
    0x45786966u32.to_io output_jif, IO::ByteFormat::BigEndian
    0u16.to_io output_jif, IO::ByteFormat::BigEndian
    # Tiff data
    tiff.serialize output_jif

    # Then we go back to update the APP1 header with the right size, then back again to current pos
    after_exif_offset = output_jif.pos
    exif_size = after_exif_offset - exif_size_offset
    output_jif.pos = exif_size_offset
    if exif_size > UInt16::MAX
      raise Exception.new "The patched EXIF block size is 0x#{exif_size.to_s 16}, which is too big"
    end
    exif_size.to_u16.to_io output_jif, IO::ByteFormat::BigEndian
    output_jif.pos = after_exif_offset

    # Read original pic, copy to dest. If find an exif block in source, omit it from dest.
    loop do
      marker = input_jif.read_bytes UInt16, IO::ByteFormat::BigEndian
      case marker
      when 0xffe1
        # Original APP1 header. If it is exif, we skip it, else
        # it may be XMP, to keep.
        size = input_jif.read_bytes UInt16, IO::ByteFormat::BigEndian
        is_it_exif = input_jif.read_bytes UInt32, IO::ByteFormat::BigEndian
        if is_it_exif == 0x45786966
          # Skip it, no copy.
          input_jif.skip size - 2 - 4
        else
          # This is probably xmp, to keep
          # Write marker, size, part we read to check and the rest
          marker.to_io output_jif, IO::ByteFormat::BigEndian
          size.to_io output_jif, IO::ByteFormat::BigEndian
          is_it_exif.to_io output_jif, IO::ByteFormat::BigEndian
          IO.copy input_jif, output_jif, size - 2 - 4
        end
      when 0xffd9, 0xffda
        # JIF EOI marker (end of image)
        # or JIF SOS (start of scan)
        # SOS mark the beginning of raw data
        marker.to_io output_jif, IO::ByteFormat::BigEndian

        IO.copy input_jif, output_jif
        break
      else
        marker.to_io output_jif, IO::ByteFormat::BigEndian

        # Any other marker should have a size after the marker, that allows us to skip to the next marker
        size = input_jif.read_bytes UInt16, IO::ByteFormat::BigEndian
        size.to_io output_jif, IO::ByteFormat::BigEndian
        IO.copy input_jif, output_jif, size - 2
        # The size include the bytes used to store the size, hence the - 2
      end
    end
  end

  # Given a *input_jif* JIF file, produce a copy of this JIF into *output_jif*
  # With the exif data from *main* inserted or replacing the exif data of *input_jif*
  def self.patch_jif(tiff : Tiff, input_jif : Path | String, output_jif : Path | String)
    File.open input_jif, "r" do |input|
      File.open output_jif, "w" do |output|
        patch_jif tiff, input, output
      end
    end
  end

  def self.patch_jif(input_jif : Path | String, output_jif : Path | String, &)
    File.open input_jif, "r" do |input|
      tiff = self.from_jif input
      if tiff
        yield tiff
        input.rewind
        File.open output_jif, "w" do |output|
          patch_jif tiff, input, output
        end
      end
    end
  end

  # TODO: Write but in place (keeping the IO open and attempting to rewrite in place)
  # This could use a fully lazy context: look up subifd/tag, check if can rewrite, rewrite or raise.
  # Or maybe, when we edit tags, keep a transaction feed.

  # Image file directory.
  # Basically just a bunch of tag together.
  # This is a tree structure, ifd can contain tags that point to other ifd.
  class Ifd
    alias Summary = String | Hash(String, Summary) | Nil

    macro register_tags(tags)
      {% for entry in tags %}
        {% name = entry[0] %}
        {% tag = entry[1] %}
        {% type = entry[2] %}
        {% wrapper = entry[3] %}
        def {{name.id.underscore}}
          {% if type.id == "self".id %}
            value = self
          {% elsif type.id == Array(UInt16 | UInt32).id %}
            value = get_aui {{tag}}
          {% elsif type.id.includes? '|' %}
            value = get_union {{tag}}, Union({{type}})
          {% else %}
            {% type = type.resolve %}
            {% if type.resolve < Enum %}
              value = get_enum {{type}}, {{tag}}
            {% elsif type <= Ifd %}
              value = get_subifd {{type}}, {{tag}}
            {% elsif type.id == Time.id %}
              value = get_time {{tag}}
            {% elsif type.id == Bytes.id %}
              value = get_bytes {{tag}}
            {% elsif type.id == String.id %}
              value = get_string {{tag}}
            {% elsif type.id == UInt8.id %}
              value = get_u8 {{tag}}
            {% elsif type.id == UInt16.id %}
              value = get_u16 {{tag}}
            {% elsif type.id == UInt32.id %}
              value = get_u32 {{tag}}
            {% elsif type.id == Array(UInt16).id %}
              value = get_au16 {{tag}}
            {% elsif type.id == Array(UInt32).id %}
              value = get_au32 {{tag}}
            {% elsif type.id == Rational(UInt32).id %}
              value = get_ur {{tag}}
            {% elsif type.id == Rational(Int32).id %}
              value = get_r {{tag}}
            {% elsif type.id == Array(Rational(UInt32)).id %}
              value = get_aur {{tag}}
            {% else %}
              {% raise "Unknown tag type #{type.id}" %}
            {% end %}
          {% end %}

          {% if wrapper %}
            value.try do |{{wrapper.args.first.name}}|
              {{wrapper.body}}
            end
          {% else %}
            value
          {% end %}
        rescue ex
          entry = tags[{{tag}}]?
          ex = InterpretException.new(
            tag: {{tag}}.to_u16, 
            value: entry[:value],
            raw: entry[:raw],
            format: entry[:format],
            components: entry[:components],
            cause: ex
          ) if entry
          @errors << ex
          nil
        end
      {% end %}

      def all
        summary = Hash(String, Summary).new initial_capacity: {{tags.size}} + 1
        {% for entry in tags %}
          {% name = entry[0] %}
          {% tag = entry[1] %}
          {% type = entry[2] %}
          if @tags.has_key? {{tag}}
            {% if type.is_a? Path && type.resolve <= Ifd %}
              value = {{name.id.underscore}}.try(&.all)
            {% else %}
              value = {{name.id.underscore}}.try(&.to_s)
            {% end %}
            summary["{{name.id}}"] = value if value
          end
        {% end %}
        next_ifd = self.next
        summary["next"] = next_ifd.all if next_ifd
        summary
      end

      def subifds
        ([
          self.next,
          {% for entry in tags %}
          {% name = entry[0] %}
          {% type = entry[2] %}
          {% if type.is_a? Path && type.resolve <= Ifd %}
            {{name}},
          {% end %}
          {% end %}
        ] of Ifd?).compact
      end

      KNOWN_TAGS = {{tags.map(&.[1])}}

      def unknown_tags
        @tags.reject KNOWN_TAGS
      end
    end

    protected def get_enum(type : T.class, tag : UInt16) : T? forall T
      get_u16(tag).try do |value|
        type.from_value value
      rescue ex
        @errors << ex unless value == 0u16
        return
      end
    end

    protected def get_time(tag : UInt16) : Time?
      get_string(tag).try do |value|
        /^\s*$/ =~ value ? nil : Time.parse value, "%Y:%m:%d %H:%M:%S", Time::Location::UTC
      end
    end

    protected def get_subifd(type, tag : UInt16) : Ifd?
      entry = @tags[tag]?
      return unless entry
      type.new @tiff, entry[:value], tag
    end

    # Support UInt16, UInt32, Array(UInt16) as they are the necessary ones
    # but it can be easely extended
    protected def get_union(tag : UInt16, union_type : T.class) forall T
      entry = @tags[tag]?
      return unless entry
      case {entry[:format], entry[:components]}
      when {3, 1}
        type = UInt16
        value = get_u16 tag
      when {3, _}
        type = Array(UInt16)
        value = get_au16 tag
      when {4, 1}
        type = UInt32
        value = get_u32 tag
      else raise Exception.new "This tag is not registered as a type solvable in union"
      end
      raise Exception.new "This tag is registered as #{type} but asked as a #{union_type}" unless type < union_type
      value.as(T)
    end

    protected def get_u16(tag : UInt16) : UInt16?
      entry = @tags[tag]?
      return unless entry
      raise Exception.new "This tag is not registered as UInt16" unless entry[:format] == 3 && entry[:components] == 1
      (entry[:value] >> 16).to_u16!
    end

    protected def get_u8(tag : UInt16) : UInt8?
      entry = @tags[tag]?
      return unless entry
      raise Exception.new "This tag is not registered as UInt8" unless entry[:format] == 1 && entry[:components] == 1
      (entry[:value] >> 24).to_u8!
    end

    protected def get_u32(tag : UInt16) : UInt32?
      entry = @tags[tag]?
      return unless entry
      raise Exception.new "This tag is not registered as UInt16" unless entry[:format] == 4 && entry[:components] == 1
      entry[:value]
    end

    protected def get_ur(tag : UInt16) : Rational(UInt32)?
      entry = @tags[tag]?
      return unless entry
      raise Exception.new "This tag is not registered as Rational(UInt32)" unless entry[:format] == 5 && entry[:components] == 1
      entry[:raw]?.try do |bytes|
        io = IO::Memory.new bytes
        Rational(UInt32).new(
          io.read_bytes(UInt32, @tiff.alignement),
          io.read_bytes(UInt32, @tiff.alignement)
        )
      end
    end

    protected def get_r(tag : UInt16) : Rational(Int32)?
      entry = @tags[tag]?
      return unless entry
      raise Exception.new "This tag is not registered as Rational(Int32)" unless entry[:format] == 10 && entry[:components] == 1
      entry[:raw]?.try do |bytes|
        io = IO::Memory.new bytes
        Rational(Int32).new(
          io.read_bytes(Int32, @tiff.alignement),
          io.read_bytes(Int32, @tiff.alignement)
        )
      end
    end

    protected def get_aur(tag : UInt16) : Array(Rational(UInt32))?
      entry = @tags[tag]?
      return unless entry
      raise Exception.new "This tag is not registered as Array(Rational(Int32))" unless entry[:format] == 5
      entry[:raw]?.try do |bytes|
        io = IO::Memory.new bytes
        Array(Rational(UInt32)).new entry[:components] do
          Rational(UInt32).new(
            io.read_bytes(UInt32, @tiff.alignement),
            io.read_bytes(UInt32, @tiff.alignement)
          )
        end
      end
    end

    protected def get_au16(tag : UInt16) : Array(UInt16)?
      entry = @tags[tag]?
      return unless entry
      raise Exception.new "This tag is not registered as Array(UInt16)" unless entry[:format] == 3
      if entry[:components] == 0
        [] of UInt16
      elsif entry[:components] == 1
        [(entry[:value] >> 16).to_u16!]
      elsif entry[:components] == 2
        [(entry[:value] >> 16).to_u16!,
         (entry[:value]).to_u16!]
      else
        entry[:raw]?.try do |bytes|
          io = IO::Memory.new bytes
          Array(UInt16).new entry[:components] do
            io.read_bytes UInt16, @tiff.alignement
          end
        end
      end
    end

    protected def get_au32(tag : UInt16) : Array(UInt32)?
      entry = @tags[tag]?
      return unless entry
      raise Exception.new "This tag is not registered as Array(UInt32)" unless entry[:format] == 4
      if entry[:components] == 0
        [] of UInt32
      elsif entry[:components] == 1
        [entry[:value]]
      else
        entry[:raw]?.try do |bytes|
          io = IO::Memory.new bytes
          Array(UInt32).new entry[:components] do
            io.read_bytes UInt32, @tiff.alignement
          end
        end
      end
    end

    protected def get_aui(tag : UInt16) : Array(UInt16 | UInt32)?
      entry = @tags[tag]?
      return unless entry
      case entry[:format]
      when 3 then get_au16(tag).try &.map(&.as(UInt16 | UInt32))
      when 4 then get_au32(tag).try &.map(&.as(UInt16 | UInt32))
      else        raise Exception.new "This tag is not registered as Array(UInt16 | UInt32)"
      end
    end

    protected def get_bytes(tag : UInt16) : Bytes?
      entry = @tags[tag]?
      return unless entry
      if entry[:components] <= 4
        raw = Bytes.new entry[:components]
        (0...(raw.size)).each do |i|
          raw[i] = (i >> (i * 8)).to_u8!
        end
        raw
      else
        entry[:raw]
      end
    end

    protected def get_string(tag : UInt16) : String?
      entry = @tags[tag]?
      return unless entry
      raise Exception.new "This tag is not registered as ASCII/Unicode" unless entry[:format] == 2
      if entry[:components] <= 4
        raw = Bytes.new entry[:components] - 1
        (0...(raw.size)).each do |i|
          raw[i] = (i >> (i * 8)).to_u8!
        end
        String.new raw
      else
        entry[:raw].try do |raw|
          String.new raw[0...(raw.index 0u8)]
        end
      end
    end

    def next : Ifd?
      @offset_to_next != 0 ? Ifd.new(@tiff, @offset_to_next, nil) : nil
    end

    def payload : Bytes?
      if (data_offset = @tags[0x0201]?) && (data_size = @tags[0x0202]?)
        @tiff.buffer[data_offset[:value], data_size[:value]]
      end
    end

    protected getter tags
    getter errors = [] of ::Exception
    @offset_to_next : UInt32

    def all_errors
      subifds.reduce @errors do |errors, ifd|
        errors + ifd.all_errors
      end
    end

    def all_unknown_tags
      subifds.reduce unknown_tags do |unknown_tags, ifd|
        unknown_tags.merge ifd.all_unknown_tags
      end
    end

    # Usefull to have overridtable for handling of maker note
    def alignement
      @tiff.alignement
    end

    def io
      @tiff.io
    end

    def buffer
      @tiff.buffer
    end

    # The tag that contained the offset of this as a subifd.
    protected getter origin_tag

    def initialize(@tiff : Tiff, @offset : UInt32, @origin_tag : UInt16?)
      io = @tiff.io
      buffer = @tiff.buffer
      io.pos = @offset
      entries_count = io.read_bytes UInt16, alignement
      @tags = Hash(UInt16, {format: UInt16, components: UInt32, value: UInt32, raw: Bytes?}).new initial_capacity: entries_count
      data_size = 0u32
      (0...entries_count).each do
        tag = io.read_bytes UInt16, alignement
        format = io.read_bytes UInt16, alignement
        components_amount = io.read_bytes UInt32, alignement
        value_or_offset = io.read_bytes UInt32, alignement

        case format
        when 1, 2, 6, 7 then byte_per_components = 1
        when 3, 8       then byte_per_components = 2
        when 4, 9, 11   then byte_per_components = 4
        when 5, 10, 12  then byte_per_components = 8
        end

        if byte_per_components.nil?
          @errors << Exception.new "Bad format for tag 0x#{tag.to_s 16}: 0x#{format}"
          next
        elsif byte_per_components * components_amount > 4
          # slice from tiff buffer instead (also no need to copy value later)
          bytes = buffer[value_or_offset, byte_per_components * components_amount]
          data_size += byte_per_components * components_amount
          data_size += 1 if data_size.odd?
        end

        @tags[tag] = {
          format:     format,
          components: components_amount,
          value:      value_or_offset,
          raw:        bytes,
        }
      end
      @offset_to_next = io.read_bytes UInt32, alignement
      io.skip data_size
    end

    def serialize(output : IO)
      pp "IFD START SERIALISATION AT 0x#{output.pos.to_s 16}, #{@tags.size} TAGS"
      @tags.size.to_u16.to_io output, alignement
      data_offset = output.pos + 4 + @tags.size * 12
      # Subifd tags and the offset in header to their value offset
      # It make sense I promise
      subifd_offsets = [] of {ifd: Ifd, offset: UInt32}

      @tags.each do |tag, entry|
        # write tag
        tag.to_io output, alignement
        entry[:format].to_io output, alignement
        entry[:components].to_io output, alignement
        case entry[:format]
        when 1, 2, 6, 7 then byte_per_components = 1
        when 3, 8       then byte_per_components = 2
        when 4, 9, 11   then byte_per_components = 4
        when 5, 10, 12  then byte_per_components = 8
        else                 byte_per_components = 0
        end
        raw = entry[:raw]
        bytes = byte_per_components * entry[:components]

        if subifd = subifds.find(&.origin_tag.== tag)
          subifd_offsets << {ifd: subifd, offset: io.pos.to_u32}
          # Should increase data offset by size of ifd.
          # But this is hard to preedict, so instead we write the ifd after all values.

        end

        if bytes > 4
          raise Exception.new "Raw data missing for large tag value size in tag #{tag}" if raw.nil?
          raise Exception.new "Raw data size #{raw.size} should be #{bytes} in tag #{tag}" if bytes != raw.size
          data_offset.to_u32.to_io output, alignement
          data_offset += bytes
          data_offset += 1 if data_offset.odd?
        else
          raise Exception.new "Raw data found for small tag value size in tag #{tag}" if raw
          entry[:value].to_io output, alignement
        end
      end

      offset_to_offset_to_next = output.pos
      0u32.to_io output, alignement

      # write values
      pad_count = 0
      @tags.each do |tag, entry|
        entry[:raw].try do |raw|
          output.write raw
          if raw.size.odd?
            pad_count += raw.size + 1
            0x0u8.to_io output, alignement
          else
            pad_count += raw.size
          end
        end
      end

      # Write Subifd.
      @tags.each do |tag, entry|
        if subifd_entry = subifd_offsets.find &.[:ifd].origin_tag.== tag
          # This is a sub ifd to serialize
          current_pos = output.pos
          output.pos = subifd_entry[:offset]
          current_pos.to_u32.to_io output, alignement
          output.pos = current_pos
          subifd_entry[:ifd].serialize output
        end
      end

      # write next if next (using offset_to_offset_to_next)
      self.next.try do |ifd|
        current_pos = output.pos
        output.pos = offset_to_offset_to_next
        current_pos.to_u32.to_io output, alignement
        output.pos = current_pos
        ifd.serialize output
      end

      payload.try do |payload|
        output.write payload
      end
    end
  end

  class Interoperability < Ifd
    register_tags [
      {index, 0x0001, Bytes, nil},
      {version, 0x0002, Bytes, nil},
      {related_image_file_format, 0x1000, String, nil},
      {related_image_width, 0x1001, UInt16 | UInt32, nil},
      {related_image_height, 0x1002, UInt16 | UInt32, nil},
    ]
  end

  # Regroup tags from Image, Thumbnail, Photo & GPS as there should be no collision.
  # AKA (IFD0, IFD1, SUBIFD, GPSIFD)
  # It is more practical than splitting them because
  # a lot of picture have those tags in the wrong IFD.
  # Interoperability is kept separated because it collide with GPS and it rarely mix up with other ifd
  class Ifd
    register_tags [
      # GPS
      {gps_version, 0x0000, Bytes, nil},
      {latitude_ref, 0x0001, String, nil},
      {latitude, 0x0002, Array(Rational(UInt32)), nil},
      {longitude_ref, 0x0003, String, nil},
      {longitude, 0x0004, Array(Rational(UInt32)), nil},
      {altitude_ref, 0x0005, UInt8, nil},
      {altitude, 0x0006, Rational(UInt32), nil},
      {timestamp, 0x0007, Array(Rational(UInt32)), nil},
      {satellites, 0x0008, String, nil},
      {status, 0x0009, String, nil},
      {measure_mode, 0x000a, String, nil},
      {dop, 0x000b, Rational(UInt32), nil},
      {speed_ref, 0x000c, String, nil},
      {speed, 0x000d, Rational(UInt32), nil},
      {track_ref, 0x000e, String, nil},
      {track, 0x000f, Rational(UInt32), nil},
      {img_direction_ref, 0x0010, String, nil},
      {img_direction, 0x0011, Rational(UInt32), nil},
      {map_datum, 0x0012, String, nil},
      {dest_latitude_ref, 0x0013, String, nil},
      {dest_latiture, 0x0014, Array(Rational(UInt32)), nil},
      {dest_longitude_ref, 0x0015, String, nil},
      {dest_longitude, 0x0016, Array(Rational(UInt32)), nil},
      {dest_bearing_ref, 0x0017, String, nil},
      {dest_bearing, 0x0018, Rational(UInt32), nil},
      {dest_distance_ref, 0x0019, String, nil},
      {dest_distance, 0x001a, Rational(UInt32), nil},
      {processing_method, 0x001b, Bytes, nil},
      {area_information, 0x001c, Bytes, nil},
      {date_stamp, 0x001d, String, nil},
      {differential, 0x001e, UInt16, nil},
      {positioning_error, 0x001f, Rational(UInt32), nil},

      # Image IFD
      {image_width, 0x0100, UInt16 | UInt32, nil},
      {image_height, 0x0101, UInt16 | UInt32, nil},
      {bit_per_sample, 0x0102, Array(UInt16), nil},
      {compression, 0x0103, Compression, nil},
      {photometric_interpretation, 0x0106, PhotometricInterpretation, nil},
      {description, 0x010e, String, nil},
      {make, 0x010f, String, nil},
      {model, 0x0110, String, nil},
      {strip_offsets, 0x0111, Array(UInt16 | UInt32), nil},
      {orientation, 0x0112, Orientation, nil},
      {samples_per_pixel, 0x0115, UInt16, nil},
      {row_per_strip, 0x0116, UInt16, nil},
      {strip_byte_count, 0x0117, UInt16 | UInt32, nil},
      {x_resolution, 0x011a, Rational(UInt32), nil},
      {y_resolution, 0x011b, Rational(UInt32), nil},
      {planar_configuration, 0x011c, UInt16, nil}, # Interpretation vary
      {resolution_unit, 0x0128, Unit, nil},
      {software, 0x0131, String, nil},
      {date_time, 0x0132, Time, nil},
      {artist, 0x013b, String, nil},
      {white_point, 0x013e, Array(Rational(UInt32)), nil},
      {primary_chromacities, 0x013f, Array(Rational(UInt32)), nil},
      {jpeg_if_offset, 0x0201, UInt32, nil},
      {jpeg_if_byte_count, 0x0202, UInt32, nil},
      {ycbcr_coefficients, 0x0211, Array(Rational(UInt32)), nil},
      {ycbcr_sub_sampling, 0x0212, Array(UInt16), nil},
      {ycbcr_positioning, 0x0213, UInt16, nil},
      {reference_black_white, 0x0214, Array(Rational(UInt32)), nil},
      {copyright, 0x8298, String, nil},
      {exif, 0x8769, Ifd, nil},
      {gps, 0x8825, Ifd, nil},
      {print_image_matching, 0xc4a5, Bytes, nil}, # No more info
      # Windows
      {title, 0x9c9b, String, nil},
      {comment, 0x9c9c, String, nil},
      {author, 0x9c9d, String, nil},
      {keywords, 0x9c9e, String, nil},
      {subject, 0x9c9f, String, nil},

      # EXIF
      {exposure_time, 0x829a, Rational(UInt32), nil},
      {f_number, 0x829d, Rational(UInt32), nil},
      {exposure_program, 0x8822, ExposureProgram, nil},
      {iso_speed_ratings, 0x8827, Array(UInt16), nil},
      {oecf, 0x8828, Bytes, nil},         # Could be parsed
      {exif_version, 0x9000, Bytes, nil}, # not String because it has no null terminator
      {date_time_original, 0x9003, Time, nil},
      {date_time_digitized, 0x9004, Time, nil},
      {components_configuration, 0x9101, Bytes, nil}, # maybe parse it,
      {compressed_bits_per_pixel, 0x9102, Rational(UInt32), nil},
      {shutter_speed_value, 0x9201, Rational(Int32), nil},
      {aperture_value, 0x9202, Rational(UInt32), nil},
      {brightness_value, 0x9203, Rational(Int32), nil},
      {exposure_bias_value, 0x9204, Rational(Int32), nil},
      {max_aperture_value, 0x9205, Rational(UInt32), nil},
      {subject_distance, 0x9206, Rational(Int32), nil}, # meter. maybe add optional unit to rational ?
      {metering_mode, 0x9207, MeteringMode, nil},
      {light_source, 0x9208, LightSource, nil},
      {flash, 0x9209, UInt16, ->(value : UInt16) { Flash.new value }},
      {focal_length, 0x920a, Rational(UInt32), nil},
      {maker_note, 0x927c, Bytes, nil},
      {user_comment, 0x9286, Bytes, ->(value : Bytes) { UserComment.from_value value }},
      {subsec_time, 0x9290, String, ->(v : String) { v.chars.all?(&.== Char::ZERO) ? nil : v.to_i.milliseconds }},
      {subsec_time_original, 0x9291, String, ->(v : String) { v.chars.all?(&.== Char::ZERO) ? nil : v.to_i.milliseconds }},
      {subsec_time_digitized, 0x9292, String, ->(v : String) { v.chars.all?(&.== Char::ZERO) ? nil : v.to_i.milliseconds }},
      {flash_pix_version, 0xa000, Bytes, nil}, # No null terminator
      {color_space, 0xa001, ColorSpace, nil},
      {exif_image_width, 0xa002, UInt16 | UInt32 | Array(UInt16), nil},
      {exif_image_height, 0xa003, UInt16 | UInt32 | Array(UInt16), nil},
      {related_sound_file, 0xa004, String, nil},
      {flash_energy, 0xa20b, Rational(Int32), nil},
      {interoperability, 0xa005, Interoperability, nil},
      {focal_plane_x_resolution, 0xa20e, Rational(UInt32), nil},
      {focal_plane_y_resolution, 0xa20f, Rational(UInt32), nil},
      {focal_plane_resolution_unit, 0xa210, Unit, nil},
      {exposure_index, 0xa215, Rational(UInt32), nil}, # See iso_speed_rating, same format but unsigned. Historical error.
      {sensing_method, 0xa217, SensingMethod, nil},
      {file_source, 0xa300, Bytes, nil},
      {scene_type, 0xa301, Bytes, nil},
      {cfa_pattern, 0xa302, Bytes, nil},
      {custom_rendered, 0xa401, UInt16, ->(value : UInt16) { value != 0 }},
      {exposure_mode, 0xa402, ExposureMode, nil},
      {white_balance, 0xa403, WhiteBalance, nil},
      {digital_zoom_ratio, 0xa404, Rational(UInt32), nil},
      {focal_length_in_35mm_film, 0xa405, UInt16, nil},
      {scene_capture_type, 0xa406, SceneType, nil},
      {gain_control, 0xa407, GainControl, nil},
      {contrast, 0xa408, Contrast, nil},
      {saturation, 0xa409, Saturation, nil},
      {sharpness, 0xa40a, Sharpness, nil},
      {gamma, 0xa500, Rational(UInt32), nil},
      {device_setting_description, 0xa40b, Bytes, nil},
      {subject_distance_range, 0xa40c, DistanceRange, nil},
      {image_uid, 0xa420, String, nil},
      {subject_area, 0x9214, Array(UInt16), nil},
      {sensitivity_type, 0x8830, UInt16, nil}, # I dont know how to interpret it
      {camera_owner_name, 0xa430, String, nil},
      {lens_specifications, 0xa432, Array(Rational(UInt32)), nil},
      {lens_make, 0xa433, String, nil},
      {lens_model, 0xa434, String, nil},
      {lens_serial_number, 0xa435, String, nil},
      {offset_time, 0x9010, String, nil},
      {offset_time_original, 0x9011, String, nil},
      {offset_time_digitized, 0x9012, String, nil},
      {body_serial_number, 0xa431, String, nil},
      {offset_schema, 0xea1d, UInt32, nil},
    ]
  end

  class Tiff < Ifd
    @alignement : IO::ByteFormat
    @buffer : Bytes
    @io : IO

    getter alignement
    getter buffer
    getter io

    def initialize(@buffer)
      @io = IO::Memory.new @buffer
      # Parse TIFF header
      case @io.read_bytes UInt16, IO::ByteFormat::BigEndian
      when 0x4d4d then @alignement = IO::ByteFormat::BigEndian
      when 0x4949 then @alignement = IO::ByteFormat::LittleEndian
      else             raise Exception.new "Bad alignment entry in TIFF header"
      end
      magic = @io.read_bytes UInt16, @alignement
      raise Exception.new "Bad magic entry in TIFF header: 0x#{magic.to_s 16}" unless 0x002a == magic
      offset = @io.read_bytes UInt32, @alignement
      super self, offset, nil
    end

    def serialize(copy_to : IO? = nil) : IO
      output = IO::Memory.new
      # Output might not be repositionnable
      if @alignement == IO::ByteFormat::BigEndian
        0x4d4du16.to_io output, @alignement
      elsif @alignement == IO::ByteFormat::LittleEndian
        0x4949u16.to_io output, @alignement
      else
        raise Exception.new "Bad alignment: #{@alignement}"
      end
      0x002au16.to_io output, @alignement
      0x8u32.to_io output, @alignement
      super output
      size = output.pos # Weird stuff
      output.rewind
      IO.copy output, copy_to, size if copy_to

      output
    end
  end
end

tiff = MakeItRight.from_jif ARGV.first
if tiff
  puts "All the tags:"
  pp tiff.all
  puts
  puts "All the unknown tags:"
  pp tiff.all_unknown_tags
  puts
  puts "All errors:"
  pp tiff.all_errors
  puts "Rewriting to result.jpg"
  MakeItRight.patch_jif tiff, ARGV.first, "result.jpg"
else
  puts "No tiff data found"
end
