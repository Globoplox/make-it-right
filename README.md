# make-it-right

A pure crystal, zero dependencies EXIF parsing lib. It will be less accurate than tool or binding based on libexif, however it might be easier to use for simple cases.

It is tested with [exiftool](https://exiftool.org/) and [exif-samples](https://github.com/ianare/exif-samples.git).

It support reading and writing TIFF/EXIF data embedded into JIF (jpg) files.  

It does not support maker notes. It will attempt to write back maker notes when serializing, but it:

- Will NOT write maker note at the same offset that they were read from
- Will NOT correct offset included into maker notes if the maker notes block moved
- WIll NOT parse or write back any maker note data that are not included within the data block whose size and offset are indicated by the makre note tag.

## Is it production ready ?

No, there might be alignment related issues when reading/writing some tags, and absence of maker notes supports might corrupt said maker notes.

## Quick overview of EXIF

JPEG is a compression method for image.
JIF is a file format for storing JPEG compressed image.
JFIF is an extension of JIF that add metadata to JIF.
TIFF is a file format for storing various things along with metadata.
EXIF is a specification for storing metadata.
When talking about EXIF in images, usually it means having a JIF file with an additional TIFF file embbed, itself including EXIF metadata.

Tags are TIFF/EXIF key/value metadata
IFD are a group of related tags. IFD can have sub-IFD.
The important IFD an image can have:

- An image IFD, containong details about the image
  - An EXIF/Photo IFD, containing details about how the photo was taken
  - A GPS IFD
  - A Maker Note IFD containing details specific to the manufacturer of the camera that crated the file
- A thumbnail IFD, containing details about the thumbnail image if there is one

## Usage

```cr
require "make-it-right"

puts "Opening picture #{ARGV.first}"
tiff = MakeItRight.from_jif ARGV.first
unless tiff
  puts "Picture #{ARGV.first} does not contains a TIFF/EXIF block, creating one."
  tiff = MakeItRight::Tiff.new

  puts "Created block will have an EXIF subifd"
  tiff.exif = tiff.new_subifd.tap { |exif|
    puts "Created EXIF subifd will have an interoperability subifd"
    exif.interoperability = tiff.new_subifd(MakeItRight::Interoperability).tap { |interoperability|
      puts "Created interoperability subifd will have an index and version"
      interoperability.index = "R98\0".to_slice
      interoperability.version = "0100".to_slice
    }
  }
else
  puts "Picure #{ARGV.first} contained a TIFF/EXIF block"
  puts "Displaying all the tags found:"
  puts "============================================"
  pp tiff.all
  puts "============================================"
  puts
  puts "Diplaying all unknown tags found:"
  pp tiff.all_unknown_tags
  puts
  puts "Displaying every error encountered:"
  pp tiff.all_errors
end

puts
puts "Setting the orientation tag of the picture to right-top"
tiff.orientation = MakeItRight::Orientation::RIGHT_TOP
tiff.gps.try do |gps|
  puts "The picture has GPS data"
  puts "Removing GPS data"
  tiff.gps = nil
  # Note that there might be other gps data elsewhere, in EXIF or somewhere else in the picture file.
end

puts
tiff.next.try do |thumbnail|
  puts "The picture has a thumbnail"
  puts "Setting the orientation for the thumbnail to right-top"
  thumbnail.orientation = MakeItRight::Orientation::RIGHT_TOP
  # We could remove/replace the thumbnail data if we wanted to:
  # thumbnail.payload = nil
  # thumbnail.payload = Bytes.new size: 4
end
puts

puts "Copying #{ARGV.first} to result.jpg with the added/edited TIFF/EXIF data block"
MakeItRight.patch_jif tiff, ARGV.first, "result.jpg"
```

Usage with [Pluto](https://github.com/phenopolis/pluto):

This example shows how to re-orient a pluto picture relative to an EXIF orientation tag.  
This allows to ensure that an image stripped of its exif metadata will still be displayed correctly.  
If you do not wish to strip the exif data, the prefered way should be to patch the jif as shown in the previous example.  
Note that pluto is not listed as a dependency.

```cr
require "pluto"
require "pluto/format/jpeg"
require "pluto/format/png"
require "make-it-right/pluto"

module Test

  file_data = File.open ARGV.first do |file|
    file.getb_to_end
  end

  image = Pluto::ImageRGBA.from_jpeg file_data

  File.open "stripped.png", "w" do |file|
    image.to_png file
  end


  tiff = MakeItRight.from_jif IO::Memory.new file_data

  puts "Orientation: #{tiff.try(&.orientation) || "none"}"

  image = MakeItRight.straighten_pluto_picture image, tiff.try(&.orientation)

  File.open "result.png", "w" do |file|
    image.to_png file
  end
end
```

Alternatively, you can require a pluto plugin that will automatically correct every JPEG picture opened with pluto:

```cr
require "pluto"
require "pluto/format/jpeg"
require "pluto/format/png"
require "make-it-right/pluto/plugin"

module Test
  file_data = File.open ARGV.first do |file|
    file.getb_to_end
  end

  image = Pluto::ImageRGBA.from_jpeg file_data

  File.open "result.png", "w" do |file|
    image.to_png file
  end
end
```

### TODO

- [ ] Fix all tag type r/w to support both alignment
- [ ] Support write on all tag types
- [ ] Maker Note

## Installation

1. Add the dependency to your `shard.yml`:

   ```yaml
   dependencies:
     make-it-right:
       github: globoplox/make-it-right
   ```

2. Run `shards install`

## Contributing

1. Fork it (<https://github.com/globoplox/make-it-right/fork>)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## Contributors

- [Pierre Rousselle](https://github.com/globoplox) - creator and maintainer
