part of wzlib;

///////////////////////////////////////////////////////////
///                 WzExtendedProperty                  ///
///////////////////////////////////////////////////////////

abstract class WzExtended extends WzImageProperty {
  WzExtended(String name, [Object? value, WzObject? parent])
      : super(name, parent);

  @override
  WzObject? operator [](String name) => null; // not available
}

class WzSoundProperty extends WzExtended {
  Uint8List? header;
  Uint8List? mp3bytes;

  // bool _headerEncrypted = false;
  int sound_length_ms = 0; // audio length in milliseconds
  int _soundDataLen = 0;
  int _offs = 0;

  // WzBinaryReader? _reader;
  WzBinaryReader wzReader;

  // Object wavFormat; // todo: [WaveFormat] not implemented

  static var soundHeader = Uint8List.fromList([
    0x02, // This comment does nothing but disables formatting.
    0x83, 0xEB, 0x36, 0xE4, 0x4F, 0x52, 0xCE, 0x11, 0x9F, 0x53, 0x00, 0x20,
    0xAF, 0x0B, 0xA7, 0x70,
    0x8B, 0xEB, 0x36, 0xE4, 0x4F, 0x52, 0xCE, 0x11, 0x9F, 0x53, 0x00, 0x20,
    0xAF, 0x0B, 0xA7, 0x70,
    0x00,
    0x01,
    0x81, 0x9F, 0x58, 0x05, 0x56, 0xC3, 0xCE, 0x11, 0xBF, 0x01, 0x00, 0xAA,
    0x00, 0x55, 0x59, 0x5A
  ]);

  @override
  WzPropertyType get propertyType => WzPropertyType.Sound;

  @override
  Object get wzValue => GetBytes(false)!; // todo: Dangerous! GetBytes() may return null

  @override
  set wzValue(Object value) => {}; // not allowed

  WzSoundProperty(String name, this.wzReader,
      [bool parseNow = false, WzObject? parent])
      : super(name, null, parent) {
    wzReader.position++;

    //note - soundDataLen does NOT include the length of the header.
    _soundDataLen = wzReader.readCompressedInt();
    sound_length_ms = wzReader.readCompressedInt();

    var headerOff = wzReader.position;
    wzReader.position += soundHeader.length; //skip GUIDs
    var wavFormatLen = wzReader.ReadByte();
    wzReader.position = headerOff;

    header = wzReader.ReadBytes(soundHeader.length + 1 + wavFormatLen);
    // _ParseWzSoundPropertyHeader(); // TODO: no need to parse so far

    //sound file offs
    _offs = wzReader.position;
    if (parseNow) {
      mp3bytes = wzReader.ReadBytes(_soundDataLen);
    } else {
      wzReader.position += _soundDataLen;
    }
  }

  /// Convert bytes to WaveFormat structure. ( C/C++ struct )
  static T _BytesToStruct<T>(Uint8List data) {
    throw UnimplementedError('not supported');
  }

  /// Parse raw (header) data to standard mp3 or other audio formats header
  void _ParseWzSoundPropertyHeader() {
    throw UnimplementedError('not supported so far');
  }

  Uint8List? GetBytes([bool saveInMemory = false]) {
    if (mp3bytes != null) {
      return mp3bytes;
    } else {
      // if (_reader == null) {
      //   return null;
      // }

      var currentPos = wzReader.position;
      wzReader.position = _offs;
      mp3bytes = wzReader.ReadBytes(_soundDataLen);
      wzReader.position = currentPos;
      if (saveInMemory) {
        return mp3bytes;
      } else {
        var result = mp3bytes;
        mp3bytes = null;
        return result;
      }
    }
  }

  @override
  void writeValue(WzBinaryWriter writer) {
    var data = GetBytes(false);
    if (data == null) {
      throw ArgumentError.notNull('Can not write null'); // todo: I added
    }
    writer.WriteStringValue('Sound_DX8', 0x73, 0x1B);
    writer.WriteByte(0);
    writer.WriteCompressedInt(data.length);
    writer.WriteCompressedInt(sound_length_ms);
    writer.WriteBytes(header!);
    writer.WriteBytes(data);
  }

  @override
  WzSoundProperty deepClone() {
    // TODO: implement WzSoundProperty.deepClone()
    throw UnimplementedError('Not supported so far');
  }

  @override
  void dispose() {
    // nothing to dispose
  }
}

class WzUOLProperty extends WzExtended {
  String uol = '';
  WzObject? _linkedTarget;

  @override
  Object get wzValue => _linkedTarget!;

  @override
  set wzValue(Object object) => throw UnimplementedError('no supported');

  @override
  WzPropertyType get propertyType => WzPropertyType.UOL;

