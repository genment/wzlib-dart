part of wzlib;

class WzImage extends WzObject with PropertyContainer {
  //region Fields

  @override
  List<WzImageProperty> get wzProperties {
    if (_reader != null && !parsed) {
      ParseImage();
    }
    return _properties;
  }

  final WzBinaryReader? _reader;

  WzBinaryReader get reader => _reader!;

  bool parsed = false;

  int offset = 0;
  int blockStart = 0;
  int blockSize = 0;
  int checksum = 0;

  int tempFileStart = 0;
  int tempFileEnd = 0;

  bool changed = false;
  bool parseEverything = false;

  /// Wz image embedding .lua file.
  ///
  /// Not used for now???
  bool get isLuaWzImage => name.endsWith('.lua');

  //endregion

  //region Fields (override)

  @override
  WzObjectType get objectType {
    if (_reader != null && !parsed) {
      ParseImage();
    }
    return WzObjectType.Image;
  }

  @override
  WzFile? get wzFileParent => parent?.wzFileParent;

  //endregion

  //region Constructor
  WzImage(String name, [this._reader, this.checksum = 0]) : super(name) {
    if (_reader != null) {
      blockStart = _reader!.position;
    } else {
      // if reader not provided, that means this WzImage is new created and could be saved with changes later.
      changed = true;
    }
  }

  //endregion

  //region Methods

  /// Get Property from specific path.
  ///
  /// Return null if not found.
  WzImageProperty? GetFromPath(String path) {
    var segments = path.characters.split('/'.characters).toList();
    if (segments[0] == '..'.characters) {
      return null;
    }

    WzImageProperty? ret;
    for (var x = 0; x < segments.length; x++) {
      var foundChild = false;

      // TODO: if somethin wrong here, check C# version
      for (var iwp in (ret == null
          ? wzProperties
          : (ret as PropertyContainer).wzProperties)) {
        if (iwp.name.characters == segments[x]) {
          ret = iwp;
          foundChild = true;
          break;
        }
      }
      if (!foundChild) {
        return null;
      }
    }
    return ret;
  }

  /// Calculates and set the image header checksum
  void CalculateAndSetImageChecksum(Uint8List bytes) {
    checksum = 0;
    for (var b in bytes) {
      checksum += b;
    }
  }

  /// Parses the image from the wz filetod
  ///
  /// Returns bool Parse status
  bool ParseImage([bool forceReadFromData = false]) {
    if (!forceReadFromData) {
      // only check if parsed or changed if its not false read
      if (parsed) {
        return true;
      } else if (changed) {
        parsed = true;
        return true;
      }
    }

    // var originalPos = reader.position;
    reader.position = offset;

    var b = reader.ReadByte();
    switch (b) {
      case 0x1: // .lua
        {
          if (isLuaWzImage) {
            var lua = WzImageProperty.ParseLuaProperty(offset, reader, this, this);
            _properties.add(lua);
            parsed = true; // test
            return true;
          }
          return false; // unhandled for now, if it isnt an .lua image
        }
      case 0x73: // WzImageHeaderByte
        {
          var prop = reader.ReadString();
          var val = reader.ReadUInt16();
          if (prop != 'Property' || val != 0) {
            return false;
          }
          break;
        }
      default:
        {
          // todo: log this or warn.
          // log('[WzImage] New Wz image header found. b = $b', time: DateTime.now());
          // Helpers.ErrorLogger.Log(Helpers.ErrorLevel.MissingFeature, "[WzImage] New Wz image header found. b = " + b);
          return false;
        }
    }
    var images = WzImageProperty.ParsePropertyList(offset, reader, this, this);
    _properties.addAll(images);

    parsed = true;

    return true;
  }

  void UnparseImage() {
    parsed = false;
    _properties.clear();
  }

  /// Writes the WzImage object to the underlying WzBinaryWriter
  ///
  /// [bIsWzUserKeyDefault] Uses the default MapleStory UserKey or a custom key.
  /// [forceReadFromData] Read from data regardless of base data that's changed or not.
  void SaveImage(WzBinaryWriter writer,
      [bool bIsWzUserKeyDefault = true, bool forceReadFromData = false]) {
    if (changed ||
        !bIsWzUserKeyDefault || //  everything needs to be re-written when a custom UserKey is used
        forceReadFromData) // if its not being force-read and written, it saves with the previous WZ encryption IV.
    {
      if (_reader != null && !parsed) {
        parseEverything = true;
        ParseImage(forceReadFromData);
      }

      var startPos = writer.position;

      // Create a temporary WzSubProperty for writing all properties.
      WzSubProperty()
        ..AddProperties(wzProperties)
        ..writeValue(writer);

      writer.StringCache.clear();

      blockSize = writer.position - startPos;
    } else {
      var pos = reader.position;
      reader.position = offset;
      writer.WriteBytes(reader.ReadBytes(blockSize));
      reader.position = pos;
    }
  }

  WzImage deepClone() {
    throw UnimplementedError('not used so far.');
  }

  //endregion

  //region Methods (override)

  @override
  void dispose() {
    for (var prop in _properties) {
      prop.dispose();
    }
    _properties.clear();
  }

  @override
  void remove() {
    // TODO: why not '?.'  ???
    // what happen if parent == null ???
    (parent as WzDirectory).RemoveImage(this);
  }

  @override
  String toString() {
    return name;
  }

//endregion
}
