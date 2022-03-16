import '../wz_types.dart';
import '../wz_object.dart';
import '../wz_file.dart';
import '../wz_image.dart';
import '../util/wz_binary_reader.dart';
import '../util/wz_binary_writer.dart';

import 'simple_property.dart';
import 'extended_property.dart';
import 'png_property.dart';
import 'lua_property.dart';

/// [WzImageProperty] represents a data structure that stores inside an *.img Image.
///
/// Three Types of Image Property:
/// (1) [WzSimpleProperty]s are:
/// [WzShortProperty], [WzIntProperty], [WzLongProperty],
/// [WzFloatProperty], [WzDoubleProperty], [WzStringProperty]
/// and [WzNullProperty].
///
/// (2) [WzExtendedProperty]s are:
/// [WzSoundProperty], [WzCanvasProperty], [WzConvexProperty],
/// [WzSubProperty], [WzUOLProperty] and [WzVectorProperty],
///
/// and three ([WzCanvasProperty], [WzConvexProperty] and [WzSubProperty])
/// of which are also [PropertyContainer].
///
/// Both [WzExtendedProperty] and [PropertyContainer] can hold other properties.
///
/// (3) Others are:
/// [WzPngProperty] and [WzLuaProperty]
abstract class WzImageProperty extends WzObject {
  //region Fields

  WzPropertyType get propertyType;

  // todo: 这个是不是不应该在这里，因为container里也有这个。
  // 而且写这里会导致所有其他int、string 之类的property也有，这不太合适吧？
  // 但是sub.getfrompath又好像需要？？？
  // List<WzImageProperty> get wzProperties;

  /// TODO: wzValue 真的需要吗？？？？
  /// Get the holding value of this property
  /// All subclass *SHOULD* override this.
  Object get wzValue;

  set wzValue(Object value);

  WzImage? get parentImage {
    var p = parent;
    while (p != null) {
      if (p is WzImage) {
        return p;
      } else {
        p = p.parent;
      }
    }
    return null;
  }

  //endregion

  //region Fields (override)

  @override
  WzObjectType get objectType => WzObjectType.Property;

  @override
  WzFile? get wzFileParent => parentImage!.wzFileParent;

  //endregion

  //region Constructor
  WzImageProperty(String name, [Object? value, WzObject? parent]) : super(name, parent);

  //endregion

  //region Methods

  /// 以下class有定义/重载
  /// WzImage -> 在 Canvas 的 GetLinkedWzImageProperty 使用
  /// ImageProperty -> Canvas, Convex, Sub,    UOL
  ///                 (Property Containers) (Extended)
  /// 作为 extension 方法？还是作为 mixin？？试试看？？？
  // WzImageProperty? GetFromPath(String path) => null;

  void writeValue(WzBinaryWriter writer);

  WzImageProperty deepClone();

  @override
  void remove() => (parent as PropertyContainer).RemoveProperty(this);

  //#region Extended Properties Parsing

  static void writePropertyList(WzBinaryWriter writer, List<WzImageProperty> props) {
    if (props.length == 1 && props[0] is WzLuaProperty) {
      props[0].writeValue(writer);
    } else {
      writer.WriteUint16(0);
      writer.WriteCompressedInt(props.length);
      for (var imgProperty in props) {
        writer.WriteStringValue(imgProperty.name, 0x00, 0x01);
        if (imgProperty is WzExtended) {
          _WriteExtendedValue(writer, imgProperty);
        } else {
          imgProperty.writeValue(writer);
        }
      }
    }
  }

  /// <summary>
  /// Parses .lua property
  /// </summary>
  static WzLuaProperty ParseLuaProperty(int offset, WzBinaryReader reader, WzObject parent, WzImage parentImg) {
    // 28 71 4F EF 1B 65 F9 1F A7 48 8D 11 73 E7 F0 27 55 09 DD 3C 07 32 D7 38 21 57 84 70 C1 79 9A 3F 49 F7 79 03 41 F4 9D B9 1B 5F CF 26 80 3D EC 25 5F 9C
    // [compressed int] [bytes]
    var length = reader.readCompressedInt();
    var rawEncBytes = reader.ReadBytes(length);

    return WzLuaProperty('Script', rawEncBytes, parent);
  }