  WzUOLProperty(String name, [this.uol = '', WzObject? parent])
      : super(name, parent);

//region Resolve UOL

  /// This is not override!
  List<WzImageProperty>? get wzProperties {
    if (_linkedTarget != null && _linkedTarget is PropertyContainer) {
      // What if linkValue is WzImage? Is it possible?
      return (_linkedTarget as PropertyContainer).wzProperties;
    }
    return null;
  }

  @override
  WzImageProperty? operator [](String name) {
    if (_linkedTarget != null && _linkedTarget is PropertyContainer) {
      // It can be WzImage. That's OK.
      return (_linkedTarget as PropertyContainer)[name];
    }
    return null;
  }

  // @override
  WzImageProperty? GetFromPath(String path) {
    if (_linkedTarget != null) {
      // It can be WzImage. That's OK.
      if (_linkedTarget is PropertyContainer) {
        return (_linkedTarget as PropertyContainer).GetFromPath(path);
      }
      if (_linkedTarget is WzUOLProperty) {
        return (_linkedTarget as WzUOLProperty).GetFromPath(path);
      }
    }
    return null;
  }

  WzObject? get linkedProperty {
    if (_linkedTarget != null) {
      return _linkedTarget;
    }

    var paths = uol.split('/');
    _linkedTarget = parent;
    for (var path in paths) {
      if (path == '..') {
        _linkedTarget = _linkedTarget?.parent;
      } else {
        switch (_linkedTarget.runtimeType) {
          case WzImageProperty:
            _linkedTarget = (_linkedTarget as WzImageProperty)[path];
            break;
          case WzImage:
            _linkedTarget = (_linkedTarget as WzImage)[path];
            break;
          case WzDirectory:
            _linkedTarget = (_linkedTarget as WzDirectory)[
                (path.endsWith('.img')) ? (path) : (path + '.img')];
            break;
          default:
            return null;
        }
      }
    }
    return _linkedTarget;
  }

//endregion

  @override
  WzImageProperty deepClone() {
    return WzUOLProperty(name, uol);
  }

  @override
  void writeValue(WzBinaryWriter writer) {
    writer.WriteStringValue('UOL', 0x73, 0x1B);
    writer.WriteByte(0);
    writer.WriteStringValue(uol, 0, 1);
  }

  @override
  void dispose() {
    _linkedTarget = null;
  }
}

class WzVectorProperty extends WzExtended {
  WzIntProperty x = WzIntProperty('X');
  WzIntProperty y = WzIntProperty('Y');

  Point get point => Point(x.value, y.value);
  set point(Point p) {
    x.value = p.x;
    y.value = p.y;
  }

  @override
  Point get wzValue => point;

  @override
  set wzValue(Object object) {
    if (object is Point) {
      x.value = object.x;
      y.value = object.y;
    } else {
      throw ArgumentError.value(object);
    }
  }

  @override
  WzPropertyType get propertyType => WzPropertyType.Vector;

  WzVectorProperty(String name,
      [WzIntProperty? x, WzIntProperty? y, WzObject? parent])
      : super(name, parent) {
    if (x != null) {
      this.x
        ..value = x.value
        ..parent = this;
    }
    if (y != null) {
      this.y
        ..value = y.value
        ..parent = this;
    }
  }

  @override
  void writeValue(WzBinaryWriter writer) {
    writer.WriteStringValue('Shape2D#Vector2D', 0x73, 0x1B);
    writer.WriteCompressedInt(x.value.toInt());
    writer.WriteCompressedInt(y.value.toInt());
  }

  @override
  WzVectorProperty deepClone() {
    return WzVectorProperty(name, x, y);
  }

  @override
  void dispose() {
    // x.dispose(); // not necessary
    // y.dispose();
  }

  @override
  String toString() {
    return point.toString();
  }
}

///////////////////////////////////////////////////////////
///                  PropertyContainer                  ///
///////////////////////////////////////////////////////////

mixin PropertyContainer on WzObject {
  final List<WzImageProperty> _properties = [];

  // @override
  Object get wzValue => throw UnimplementedError('PropertyContainer');

  // @override
  set wzValue(Object value) => throw UnimplementedError('PropertyContainer');

  List<WzImageProperty> get wzProperties => _properties;

  // PropertyContainer(String name, [Object? value, WzObject? parent]) : super(name, parent);

  WzImageProperty? GetFromPath(String path);

  // @override
  WzImageProperty? operator [](String name) {
    for (var iwp in wzProperties) {
      if (iwp.name.toLowerCase() == name.toLowerCase()) {
        return iwp;
      }
    }
    return null;
  }

  void operator []=(String name, WzImageProperty prop) {
    prop.name = name;
    AddProperty(prop);
  }

  void AddProperty(WzImageProperty prop) {
    prop.parent = this as WzObject?; // TODO: ?????
    _properties.add(prop);
  }

  void AddProperties(List<WzImageProperty> props) {
    for (var p in props) {
      AddProperty(p);
    }
  }

  void RemoveProperty(WzImageProperty prop) {
    prop.parent = null;
    _properties.remove(prop);
  }

  void ClearProperties() {
    for (var p in _properties) {
      p.parent = null;
    }
    _properties.clear();
  }
}

