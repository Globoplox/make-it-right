require "./ifd"

class MakeItRight::Tiff < MakeItRight::Ifd
  @alignement : IO::ByteFormat
  @buffer : Bytes
  @io : IO

  getter alignement
  getter buffer
  getter io

  def initialize
    @alignement = IO::ByteFormat::BigEndian
    @buffer = Bytes.new size: 0
    @io = IO::Memory.new @buffer
    super self
  end

  def initialize(@alignement)
    super
    @buffer = Bytes.new size: 0
    @io = IO::Memory.new @buffer
  end

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