  static List<WzImageProperty> ParsePropertyList(
      int offset, WzBinaryReader reader, WzObject parent, WzImage parentImg) {
    var entryCount = reader.readCompressedInt();
    var properties = <WzImageProperty>[];
    // properties.length = entryCount; // not allowed due to null-safety!!!
    for (var i = 0; i < entryCount; i++) {
      var name = reader.ReadStringBlock(offset);
      var ptype = reader.ReadByte();
      print('name = $name, ptype = $ptype');
      switch (ptype) // header value
          {
        case 0:
          properties.add(WzNullProperty(name, parent));
          break;
        case 11:
        case 2:
          properties.add(WzShortProperty(name, reader.ReadInt16(), parent));
          break;
        case 3:
        case 19:
          properties.add(WzIntProperty(name, reader.readCompressedInt(), parent));
          break;
        case 20:
          properties.add(WzLongProperty(name, reader.ReadLong(), parent));
          break;
        case 4:
          var type = reader.ReadByte();
          if (type == 0x80) {
            properties.add(WzFloatProperty(name, reader.ReadSingle(), parent));
          } else if (type == 0) {
            properties.add(WzFloatProperty(name, .0, parent));
          }
          break;
        case 5:
          properties.add(WzDoubleProperty(name, reader.ReadDouble(), parent));
          break;
        case 8:
          properties.add(WzStringProperty(name, reader.ReadStringBlock(offset), parent));
          break;
        case 9:
          var eob = reader.ReadUInt32() + reader.position;
          WzImageProperty exProp = _ParseExtendedProp(reader, offset, eob, name, parent, parentImg);
          properties.add(exProp);
          if (reader.position != eob) {
            reader.position = eob;
          }
          break;
        default:
          throw Exception('Unknown property type at ParsePropertyList, ptype = $ptype');
      }
    }
    return properties;
  }

  static WzExtended _ParseExtendedProp(
      WzBinaryReader reader, int offset, int endOfBlock, String name, WzObject parent, WzImage imgParent) {
    switch (reader.ReadByte()) {
      case 0x01:
      case 0x1B:
        return ExtractMore(reader, offset, endOfBlock, name, reader.ReadStringAtOffset(offset + reader.ReadInt32()),
            parent, imgParent);
      case 0x00:
      case 0x73:
        return ExtractMore(reader, offset, endOfBlock, name, '', parent, imgParent);
      default:
        throw Exception('Invalid byte read at ParseExtendedProp');
    }
  }

  static WzExtended ExtractMore(
      WzBinaryReader reader, int offset, int eob, String name, String iname, WzObject parent, WzImage imgParent) {
    if (iname == '') {
      iname = reader.ReadString();
    }
    switch (iname) {
      case 'Property':
        var subProp = WzSubProperty(name, parent);
        reader.position += 2; // Reserved?
        subProp.AddProperties(WzImageProperty.ParsePropertyList(offset, reader, subProp, imgParent));
        return subProp;
      case 'Canvas':
        var canvasProp = WzCanvasProperty(name, parent);
        reader.position++;
        if (reader.ReadByte() == 1) {
          reader.position += 2;
          canvasProp.AddProperties(WzImageProperty.ParsePropertyList(offset, reader, canvasProp, imgParent));
        }
        canvasProp.pngProperty = WzPngProperty(reader, imgParent.parseEverything, canvasProp);
        return canvasProp;
      case 'Shape2D#Vector2D':
        return WzVectorProperty(name)
          ..parent = parent
          ..x = WzIntProperty('X', reader.readCompressedInt())
          ..y = WzIntProperty('Y', reader.readCompressedInt());
      case 'Shape2D#Convex2D':
        var convexProp = WzConvexProperty(name, parent);
        var convexEntryCount = reader.readCompressedInt();
        // convexProp.wzProperties.length = convexEntryCount;  // not allowed due to null-safety!!!
        for (var i = 0; i < convexEntryCount; i++) {
          convexProp.AddProperty(_ParseExtendedProp(reader, offset, 0, name, convexProp, imgParent));
        }
        return convexProp;
      case 'Sound_DX8':
        var soundProp = WzSoundProperty(name, reader, imgParent.parseEverything, parent);
        return soundProp;
      case 'UOL':
        reader.position++;
        switch (reader.ReadByte()) {
          case 0:
            return WzUOLProperty(name, reader.ReadString(), parent);
          case 1:
            return WzUOLProperty(name, reader.ReadStringAtOffset(offset + reader.ReadInt32()), parent);
        }
        throw Exception('Unsupported UOL type');
      default:
        throw Exception('Unknown iname: $iname');
    }
  }

  static void _WriteExtendedValue(WzBinaryWriter writer, WzExtended property) {
    writer.WriteByte(9);

    var beforePos = writer.position;
    writer.WriteInt32(0); // Placeholder
    property.writeValue(writer);

    var len = writer.position - beforePos;
    var newPos = writer.position;
    writer.position = beforePos;
    writer.WriteInt32(len - 4);
    writer.position = newPos;
  }

  static void WriteExtendedValue(WzBinaryWriter writer, WzExtended property) {
    writer.WriteByte(9);

    var beforePos = writer.position;
    writer.WriteInt32(0); // Placeholder
    property.writeValue(writer);

    var len = writer.position - beforePos;
    var newPos = writer.position;
    writer.position = beforePos;
    writer.WriteInt32(len - 4);
    writer.position = newPos;
  }

  //#endregion

  //#region Custom Members

  /// Gets the linked WzImageProperty via WzUOLProperty
  WzImageProperty GetLinkedWzImageProperty() {
    // throw UnimplementedError('not available'); // todo:
    var thisWzImage = this;
    while ((thisWzImage is WzUOLProperty)) {
      var newWzImage = thisWzImage.linkedProperty;
      if (newWzImage is WzImageProperty) {
        thisWzImage = newWzImage;
      } else {
        // broken link
        return this;
      }
    }
    return thisWzImage;
  }

//#endregion
}
