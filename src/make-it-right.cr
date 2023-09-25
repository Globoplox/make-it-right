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

  def self.from_jif(path : String | Path, filters : Filters? = nil) : MainImageIfd?
    File.open path do |io|
      from_jif io, filters
    end
  end

  # Extract tags from a JIF file.
  def self.from_jif(io : IO, filters : Filters? = nil) : MainImageIfd?
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
        return from_exif io, filters
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

    def get_u16(tag : UInt16) : UInt16?
      entry = @tags[tag]?
      return unless entry
      raise Exception.new "This tag is not registered as UInt16" unless entry[:format] == 3 && entry[:components] == 1
      (entry[:value] >> 16).to_u16!
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
  end

  class ExifIfd < Ifd
    property interoperability : InteroperabilityIfd?
  end

  class ThumbnailIfd < Ifd
    property interoperability : InteroperabilityIfd?
  end

  class MainImageIfd < Ifd
    property exif : ExifIfd?
    property tumbnail : ThumbnailIfd?

    def orientation
      get_u16(0x0112u16).try do |value|
        Orientation.from_value value
      end
    end
  end

  enum Orientation
    TOP_LEFT
    TOP_RIGHT
    BOTTOM_RIGHT
    BOTTOM_LEFT
    LEFT_TOP
    RIGHT_TOP
    RIGHT_BOTTOM
    LEFT_BOTTOM
  end
end

pp MakeItRight.just_give_me_the_orientation ARGV.first
