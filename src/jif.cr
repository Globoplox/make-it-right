require "./tiff"

module MakeItRight
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
end
