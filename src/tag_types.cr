module MakeItRight
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
end
