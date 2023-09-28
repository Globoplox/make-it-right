# make-it-right

Important todo/note to myself:

- There might be TWO APP1 (one for EXIF, one for XMP)

- Allow to store original IO offset of tag entry for in place editing
- Remove filters
- Remove the close? param and just buffer all and rewrap into an IO.
- Make sub IFD regular lazy value (Have to handle both 'offset' and 'bytes' flavor)
  - Including the offset IFD (will need to have a specialized accessor)
- Maybe allow, for some tags, to cache the value (usefull if complex, like sub IFD)
- If we parse the IFD from a buffer instead of an IO, we can reduce allocation by slicing the original slice
  instead of copying it.
  We could actually have both parameter (io/slice) passed or, if slice, wrap io, if io only, dup when slicing.
- Maybe merge all the tags within a single IFD type.
- Ifd#all clear nil tags. Maybe even it should run only for tags present in @tags to avoid useless checks

A pure crystal, zero dependencies EXIF parsing lib.
It will be much less accurate than tool or binding based on exisiting libs (libexif and exiv2).
But it might be less of a pity for simplest needs. Exiv2 is c++ so binding are annoying. There are bindings for libexif available that are surely much better than this if you mostly wish to display the data.
If you just want that damned orientation tag, this lib will be more than enough.
This lib also attempt to produce programmatically practical values rather than purely visual ones.

## Accuracy, testing

Im still working on it but I am using pictures from the exif-sample repository and comparing to exiftool to ensure, as much as possible:

- I detect all the tags (not yet, there are oddities (subifd where there should not, and maker_note))
- I know all the tags (All the one I detect at least lol)
- I successfully parse all the tags
- I can read then write to the same jpeg and produce an
  image identical to the source (when possible, there might be ordering that change, but it should be valid)
- In the future, i will have to test that writing tags work correctly

## Rapid overview of exif and related for the people that wish they weren't here (like me) SKIP if you already KnowTheThings™

JPEG is a compression method for image.
JIF is a file format for storing JPEG compressed image.
JFIF is an extension of JIF that add metadata to JIF.
TIFF is a file format for storing various things along with metadata.
EXIF is a specification for storing metadata.
When talking about EXIF in images, usually it means having a regular JIF of JFIF file with an additional TIFF file, itself including EXIF metadata.

Tags are TIFF/EXIF key/value metadata
IFD are a group of related tags. IFD can have sub-IFD.
The important IFD an image can have:

- An image IFD, containong details about the image
  - An EXIF/Photo IFD, containing details about how the photo was taken
  - A GPS IFD
  - A Maker Note IFD containing details specific to the manufacturer of the camera that crated the file
- A thumbnail IFD, containing details about the thumbnail image if there is one

Now the main issue about EXIF/TIFF is that it is usually poorly implemented and often tags or even IFD are not where the IFD they should, have aberrant values, or even out of spec types.
Most of the time the EXIF/TIFF metadata are completely irrelevant, but some infamous metadata tags can affect how the picture will be displayed in some tools, which force everyone else to care about this.

## Usage

Extract tags from a JPEG picture:

```cr
tags = MakeItRight.from_jif "path/to/picture.jpg"
unless tags
  puts "no tags data found"
end
```

You can also open TIFF file with `#from_tiff`

Extract tags from the payload of an APP1 block of a JIF (.jpg) file that you are parsing by your own means:

```cr
tags = MakeItRight.from_exif io_jif_app1_payload_without_marker_and_size
```

Access a particular subcategory (ifd) of tags:

```cr
MakeItRight.from_jif("path/to/picture.jpg").try do |image|
  puts "Image tags are presents"

  image.thumbnail.try do |thumbnail|
    puts "Thumbnail tags are presents"

    thumbnail.interoperability.try do |interoperability|
      puts "Thumbnail interoperability tags are presents"
    end

  end

  image.exif.try do |exif|
    puts "Exif tags are presents"

    exif.interoperability.try do |interoperability|
      puts "Exif interoperability tags are presents"
    end

    exif.maker_note.try do |maker_note|
      puts "Exif maker_note tags are presents"
    end

  end

  image.gps.try do |gps|
    puts "GPS tags are presents"
  end
end
```

Access a particular tag:

```cr
tags = MakeItRight.from_jif "path/to/picture.jpg"
orientation = tags.try &.orientation
thumb_orientation = tags.try &.thumbnail.try &.orientation
```

Reduce parsing time / allocation amount slightly by specifying intersting tags:

```cr
filters = MakeItRight::Filters{:tags => [0x0112u16], :thumbnail => {:tags => [0x0112u16]}}
tags = MakeItRight.from_jif "path/to/picture.jpg", filters
```

Dump all the successfully decoded tags:

```cr
tags = MakeItRight.from_jif "path/to/picture.jpg", filters
if tags
  puts "All the tags:"
  pp tags.all
else
  puts "no tags data found"
end
```

Check if there were any errors while decoding any tags:

```cr
tags = MakeItRight.from_jif "path/to/picture.jpg", filters
if tags
  tags.all # trigger decoding, otherwise it is lazy
  puts "Decoding errors:"
  pp tags.all_errors
  # Specific ifd errors:
  # tags.errors
  # tags.exif.try &.errors
  # ...
end
```

Check if there were tags unhandled (present in file but not expected, without a known name and decoding)

```cr
tags = MakeItRight.from_jif "path/to/picture.jpg", filters
if tags
  puts "Unknown tags:
  pp tags.all_unknown || "none, yay !"
  # Specific ifd:
  # tags.unknown_tags
  # tags.exif.try &.unknown_tags
  # ...
end
```

Access the actual thumbnail raw image data

```cr
tags = MakeItRight.from_jif "path/to/picture.jpg", filters
if tags
  tags.thumbnail.try &.data.try do |thumbnail_picture_data|
    puts thumbnail_picture_data.size
  end
end
```

### TODO

- [ ] Write into JPEG (parse JIF, omit existing, insert)
- [ ] Tag write
- [ ] Write in place into JPEG (zero previous, write over (must have enough space)
- [ ] Remove from JPEG
- [ ] Pluto integration

### TODO but probably wont do

- [ ] Maker Note (im a coward)
- [ ] Swapping endianess
- [ ] Parse JFIF (APP0)
- [ ] Parse XMP (APP1 but not exif)
- [ ] Parse ICC (APPx idk)
- [ ] Parse Photoshop metadata (APPx idk)
- [ ] Parse from TIFF (who care)
- [ ] Parse from PNG (barely standard)
- [ ] Parse from HEIC (what is this)
- [ ] Write into and pluto integration for all those file format

## Installation

1. Add the dependency to your `shard.yml`:

   ```yaml
   dependencies:
     make-it-right:
       github: globoplox/make-it-right
   ```

2. Run `shards install`

## Usage

```crystal
require "make-it-right"
```

TODO: Write usage instructions here

## Development

TODO: Write development instructions here

## Contributing

1. Fork it (<https://github.com/your-github-user/make-it-right/fork>)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## Contributors

- [Pierre Rousselle](https://github.com/your-github-user) - creator and maintainer
