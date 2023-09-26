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
# Reference http://www.fifi.org/doc/jhead/exif-e.html#ExifData
module MakeItRight
  VERSION = {{ `shards version __DIR__`.chomp.stringify }}

  def self.just_give_me_the_orientation(param)
    MakeItRight.from_jif(param, MakeItRight::Filters{:tags => [0x0112u16]}).try &.orientation
  end

  class Exception < ::Exception
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
    def self.from_value(value : UInt16)
      new(value & 0b1 != 0, value & 0b10 != 0, value & 0b100 != 0)
    end

    property fired : Bool
    property detectable : Bool
    property detected : Bool

    def initialize(@fired, @detected, @detectable)
    end
  end

  enum ColorSpace
    UNKNOWN      =     0
    SRGB         =     1
    UNCALIBRATED = 65535
  end

  enum SensingMethod
    UNKNOWN = 0
    REGULAR = 1
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
        if filters.nil? || (interop_filters = thumb_filters.not_nil![:interoperability]?)
          thumbnail_ifd.try &.tags[0xa005]?.try do |interop_offset|
            io.pos = start_at + interop_offset[:value]
            thumbnail_ifd.interoperability = InteroperabilityIfd.new io, interop_filters.try(&.tags), start_at, alignement
          end
        end
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

    macro register_tags(tags)
      {% for entry in tags %}
        {% name = entry[0] %}
        {% tag = entry[1] %}
        {% type = entry[2] %}
        {% if type.id == "self".id %}
        # TODO: make this generic
        {% elsif type.id == "UInt16 | UInt32" %}
          {% type = Union(UInt16, UInt32) %}
        {% else %}
          {% type = type.resolve %}
        {% end %}
        {% wrapper = entry[3] %}
        def {{name.id.underscore}}
          {% if type.id == "self".id %}
            value = self
          {% elsif type.union? %}
            value = get_union {{tag}}, {{type}}
          {% elsif type < Enum %}
            value = get_u16({{tag}}).try { |value| {{type}}.from_value value }
          {% elsif type.id == Bytes.id %}
            value = get_bytes {{tag}}
          {% elsif type.id == String.id %}
            value = get_string {{tag}}
          {% elsif type.id == UInt16.id %}
            value = get_u16 {{tag}}
          {% elsif type.id == Array(UInt16).id %}
            value = get_au16 {{tag}}
          {% elsif type.id == Rational(UInt32).id %}
            value = get_ur {{tag}}
          {% elsif type.id == Rational(Int32).id %}
            value = get_r {{tag}}
          {% elsif type.id == Array(Rational(UInt32)).id %}
            value = get_aur {{tag}}
          {% else %}
            {% raise "Unknown tag type #{type.id}" %}
          {% end %}

          {% if wrapper %}
            value.try do |{{wrapper.args.first.name}}|
              {{wrapper.body}}
            end
          {% else %}
            value
          {% end %}
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
    end

    # Support only UInt16 and UInt32 as they are the necessary ones
    # but it can be easely extended
    def get_union(tag : UInt16, union_type : T.class) forall T
      entry = @tags[tag]?
      return unless entry
      case entry[:format]
      when 3
        type = UInt16
        value = get_u16 tag
      when 4
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
  end

  class ExifIfd < Ifd
    property interoperability : InteroperabilityIfd?
    property maker_note : MakerNoteIfd?

    register_tags [
      {exposure_time, 0x829a, Rational(UInt32), nil},
      {f_number, 0x829d, Rational(UInt32), nil},
      {exposure_program, 0x8822, ExposureProgram, nil},
      {iso_speef_ratings, 0x8827, Array(UInt16), nil},
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
      {flash, 0x9209, UInt16, ->(value : UInt16) { Flash.from_value value }},
      {focal_length, 0x920a, Rational(UInt32), nil},
      {maker_note_offset, 0x927c, self, ->(value : self) { value.maker_note.try(&.all) }},
      {user_comment, 0x9286, Bytes, ->(value : Bytes) { UserComment.from_value value }},
      {subsec_time, 0x9290, String, ->(v : String) { v.to_i.milliseconds }},
      {subsec_time_original, 0x9291, String, ->(v : String) { v.to_i.milliseconds }},
      {subsec_time_digitized, 0x9292, String, ->(v : String) { v.to_i.milliseconds }},
      {flash_pix_version, 0xa000, Bytes, ->(value : Bytes) { String.new value }}, # No null terminator
      {color_space, 0xa001, ColorSpace, nil},
      {exif_image_width, 0xa002, UInt16 | UInt32, nil},
      {exif_image_height, 0xa003, UInt16 | UInt32, nil},
      {related_sound_file, 0xa004, String, nil},
      {interoperability_offset, 0xa005, self, ->(value : self) { value.interoperability.try(&.all) }},
      {focal_plane_x_resolution, 0xa20e, Rational(UInt32), nil},
      {focal_plane_y_resolution, 0xa20f, Rational(UInt32), nil},
      {focal_plane_resolution_unit, 0xa210, Unit, nil},
      {exposure_index, 0xa215, Rational(UInt32), nil}, # See iso_speed_rating, same format but unsigned. Historical error.
      {sensing_method, 0xa217, SensingMethod, nil},
      {file_source, 0xa300, Bytes, nil},
      {scene_type, 0xa301, Bytes, nil},
      {cfa_pattern, 0xa302, Bytes, nil},
    ]
  end

  class ThumbnailIfd < Ifd
    property interoperability : InteroperabilityIfd?
  end

  class MainImageIfd < Ifd
    property exif : ExifIfd?
    property tumbnail : ThumbnailIfd?

    register_tags [
      {orientation, 0x0112, Orientation, nil},
      {description, 0x010e, String, nil},
      {make, 0x010f, String, nil},
      {model, 0x0110, String, nil},
      {x_resolution, 0x011a, Rational(UInt32), nil},
      {y_resolution, 0x011b, Rational(UInt32), nil},
      {x_resolution_unit, 0x0128, Unit, nil},
      {software, 0x0131, String, nil},
      {date_time, 0x0132, String, ->(value : String) { /^\s*$/ =~ value ? nil : Time.parse value, "%Y:%m:%d %H:%M:%S", Time::Location::UTC }},
      {white_point, 0x013e, Array(Rational(UInt32)), nil},
      {primary_chromacities, 0x013f, Array(Rational(UInt32)), nil},
      {ycbcr_coefficients, 0x0211, Array(Rational(UInt32)), nil},
      {ycbcr_positionning, 0x0213, UInt16, nil},
      {reference_black_white, 0x0214, Array(Rational(UInt32)), nil},
      {copyright, 0x8298, String, nil},
      {exif_offset, 0x8769, self, ->(value : self) { value.exif.try(&.all) }},
    ]
  end

  # Todo. It doesnt parse in the same way as other.
  class MakerNoteIfd < Ifd
    def all
      nil
    end

    def initialize(io : IO, filters : Enumerable(UInt16)?, io_start, @alignement)
      @offset = 0
      @tags = Hash(UInt16, {format: UInt16, components: UInt32, value: UInt32, raw: Bytes?}).new initial_capacity: 0
    end
  end
end

exif = MakeItRight.from_jif ARGV.first
unless exif
  puts "no exif data found"
  exit 0
end
pp exif.all
