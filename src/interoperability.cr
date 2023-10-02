require "./ifd"

class MakeItRight::Interoperability < MakeItRight::Ifd
  register_tags [
    {index, 0x0001, Bytes, nil},
    {version, 0x0002, Bytes, nil},
    {related_image_file_format, 0x1000, String, nil},
    {related_image_width, 0x1001, UInt16 | UInt32, nil},
    {related_image_height, 0x1002, UInt16 | UInt32, nil},
  ]
end
