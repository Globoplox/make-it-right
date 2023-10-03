# Image file directory.
# Basically just a bunch of tag together.
# This is a tree structure, ifd can contain tags that point to other ifd.
class MakeItRight::Ifd
  alias Summary = String | Hash(String, Summary) | Nil

  macro register_tags(tags)
    {% for entry in tags %}
      {% name = entry[0] %}
      {% tag = entry[1] %}
      {% type = entry[2] %}
      {% wrapper = entry[3] %}

      def {{name.id.underscore}}
        {% if type.id == Array(UInt16 | UInt32).id %}
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

      def {{name.id.underscore}}=(value : {{type}}?)
        {% if type.id == Array(UInt16 | UInt32).id %}
          raise "Unknown tag type {{type.id}} for writting"
        {% elsif type.id.includes? '|' %}
          raise "Unknown tag type {{type.id}} for writting"
        {% else %}
          {% type = type.resolve %}
          {% if type < Enum %}
            set_enum {{tag}}, value
          {% elsif type <= Ifd %}
            if value
              set_subifd {{tag}}.to_u16, value, {{type}}
            else
              remove_subifd {{tag}}.to_u16
            end
          {% elsif type.id == UInt16.id %}
            set_u16 {{tag}}, value
          {% elsif type.id == Bytes.id %}
            set_b {{tag}}, value
          {% else %}
            raise "Unknown tag type {{type.id}} for writting"
          {% end %}
        {% end %}
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

  protected def set_tag(tag : UInt16, value : T?) forall T
    if value
      @tags[tag] = yield value
    else
      @tags.delete tag
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

  protected def set_enum(tag : UInt16, value)
    set_u16 tag, value.try &.to_u16!
  end

  protected def get_time(tag : UInt16) : Time?
    get_string(tag).try do |value|
      /^\s*$/ =~ value ? nil : Time.parse value, "%Y:%m:%d %H:%M:%S", Time::Location::UTC
    end
  end

  @subifd_cache = {} of UInt16 => Ifd?

  protected def get_subifd(type, tag : UInt16) : Ifd?
    if @subifd_cache.has_key? tag
      return @subifd_cache[tag]
    else
      entry = @tags[tag]?
      return unless entry
      @subifd_cache[tag] = type.new @tiff, entry[:value], tag
    end
  end

  protected def set_subifd(tag : UInt16, value : T, type : T.class) forall T
    value.origin_tag = tag
    @subifd_cache[tag] = value
    @tags[tag] = {format: 4u16, components: 1u32, value: 0u32, raw: nil}
  end

  protected def remove_subifd(tag : UInt16)
    @tags.delete tag
    @subifd_cache[tag] = nil
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
    if @tiff.alignement == IO::ByteFormat::LittleEndian
      entry[:value].to_u16!
    else
      (entry[:value] >> 16).to_u16!
    end
  end

  protected def set_u16(tag : UInt16, value : UInt16?)
    set_tag tag, value do |value|
      {format: 3u16, components: 1u32, value: value.to_u32, raw: nil}
    end
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
      [(entry[:value]).to_u16!]
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
        raw[i] = (entry[:value] >> (i * 8)).to_u8!
      end
      raw
    else
      entry[:raw]
    end
  end

  protected def set_b(tag : UInt16, value : Bytes?)
    set_tag tag, value do |value|
      if value.size > 4
        {format: 7.to_u16, components: value.size.to_u32, value: 0u32, raw: value}
      else
        int = 0u32
        value.each do |byte|
          int = (int << 8) + byte
        end
        {format: 7.to_u16, components: value.size.to_u32, value: int, raw: nil}
      end
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

  @next_cache : Ifd?

  def next : Ifd?
    @offset_to_next != 0 ? (@next_cache ||= Ifd.new(@tiff, @offset_to_next, nil)) : nil
  end

  def next=(value : Ifd?)
    if value
      value.origin_tag = nil
      @next_cache = value
      @offset_to_next = 1
    else
      @next_cache = nil
      @offset_to_next = 0
    end
  end

  @payload_cache : Bytes?

  def payload : Bytes?
    cache = @payload_cache
    return cache if cache

    if (data_offset = @tags[0x0201]?) && (data_size = @tags[0x0202]?)
      @payload_cache = @tiff.buffer[data_offset[:value], data_size[:value]]
    end
  end

  def payload=(value : Bytes?)
    if value
      @payload_cache = value
      @tags[0x0201u16] = {format: 4u16, components: 1u32, value: 0u32, raw: nil}
      @tags[0x0202u16] = {format: 4u16, components: 1u32, value: value.size.to_u32, raw: nil}
    else
      @payload_cache = nil
      @tags.delete 0x0201
      @tags.delete 0x0202
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
  protected property origin_tag

  protected def initialize(@tiff : Tiff)
    @offset = 0
    @origin_tag = nil
    @tags = Hash(UInt16, {format: UInt16, components: UInt32, value: UInt32, raw: Bytes?}).new
    @offset_to_next = 0
  end

  def new_subifd(type = Ifd)
    type.new @tiff
  end

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
    @tags.size.to_u16.to_io output, alignement
    data_offset = output.pos + 4 + @tags.size * 12
    # Subifd tags and the offset in header to their value offset
    # It make sense I promise
    subifd_offsets = [] of {ifd: Ifd, offset: UInt32}
    payload_offset_offset = nil

    @tags.keys.sort.each do |tag|
      entry = @tags[tag]
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

      payload_offset_offset = output.pos if tag == 0x0201

      if subifd = subifds.find(&.origin_tag.== tag)
        subifd_offsets << {ifd: subifd, offset: output.pos.to_u32}
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
    @tags.keys.sort.each do |tag|
      entry = @tags[tag]
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
    @tags.keys.sort.each do |tag|
      entry = @tags[tag]
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
      payload_position = output.pos
      output.write payload
      payload_offset_offset.try do |offset|
        current_pos = output.pos
        output.pos = offset
        payload_position.to_u32.to_io output, alignement
        output.pos = current_pos
      end || raise Exception.new "Payload is present but payload offset tag is not"
    end
  end
end
