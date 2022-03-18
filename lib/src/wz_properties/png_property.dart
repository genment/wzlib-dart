import 'dart:typed_data';

import 'package:archive/archive.dart';

import '../wz_types.dart';
import '../wz_object.dart';
import '../util/wz_binary_reader.dart';
import '../util/wz_binary_writer.dart';
import 'base_property.dart';

class WzPngProperty extends WzImageProperty {
  int width = 0, height = 0;
  int format1 = 0, format2 = 0;

  Uint8List? compressedImageBytes;
  late Bitmap? png;

  // Whether a png is a List.wz property (mostly not).
  // A List.wz property is compressed but not encrypted,
  // while a normal (non-List.wz) property is compressed and encrypted.
  bool listWzUsed = false;

  WzBinaryReader? _reader;

  WzBinaryReader get wzReader => _reader!;
  int _offs = 0;

  @override
  set name(String _name) {} // not allowed

  @override
  Object get wzValue => getImage();

  @override
  set wzValue(Object value) {} // not allowed

  @override
  WzPropertyType get propertyType => WzPropertyType.PNG;

  int get format => format1 + format2;

  set format(int format) {
    format1 = format;
    format2 = 0;
  }

  Bitmap getImage([bool saveInMemory = false]) {
    return png ?? ParsePng(saveInMemory);
  }

  void setImage(Bitmap png) {
    this.png = png;
    CompressPng(png);
  }

  /// TODO: 这个方法在 c# 版本中是继承自 WzImageProperty 的，基本上每个子类都有重写，但是我直接去掉这个方法了
  @deprecated
  void setValue(Object value) {
    if (value is Bitmap) {
      setImage(value);
    } else {
      compressedImageBytes = value as Uint8List; // 能这样吗？好像不安全吧？？？
    }
  }

  WzPngProperty([WzBinaryReader? reader, bool parseNow = false, WzObject? parent]) : super('PNG', null, parent) {
    if (reader == null) return;

    width = reader.readCompressedInt();
    height = reader.readCompressedInt();
    format1 = reader.readCompressedInt();
    format2 = reader.ReadByte();
    reader.position += 4;
    _offs = reader.position;  // 将位置保存下来，如果 parseNow == false，那么以后解析的时候，就从这里开始读取
    var len = reader.ReadInt32() - 1;
    reader.position += 1;

    if (len > 0) {
      if (parseNow) {
        compressedImageBytes = reader.ReadBytes(len);
        // ParsePng(true);
      }
      _reader = reader;
    }
  }

  //region Parsing Methods

  /// 将 wz 数据解析成 png (Bitmap) 图像，相反的过程是[CompressPng]
  Bitmap ParsePng(    bool saveInMemory  ) {
    // var rawBytes = _GetRawImage(saveInMemory);
    throw UnimplementedError('TODO: implement PngProperty.ParsePng()');
  }

  /// 将 png (Bitmap) 图像解析成 wz 数据，相反的过程是[ParsePng]
  void CompressPng(Bitmap bmp) {
    throw UnimplementedError('TODO: implement PngProperty.CompressPng()');
  }

  Uint8List? GetCompressedBytes(bool saveInMemory) {
    if (compressedImageBytes == null) {
      var pos = wzReader.position;
      wzReader.position = _offs;
      var len = wzReader.ReadInt32() - 1;
      if (len <= 0) {
        // possibility an image written with the wrong wzIv
        throw Exception('The length of the image is negative. WzPngProperty. Wrong WzIV?');
      }
      wzReader.position += 1;

      if (len > 0) {
        compressedImageBytes = wzReader.ReadBytes(len);
      }
      wzReader.position = pos;
    }

    if (!saveInMemory) {
      // were removing the reference to compressedBytes, so a backup for the ret value is needed
      var returnBytes = compressedImageBytes;
      compressedImageBytes = null;
      return returnBytes;
    }
    return compressedImageBytes;
  }

  /// 目前没有被使用，但是应该是会被 [ParsePng] 调用的？？？
  Uint8List _Decompress(Uint8List compressedBuffer, int decompressedSize) {
    return ZLibDecoder().decodeBuffer(InputStream(compressedBuffer)..skip(2))
        as Uint8List;
  }

  /// 目前被 [CompressPng] 调用，使用 zip deflate 算法压缩 png（Bitmap）数据。
  /// 并在前面插入 0x78 0x9C 两个字节，最终数据存放在 [compressedImageBytes].
  Uint8List _Compress(Uint8List decompressedBuffer) {
    return ZLibEncoder().encode(decompressedBuffer,
        output: OutputStream()..writeBytes([0x78, 0x9C])) as Uint8List;
  }

  Uint8List _GetRawImage(bool saveInMemory) {
    var rawImageBytes = GetCompressedBytes(saveInMemory);
    
    // var uncompressedSize = 0;

    // switch (format) {
    //   case 0x01:
    //     uncompressedSize = width * height * 2; break;
    //   case 0x02:
    //     uncompressedSize = width * height * 4; break;
    //   case 0x03:
    //     uncompressedSize = width * height * 4; break;
    //   case 0x101:
    //     uncompressedSize = width * height * 2; break; 
    //   case 0x201:
    //     uncompressedSize = width * height * 2; break;
    //   case 0x205:
    //     uncompressedSize = width * height ~/ 128; break;
    //   case 0x402:
    //     uncompressedSize = width * height * 4; break;
    //   case 0x802:
    //     uncompressedSize = width * height; break;
    //   default:
    //     throw UnsupportedError('Unsupported format: $format, path: $fullPath');
    // }

    var input = InputStream(rawImageBytes);
    var header = input.readUint16();
    listWzUsed = header != 0x9C78 && header != 0xDA78 && header != 0x0178 && header != 0x5E78;

    if (listWzUsed) {
      throw UnsupportedError('Unsupported listWzUsed header: $header');
    }

    var decompressed = ZLibDecoder().decodeBuffer(input) as Uint8List;
    input.close();
    return decompressed;
  }

  //region Decoders
  // TODO: Decoders Code Region: not implemented
  //endregion

  //endregion

  @override
  void writeValue(WzBinaryWriter writer) {
    throw UnsupportedError('Cannot write a PngProperty');
  }

  @override
  WzObject? operator [](String name) {
    throw UnsupportedError('Invalid operation: PngProperty not supported');
  }

  @override
  WzPngProperty deepClone() {
    return WzPngProperty()..setImage(getImage(false));
  }

  @override
  void dispose() {
    // todo: check if png nullable
    // compressedImageBytes.clear();
    png?.dispose();
  }
}

// TODO: this is a fake Bitmap class.
class Bitmap {
  void dispose() {}
}
