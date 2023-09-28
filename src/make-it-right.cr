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

  def self.just_give_me_the_orientation(param)
    MakeItRight.from_jif(param, MakeItRight::Filters{:tags => [0x0112u16]}).try &.orientation
  end

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

      STR
    end
  end

  class Filters
    property tags : Enumerable(UInt16)?
    property subs : Hash(Symbol, Filters)?

    def initialize(@tags = nil, @subs = nil)
    end

    def []?(symbol : Symbol)
      subs.try &.[symbol]?
    end

    def []=(symbol : Symbol, value : Enumerable(UInt16) | Filters)
      case value
      when Enumerable(UInt16) then @tags = value
      when Filters            then (@subs ||= ({} of Symbol => Filters))[symbol] = value
      end
    end
  end

  enum Orientation
    UNKNOWN      = 0
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
    UNKNOWN    = 0
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
    UNKNOWN           = 0
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
    UNKNOWN                 =   0
    AVERAGE                 =   1
    CENTER_WEIGHTED_AVERAGE =   2
    SPOT                    =   3
    MULTI_SPOT              =   4
    MULTI_SEGMENT           =   5
    PARTIAL                 =   6
    OTHER                   = 255
  end

  enum LightSource
    UNKNOWN          =   0
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
  end

  enum ColorSpace
    UNKNOWN      =     0
    SRGB         =     1
    UNCALIBRATED = 65535
  end

  enum SensingMethod
    INVALID                 = 0
    UNDEFINED               = 1
    ONE_CHIP_COLOR_AREA     = 2
    TWO_CHIP_COLOR_AREA     = 3
    THREE_CHIP_COLOR_AREA   = 4
    COLOR_SEQUENTIAL_AREA   = 5
    TRILINEAR               = 7
    COLOR_SEQUENTIAL_LINEAR = 8
  end

  enum Compression
    UNKNOWN       =     0
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
    UNKNOWN    = 0
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
    UNKNOWN = 0
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
      new encoding, String.new value[8...(value.size - 1)]
    end

    property encoding : Bytes
    property value : String

    def initialize(@encoding, @value)
    end

    def to_s(io)
      io << @value
    end
  end

  def self.from_jif(path : String | Path, filters : Filters? = nil) : MainImageIfd?
    File.open path do |io|
      from_jif io, filters, close: true
    end
  end

  # Extract tags from a JIF file.
  def self.from_jif(io : IO, filters : Filters? = nil, close = false) : MainImageIfd?
    # Parse the JIF searching for the APP1 marker, ingoring everything else.
    marker = io.read_bytes UInt16, IO::ByteFormat::BigEndian
    raise Exception.new "Not a JIF file" unless marker == 0xffd8 # JIF SOI marker (start  of image)
    loop do
      marker = io.read_bytes UInt16, IO::ByteFormat::BigEndian
      case marker
      when 0xffe1
        # JIF APP1 marker, kind of an extension slot where the TIFF file containing the EXIF data is located.
        # See below for the size and - 2 explaination.
        size = io.read_bytes UInt16, IO::ByteFormat::BigEndian
        # We could use the size to limit the io range, but it has no point really.
        app1_copy = Bytes.new size - 2
        io.read app1_copy
        io.close if close # Closing the file descriptor early
        return from_exif IO::Memory.new(app1_copy), filters
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

  # Extract EXIF from an EXIF file
  def self.from_exif(io : IO, filters : Filters? = nil) : MainImageIfd
    raise Exception.new "Not an EXIF file" unless 0x45786966 == io.read_bytes UInt32, IO::ByteFormat::BigEndian
    io.skip 2 # There shoud be 2 null bytes
    # Tiff header
    self.from_tiff io, filters
  end

  def self.from_tiff(path : String | Path, filters : Filters? = nil) : MainImageIfd?
    File.open path do |io|
      from_tiff io, filters
    end
  end

  # Extract tags from a TIFF file
  def self.from_tiff(io : IO, filters : Filters? = nil) : MainImageIfd
    start_at = io.pos
    # Parse TIFF header
    case io.read_bytes UInt16, IO::ByteFormat::BigEndian
    when 0x4d4d then alignement = IO::ByteFormat::BigEndian
    when 0x4949 then alignement = IO::ByteFormat::LittleEndian
    else             raise Exception.new "Bad alignment entry in TIFF header"
    end
    magic = io.read_bytes UInt16, alignement
    raise Exception.new "Bad magic entry in TIFF header: 0x#{magic.to_s 16}" unless 0x002a == magic
    offset = io.read_bytes UInt32, alignement
    io.pos = start_at + offset

    # Parse IFD according to filters
    main_image_ifd = MainImageIfd.new io, filters.try(&.tags), start_at, alignement

    if filters.nil? || (exif_filters = filters[:exif]?)
      main_image_ifd.tags[0x8769]?.try do |exif_offset|
        io.pos = start_at + exif_offset[:value]
        exif = main_image_ifd.exif = ExifIfd.new io, exif_filters.try(&.tags), start_at, alignement

        if filters.nil? || (maker_note_filters = exif_filters.not_nil![:maker_note]?)
          exif.tags[0x927c]?.try do |maker_note_offset|
            io.pos = start_at + maker_note_offset[:value]
            exif.maker_note = MakerNoteIfd.new io, maker_note_filters.try(&.tags), start_at, alignement
          end
        end

        if filters.nil? || (interop_filters = exif_filters.not_nil![:interoperability]?)
          exif.tags[0xa005]?.try do |interop_offset|
            io.pos = start_at + interop_offset[:value]
            exif.interoperability = InteroperabilityIfd.new io, interop_filters.try(&.tags), start_at, alignement
          end
        end
      end
    end

    if filters.nil? || (thumb_filters = filters[:thumbnail]?)
      if (offset_to_next = main_image_ifd.offset) != 0
        io.pos = start_at + offset_to_next
        thumbnail_ifd = ThumbnailIfd.new io, thumb_filters.try(&.tags), start_at, alignement
        main_image_ifd.thumbnail = thumbnail_ifd

        if filters.nil? || thumb_filters.not_nil![:data]?
          data_offset = thumbnail_ifd.tags[0x0201]?.try &.[:value]
          data_size = thumbnail_ifd.tags[0x0202]?.try &.[:value]
          if data_offset && data_size && data_offset != 0 && data_size > 0
            data = Bytes.new data_size
            io.pos = start_at + data_offset
            io.read data
            thumbnail_ifd.data = data
          end
        end

        if filters.nil? || (interop_filters = thumb_filters.not_nil![:interoperability]?)
          thumbnail_ifd.tags[0xa005]?.try do |interop_offset|
            io.pos = start_at + interop_offset[:value]
            thumbnail_ifd.interoperability = InteroperabilityIfd.new io, interop_filters.try(&.tags), start_at, alignement
          end
        end
      end
    end

    if filters.nil? || (gps_filters = filters[:gps]?)
      main_image_ifd.try &.tags[0x8825]?.try do |gps_offset|
        io.pos = start_at + gps_offset[:value]
        main_image_ifd.gps = GpsIfd.new io, gps_filters.try(&.tags), start_at, alignement
      end
    end

    main_image_ifd
  end

  # Image file directory.
  # Basically just a bunch of tag together.
  # This is a tree structure, ifd can contain tags that point to other ifd.
  class Ifd
    getter offset : UInt32
    getter tags
    @alignement : IO::ByteFormat
    @errors = [] of ::Exception

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
              value = get_u16({{tag}}).try { |value| {{type}}.from_value value }
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
        {
          {% for entry in tags %}
            {% name = entry[0] %}
            "{{name.id}}" => {{name.id.underscore}},
          {% end %}
        }
      end

      KNOWN_TAGS = {{tags.map(&.[1])}}

      def unknown_tags
        @tags.reject KNOWN_TAGS
      end
    end

    def errors
      @errors
    end

    # Support UInt16, UInt32, Array(UInt16) as they are the necessary ones
    # but it can be easely extended
    def get_union(tag : UInt16, union_type : T.class) forall T
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

    def get_u16(tag : UInt16) : UInt16?
      entry = @tags[tag]?
      return unless entry
      raise Exception.new "This tag is not registered as UInt16" unless entry[:format] == 3 && entry[:components] == 1
      (entry[:value] >> 16).to_u16!
    end

    def get_u8(tag : UInt16) : UInt8?
      entry = @tags[tag]?
      return unless entry
      raise Exception.new "This tag is not registered as UInt8" unless entry[:format] == 1 && entry[:components] == 1
      (entry[:value] >> 24).to_u8!
    end

    def get_u32(tag : UInt16) : UInt32?
      entry = @tags[tag]?
      return unless entry
      raise Exception.new "This tag is not registered as UInt16" unless entry[:format] == 4 && entry[:components] == 1
      entry[:value]
    end

    def get_ur(tag : UInt16) : Rational(UInt32)?
      entry = @tags[tag]?
      return unless entry
      raise Exception.new "This tag is not registered as Rational(UInt32)" unless entry[:format] == 5 && entry[:components] == 1
      entry[:raw]?.try do |bytes|
        io = IO::Memory.new bytes
        Rational(UInt32).new(
          io.read_bytes(UInt32, @alignement),
          io.read_bytes(UInt32, @alignement)
        )
      end
    end

    def get_r(tag : UInt16) : Rational(Int32)?
      entry = @tags[tag]?
      return unless entry
      raise Exception.new "This tag is not registered as Rational(Int32)" unless entry[:format] == 10 && entry[:components] == 1
      entry[:raw]?.try do |bytes|
        io = IO::Memory.new bytes
        Rational(Int32).new(
          io.read_bytes(Int32, @alignement),
          io.read_bytes(Int32, @alignement)
        )
      end
    end

    def get_aur(tag : UInt16) : Array(Rational(UInt32))?
      entry = @tags[tag]?
      return unless entry
      raise Exception.new "This tag is not registered as Array(Rational(Int32))" unless entry[:format] == 5
      entry[:raw]?.try do |bytes|
        io = IO::Memory.new bytes
        Array(Rational(UInt32)).new entry[:components] do
          Rational(UInt32).new(
            io.read_bytes(UInt32, @alignement),
            io.read_bytes(UInt32, @alignement)
          )
        end
      end
    end

    def get_au16(tag : UInt16) : Array(UInt16)?
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
            io.read_bytes UInt16, @alignement
          end
        end
      end
    end

    def get_au32(tag : UInt16) : Array(UInt32)?
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
            io.read_bytes UInt32, @alignement
          end
        end
      end
    end

    def get_aui(tag : UInt16) : Array(UInt16 | UInt32)?
      entry = @tags[tag]?
      return unless entry
      case entry[:format]
      when 3 then get_au16(tag).try &.map(&.as(UInt16 | UInt32))
      when 4 then get_au32(tag).try &.map(&.as(UInt16 | UInt32))
      else        raise Exception.new "This tag is not registered as Array(UInt16 | UInt32)"
      end
    end

    def get_bytes(tag : UInt16) : Bytes?
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

    def get_string(tag : UInt16) : String?
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
          String.new raw[0, raw.size - 1]
        end
      end
    end

    def initialize(io : IO, filters : Enumerable(UInt16)?, io_start, @alignement)
      # raise Exception.new "Bad filter #{filters}" unless filters.responds_to? :includes?
      entries_count = io.read_bytes UInt16, @alignement
      @tags = Hash(UInt16, {format: UInt16, components: UInt32, value: UInt32, raw: Bytes?}).new initial_capacity: entries_count
      (0...entries_count).each do
        tag = io.read_bytes UInt16, @alignement
        format = io.read_bytes UInt16, @alignement
        components_amount = io.read_bytes UInt32, @alignement
        value_or_offset = io.read_bytes UInt32, @alignement
        if filters.nil? || filters.includes? tag
          case format
          when 1, 2, 6, 7 then bit_per_components = 1
          when 3, 8       then bit_per_components = 2
          when 4, 9, 11   then bit_per_components = 4
          when 5, 10, 12  then bit_per_components = 8
          end

          if bit_per_components && bit_per_components * components_amount > 4
            bytes = Bytes.new bit_per_components * components_amount
          end

          @tags[tag] = {
            format:     format,
            components: components_amount,
            value:      value_or_offset,
            raw:        bytes,
          }
        end
      end
      @offset = io.read_bytes UInt32, @alignement

      # Copy the raw value data for selected tags whose values is an offset to raw data
      @tags.values.each do |entry|
        if bytes = entry[:raw]
          io.pos = io_start + entry[:value]
          io.read bytes
        end
      end
    end
  end

  class InteroperabilityIfd < Ifd
    register_tags [
      {index, 0x0001, Bytes, nil},
      {version, 0x0002, Bytes, nil},
      {related_image_file_format, 0x1000, String, nil},
      {related_image_width, 0x1001, UInt16 | UInt32, nil},
      {related_image_height, 0x1002, UInt16 | UInt32, nil},
    ]

    def all_errors
      errors
    end

    def all_unknown
      unknown_tags unless unknown_tags.empty?
    end
  end

  class ExifIfd < Ifd
    property interoperability : InteroperabilityIfd?
    property maker_note : MakerNoteIfd?

    def all_errors
      @errors +
        (maker_note.try(&.all_errors) || [] of Exception) +
        (interoperability.try(&.all_errors) || [] of Exception)
    end

    register_tags [
      {exposure_time, 0x829a, Rational(UInt32), nil},
      {f_number, 0x829d, Rational(UInt32), nil},
      {exposure_program, 0x8822, ExposureProgram, nil},
      {iso_speed_ratings, 0x8827, Array(UInt16), nil},
      {oecf, 0x8828, Bytes, nil},                                            # Could be parsed
      {exif_version, 0x9000, Bytes, ->(value : Bytes) { String.new value }}, # not String because it has no null terminator
      {date_time_original, 0x9003, String, ->(value : String) { /^\s*$/ =~ value ? nil : Time.parse value, "%Y:%m:%d %H:%M:%S", Time::Location::UTC }},
      {date_time_digitized, 0x9004, String, ->(value : String) { /^\s*$/ =~ value ? nil : Time.parse value, "%Y:%m:%d %H:%M:%S", Time::Location::UTC }},
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
      {maker_note_offset, 0x927c, self, ->(value : self) { value.maker_note.try(&.all) }},
      {user_comment, 0x9286, Bytes, ->(value : Bytes) { UserComment.from_value value }},
      {subsec_time, 0x9290, String, ->(v : String) { v.chars.all?(&.== Char::ZERO) ? nil : v.to_i.milliseconds }},
      {subsec_time_original, 0x9291, String, ->(v : String) { v.chars.all?(&.== Char::ZERO) ? nil : v.to_i.milliseconds }},
      {subsec_time_digitized, 0x9292, String, ->(v : String) { v.chars.all?(&.== Char::ZERO) ? nil : v.to_i.milliseconds }},
      {flash_pix_version, 0xa000, Bytes, ->(value : Bytes) { String.new value }}, # No null terminator
      {color_space, 0xa001, ColorSpace, nil},
      {exif_image_width, 0xa002, UInt16 | UInt32 | Array(UInt16), nil},
      {exif_image_height, 0xa003, UInt16 | UInt32 | Array(UInt16), nil},
      {related_sound_file, 0xa004, String, nil},
      {flash_energy, 0xa20b, Rational(Int32), nil},
      {interoperability_offset, 0xa005, self, ->(value : self) { value.interoperability.try(&.all) }},
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
      # That one is fun, it's an attempt by microsoft to fix maker note that ended being another
      # issue on its own. It probably make no sense.
      {offset_schema, 0xea1d, UInt32, nil},
    ]

    def all_unknown
      u_tags = unknown_tags.empty? ? nil : unknown_tags
      u_interoperability = interoperability.try &.all_unknown
      u_maker_note = maker_note.try &.all_unknown
      {
        "tags"             => u_tags,
        "interoperability" => u_interoperability,
        "maker_note"       => u_maker_note,
      } if u_tags || u_interoperability || u_maker_note
    end
  end

  class ThumbnailIfd < Ifd
    property interoperability : InteroperabilityIfd?
    property data : Bytes?

    def all_errors
      @errors +
        (interoperability.try(&.all_errors) || [] of Exception)
    end

    register_tags [
      {image_width, 0x0100, UInt16 | UInt32, nil},
      {image_height, 0x0101, UInt16 | UInt32, nil},
      {bit_per_sample, 0x0102, Array(UInt16), nil},
      {compression, 0x0103, Compression, nil},
      {photometric_interpretation, 0x0106, PhotometricInterpretation, nil},
      {strip_offsets, 0x0111, Array(UInt16 | UInt32), nil},
      {orientation, 0x0112, Orientation, nil},
      {samples_per_pixel, 0x0115, UInt16, nil},
      {row_per_strip, 0x0116, UInt16, nil},
      {strip_byte_count, 0x0117, UInt16 | UInt32, nil},
      {x_resolution, 0x011a, Rational(UInt32), nil},
      {y_resolution, 0x011b, Rational(UInt32), nil},
      {planar_configuration, 0x011c, UInt16, nil},                                         # Interpretation vary
      {resolution_unit, 0x0128, UInt16, ->(value : UInt16) { Unit.from_thumbnail value }}, # Not the same value as other
      {jpeg_if_offset, 0x0201, UInt32, nil},
      {jpeg_if_byte_count, 0x0202, UInt32, nil},
      {ycbcr_coefficients, 0x0211, Array(Rational(UInt32)), nil},
      {ycbcr_sub_sampling, 0x0212, Array(UInt16), nil},
      {ycbcr_positioning, 0x0213, UInt16, nil},
      {reference_black_white, 0x0214, Array(Rational(UInt32)), nil},
      # Sony put those for thumbnail too:
      {make, 0x010f, String, nil},
      {model, 0x0110, String, nil},
      {date_time, 0x0132, String, ->(value : String) { /^\s*$/ =~ value ? nil : Time.parse value, "%Y:%m:%d %H:%M:%S", Time::Location::UTC }},
    ]

    def all_unknown
      u_tags = unknown_tags.empty? ? nil : unknown_tags
      u_interoperability = interoperability.try &.all_unknown
      {
        "tags"             => u_tags,
        "interoperability" => u_interoperability,
      } if u_tags || u_interoperability
    end
  end

  class MainImageIfd < Ifd
    property exif : ExifIfd?
    property thumbnail : ThumbnailIfd?
    property gps : GpsIfd?

    def all_errors
      @errors +
        (exif.try(&.all_errors) || [] of Exception) +
        (thumbnail.try(&.all_errors) || [] of Exception) +
        (gps.try(&.all_errors) || [] of Exception)
    end

    register_tags [
      {orientation, 0x0112, Orientation, nil},
      {description, 0x010e, String, nil},
      {make, 0x010f, String, nil},
      {model, 0x0110, String, nil},
      {artist, 0x013b, String, nil},
      {x_resolution, 0x011a, Rational(UInt32), nil},
      {y_resolution, 0x011b, Rational(UInt32), nil},
      {x_resolution_unit, 0x0128, Unit, nil},
      {software, 0x0131, String, nil},
      {date_time, 0x0132, String, ->(value : String) { /^\s*$/ =~ value ? nil : Time.parse value, "%Y:%m:%d %H:%M:%S", Time::Location::UTC }},
      {white_point, 0x013e, Array(Rational(UInt32)), nil},
      {primary_chromacities, 0x013f, Array(Rational(UInt32)), nil},
      {ycbcr_coefficients, 0x0211, Array(Rational(UInt32)), nil},
      {ycbcr_positioning, 0x0213, UInt16, nil},
      {reference_black_white, 0x0214, Array(Rational(UInt32)), nil},
      {copyright, 0x8298, String, nil},
      {exif_offset, 0x8769, self, ->(value : self) { value.exif.try(&.all) }},
      {gps_offset, 0x8825, self, ->(value : self) { value.gps.try(&.all) }},
      {print_image_matching, 0xc4a5, Bytes, nil}, # No more info
      {gamma, 0xa500, Rational(UInt32), nil},
      # WINDOWS XP SHITYARD
      {title, 0x9c9b, String, nil},
      {comment, 0x9c9c, String, nil},
      {author, 0x9c9d, String, nil},
      {keywords, 0x9c9e, String, nil},
      {subject, 0x9c9f, String, nil},
      # Those should be in the EXIF ifd but sometimes they are here
      {custom_rendered, 0xa401, UInt16, ->(value : UInt16) { value != 0 }},
      {exposure_mode, 0xa402, ExposureMode, nil},
      {white_balance, 0xa403, WhiteBalance, nil},
      {scene_capture_type, 0xa406, SceneType, nil},
      {contrast, 0xa408, Contrast, nil},
      {saturation, 0xa409, Saturation, nil},
      {sharpness, 0xa40a, Sharpness, nil},
      {subject_distance_range, 0xa40c, DistanceRange, nil},
      {digital_zoom_ratio, 0xa404, Rational(UInt32), nil},
      {focal_length_in_35mm_film, 0xa405, UInt16, nil},
      {gain_control, 0xa407, GainControl, nil},

      # These should be in interoperability, but sometimes they are not
      {related_image_width, 0x1001, UInt16 | UInt32, nil},
      {related_image_height, 0x1002, UInt16 | UInt32, nil},

    ]

    def all
      tags = previous_def
      thumbnail.try do |thumb|
        return tags.merge Hash{"thumbnail" => thumb.all}
      end
      tags
    end

    def all_unknown
      u_tags = unknown_tags.empty? ? nil : unknown_tags
      u_exif = exif.try(&.all_unknown)
      u_thumbnail = thumbnail.try(&.all_unknown)
      u_gps = gps.try(&.all_unknown)

      {
        "tags"      => u_tags,
        "exif"      => u_exif,
        "thumbnail" => u_thumbnail,
        "gps"       => u_gps,
      } if u_tags || u_exif || u_thumbnail || u_gps
    end
  end

  # Todo. It doesnt parse in the same way as other.
  class MakerNoteIfd < Ifd
    def all
      nil
    end

    def all_unknown
      nil
    end

    def all_errors
      errors
    end

    def initialize(io : IO, filters : Enumerable(UInt16)?, io_start, @alignement)
      @offset = 0
      @tags = Hash(UInt16, {format: UInt16, components: UInt32, value: UInt32, raw: Bytes?}).new initial_capacity: 0
    end
  end

  class GpsIfd < Ifd
    register_tags [
      {gps_version, 0x0000, Bytes, ->(value : Bytes) { String.new value }},
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
      # Tags that belongs to other IFD but there pics in the wild with those in gps
      {exposure_time, 0x829a, Rational(UInt32), nil},
      {f_number, 0x829d, Rational(UInt32), nil},
      {exposure_program, 0x8822, ExposureProgram, nil},
      {exif_version, 0x9000, Bytes, ->(value : Bytes) { String.new value }}, # not String because it has no null terminator
      {date_time_original, 0x9003, String, ->(value : String) { /^\s*$/ =~ value ? nil : Time.parse value, "%Y:%m:%d %H:%M:%S", Time::Location::UTC }},
      {date_time_digitized, 0x9004, String, ->(value : String) { /^\s*$/ =~ value ? nil : Time.parse value, "%Y:%m:%d %H:%M:%S", Time::Location::UTC }},
      {components_configuration, 0x9101, Bytes, nil}, # maybe parse it,
      {flash, 0x9209, UInt16, ->(value : UInt16) { Flash.new value }},
      {focal_length, 0x920a, Rational(UInt32), nil},
      # This one is gonna make me SO MAD FFS WHY THE FUCK IS IT IN GPS
      {maker_note_offset, 0x927c, self, ->(value : self) { nil }},
      {flash_pix_version, 0xa000, Bytes, ->(value : Bytes) { String.new value }}, # No null terminator
      {color_space, 0xa001, ColorSpace, nil},
      {exif_image_width, 0xa002, UInt16 | UInt32 | Array(UInt16), nil},
      {exif_image_height, 0xa003, UInt16 | UInt32 | Array(UInt16), nil},
      {related_sound_file, 0xa004, String, nil},
      # THIS ONE TOO
      {interoperability_offset, 0xa005, self, ->(value : self) { nil }},
      # Ok so I am gonna have to do a generic ifd shit stuff i guess ?

    ]

    # override all_errors and all_unknowns if we add more subifd
    def all_errors
      errors
    end

    def all_unknown
      unknown_tags unless unknown_tags.empty?
    end
  end
end