class WzCanvasProperty extends WzExtended with PropertyContainer {
  static const String InlinkPropertyName = '_inlink';
  static const String OutlinkPropertyName = '_outlink';
  static const String OriginPropertyName = 'origin';
  static const String HeadPropertyName = 'head';
  static const String LtPropertyName = 'lt';
  static const String AnimationDelayPropertyName = 'delay';

  WzPngProperty? pngProperty;

  @override
  WzPropertyType get propertyType => WzPropertyType.Canvas;

  WzCanvasProperty([String name = '', WzObject? parent]) : super(name, parent);

  /// Gets the '_inlink' WzCanvasProperty of this.
  ///
  /// '_inlink' is not implemented as part of WzCanvasProperty as I dont want to override existing Wz structure.
  /// It will be handled via HaRepackerMainPanel instead.
  Bitmap GetLinkedWzCanvasBitmap() {
    // todo: 检查是否所有 inlink 或 outlink 的都是 CanvasProperty, 如果是的话，那么就直接强制转换为 canvas
    return (GetLinkedWzImageProperty() as WzCanvasProperty).GetBitmap();
  }

  /// Gets the '_inlink' WzCanvasProperty of this.
  ///
  /// '_inlink' is not implemented as part of WzCanvasProperty as I dont want to override existing Wz structure.
  /// It will be handled via HaRepackerMainPanel instead.
  @override
  WzImageProperty GetLinkedWzImageProperty() {
    // could get nexon'd here. In case they place an _inlink or _outlink that's not WzStringProperty
    var _inlink = (this[InlinkPropertyName] as WzStringProperty).value;
    var _outlink = (this[OutlinkPropertyName] as WzStringProperty).value;

    if (_inlink.isNotEmpty) {
      WzObject? currentWzObj = this; // first object to work with
      while ((currentWzObj = currentWzObj?.parent) != null) {
        if (!(currentWzObj is WzImage)) {
          // keep looping if its not a WzImage
          continue;
        }
        var foundProperty = currentWzObj.GetFromPath(_inlink);
        if (foundProperty != null) {
          return foundProperty;
        }
      }
    } else if (_outlink.isNotEmpty) {
      WzObject? currentWzObj = this; // first object to work with
      while ((currentWzObj = currentWzObj?.parent) != null) {
        if (!(currentWzObj is WzDirectory)) {
          // keep looping if its not a WzImage
          continue;
        }
        var wzFileParent = currentWzObj.wzFile;

        // TODO
        // Given the way it is structured, it might possibility also point to a different WZ file (i.e NPC.wz instead of Mob.wz).
        // Mob001.wz/8800103.img/8800103.png has an outlink to "Mob/8800141.img/8800141.png"
        // https://github.com/lastbattle/Harepacker-resurrected/pull/142

        // TODO: 这里写死了 wz 后缀的文件名，如果汉化需要的话，必须改成 bin 或者 (wz|bin) 或者 *
        var prefixWz = RegExp('^([A-Za-z]+)([0-9]*).wz')
            .firstMatch(wzFileParent.name)
            ?.group(1);
        prefixWz = prefixWz.toString() + '/'; // remove ended numbers and .wz from wzfile name

        WzObject? foundProperty;

        if (_outlink.startsWith(prefixWz)) {
          // fixed root path
          var realPath = _outlink.replaceAll(prefixWz, wzFileParent.name.replaceAll('.wz', '') + '/');
          foundProperty = null; // todo: wzFileParent.GetObjectFromPath(realPath);
        } else {
          foundProperty = null; // todo: wzFileParent.GetObjectFromPath(_outlink);
        }
        if (foundProperty != null && foundProperty is WzImageProperty) {
          return foundProperty;
        }
      }
    }
    return this;
  }

  @override
  WzImageProperty? GetFromPath(String path) {
    // TODO: implement GetFromPath
    throw UnimplementedError('need to implement WzCanvasProperty.GetFromPath()');
  }

  @override
  WzImageProperty? operator [](String name) {
    if (name == 'PNG') {
      return pngProperty;
    }
    return super[name];
  }

  @override
  void operator []=(String name, WzImageProperty prop) {
    if (name == 'PNG' && prop is WzPngProperty) {
      pngProperty = prop;
      return;
    }
    super[name] = prop;
  }

  @override
  WzCanvasProperty deepClone() {
    var clone = WzCanvasProperty(name);
    for (var prop in _properties) {
      clone.AddProperty(prop.deepClone());
    }
    clone.pngProperty = pngProperty?.deepClone();
    return clone;
  }

  @override
  void writeValue(WzBinaryWriter writer) {
    writer.WriteStringValue('Canvas', 0x73, 0x1B);
    writer.WriteByte(0);
    if (_properties.isNotEmpty) {
      // sub-property in the canvas
      writer.WriteByte(1);
      WzImageProperty.writePropertyList(writer, _properties);
    } else {
      writer.WriteByte(0);
    }

    // Image info
    writer.WriteCompressedInt(pngProperty!.width);
    writer.WriteCompressedInt(pngProperty!.height);
    writer.WriteCompressedInt(pngProperty!.format);
    writer.WriteByte(pngProperty!.format2);
    writer.WriteInt32(0);

    // Write image
    var bytes = pngProperty!.GetCompressedBytes(false)!;
    writer.WriteInt32(bytes.length + 1);
    writer.WriteByte(0); // header? see WzImageProperty.ParseExtendedProp "0x00"
    writer.WriteBytes(bytes);
  }

  Bitmap GetBitmap() {
    return pngProperty!.getImage(); // ?? throw UnimplementedError('not implemented'); // todo
  }

  @override
  void dispose() {
    parent = null; // TODO: 只是写在这里的一个提示： 所有 property 应该在 dispose 的时候将 parent = null
    pngProperty?.dispose();
    for (var p in _properties) {
      p.dispose();
    }
    ClearProperties();
  }
}

class WzConvexProperty extends WzExtended with PropertyContainer {
  @override
  WzPropertyType get propertyType => WzPropertyType.Convex;

  WzConvexProperty([String name = '', WzObject? parent]) : super(name, parent);

  @override
  WzImageProperty? GetFromPath(String path) {
    // TODO: implement GetFromPath
    return null;
  }

  @override
  WzConvexProperty deepClone() {
    var clone = WzConvexProperty(name);
    for (var prop in _properties) {
      clone.AddProperty(prop.deepClone());
    }
    return clone;
  }

  /// Special case: [prop] must be a subclass of Extended.
  ///
  /// Why??? See [WzImageProperty#ParsePropertyList] case #9.
  @override
  void AddProperty(WzImageProperty prop) {
    if (!(prop is WzExtended)) {
      throw ArgumentError('Property is not a subclass of ExtendedProperty');
    }
    super.AddProperty(prop);
  }

  @override
  void dispose() {
    for (var exProp in _properties) {
      exProp.dispose();
    }
    ClearProperties();
  }

  @override
  void writeValue(WzBinaryWriter writer) {
    var extendedProps = <WzExtended>[];
    for (var prop in _properties) {
      if (prop is WzExtended) extendedProps.add(prop);
    }
    writer.WriteStringValue('Shape2D#Convex2D', 0x73, 0x1B);
    writer.WriteCompressedInt(extendedProps.length);

    for (var imgProperty in _properties) {
      imgProperty.writeValue(writer);
    }
  }
}

class WzSubProperty extends WzExtended with PropertyContainer {
  @override
  WzPropertyType get propertyType => WzPropertyType.SubProperty;

  WzSubProperty([String name = '', WzObject? parent]) : super(name, parent);

  @override
  WzSubProperty deepClone() {
    var clone = WzSubProperty(name);
    for (var prop in _properties) {
      clone.AddProperty(prop.deepClone());
    }
    return clone;
  }

  @override
  void dispose() {
    for (var prop in _properties) {
      prop.parent = null; // todo: I added this line.
      prop.dispose();
    }
    _properties.clear();
  }

  /// Gets a wz property by a path name
  /// [path] path to property</param>
  /// <returns>the wz property with the specified name</returns>
  @override
  WzImageProperty? GetFromPath(String path) {
    // todo: find if some other class has the same implementation.
    // wz_image is slightly different.
    var segments = path.characters.split('/'.characters).toList();
    if (segments[0] == '..'.characters) {
      return (parent as WzImageProperty)[path.substring(name.indexOf('/') + 1)]
          as WzImageProperty;
    }

    WzImageProperty ret = this;
    for (var x in segments) {
      var foundChild = false;

      for (var iwp in (ret as PropertyContainer).wzProperties) {
        if (iwp.name.characters == x) {
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

  @override
  void writeValue(WzBinaryWriter writer) {
    var bIsLuaProperty = _properties.length == 1 && _properties[0] is WzLuaProperty;
    if (!bIsLuaProperty) {
      writer.WriteStringValue('Property', 0x73, 0x1B);
    }
    WzImageProperty.writePropertyList(writer, _properties);
  }
}
