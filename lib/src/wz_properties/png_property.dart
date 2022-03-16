import 'dart:typed_data';

import '../wz_types.dart';
import '../wz_object.dart';
import '../util/wz_binary_reader.dart';
import '../util/wz_binary_writer.dart';
import 'base_property.dart';

class WzPngProperty extends WzImageProperty {
  int width = 0, height = 0;
  int format1 = 0, format2 = 0;

  Uint8List? compressedImageBytes;
  Bitmap? png;

  // bool listWzUsed = false;  // todo: not sure what it is.

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
        ParsePng(true);
      }
      _reader = reader;
    }
  }

  //region Parsing Methods

  /// 将 wz 数据解析成 png (Bitmap) 图像，相反的过程是[CompressPng]
  Bitmap ParsePng(
    bool saveInMemory,
    /*[Texture2D? texture2d ]*/
  ) {
    throw UnimplementedError('TODO: implement PngProperty.ParsePng()');
    // byte[] rawBytes = _GetRawImage(saveInMemory);
    // if (rawBytes == null) {
    //   png = null;
    //   return;
    // }
    // try {
    //   Bitmap bmp = null;
    //   Rectangle rect_ = new Rectangle(0, 0, width, height);
    //
    //   switch (Format) {
    //     case 1:
    //       {
    //         bmp = new Bitmap(width, height, PixelFormat.Format32bppArgb);
    //         BitmapData bmpData = bmp.LockBits(rect_, ImageLockMode.WriteOnly, PixelFormat.Format32bppArgb);
    //
    //         DecompressImage_PixelDataBgra4444(rawBytes, width, height, bmp, bmpData);
    //         break;
    //       }
    //     case 2:
    //       {
    //         bmp = new Bitmap(width, height, PixelFormat.Format32bppArgb);
    //         BitmapData bmpData = bmp.LockBits(rect_, ImageLockMode.WriteOnly, PixelFormat.Format32bppArgb);
    //
    //         Marshal.Copy(rawBytes, 0, bmpData.Scan0, rawBytes.Length);
    //         bmp.UnlockBits(bmpData);
    //         break;
    //       }
    //     case 3:
    //       {
    //         // New format 黑白缩略图
    //         // thank you Elem8100, http://forum.ragezone.com/f702/wz-png-format-decode-code-1114978/
    //         // you'll be remembered forever <3
    //         bmp = new Bitmap(width, height, PixelFormat.Format32bppArgb);
    //         BitmapData bmpData = bmp.LockBits(rect_, ImageLockMode.WriteOnly, PixelFormat.Format32bppArgb);
    //
    //         DecompressImageDXT3(rawBytes, width, height, bmp, bmpData);
    //         break;
    //       }
    //     case 257: // http://forum.ragezone.com/f702/wz-png-format-decode-code-1114978/index2.html#post9053713
    //       {
    //         bmp = new Bitmap(width, height, PixelFormat.Format16bppArgb1555);
    //         BitmapData bmpData = bmp.LockBits(rect_, ImageLockMode.WriteOnly, PixelFormat.Format16bppArgb1555);
    //         // "Npc.wz\\2570101.img\\info\\illustration2\\face\\0"
    //
    //         CopyBmpDataWithStride(rawBytes, bmp.Width * 2, bmpData);
    //
    //         bmp.UnlockBits(bmpData);
    //         break;
    //       }
    //     case 513: // nexon wizet logo
    //       {
    //         bmp = new Bitmap(width, height, PixelFormat.Format16bppRgb565);
    //         BitmapData bmpData = bmp.LockBits(rect_, ImageLockMode.WriteOnly, PixelFormat.Format16bppRgb565);
    //
    //         Marshal.Copy(rawBytes, 0, bmpData.Scan0, rawBytes.Length);
    //         bmp.UnlockBits(bmpData);
    //         break;
    //       }
    //     case 517:
    //       {
    //         bmp = new Bitmap(width, height, PixelFormat.Format16bppRgb565);
    //         BitmapData bmpData = bmp.LockBits(rect_, ImageLockMode.WriteOnly, PixelFormat.Format16bppRgb565);
    //
    //         DecompressImage_PixelDataForm517(rawBytes, width, height, bmp, bmpData);
    //         break;
    //       }
    //     case 1026:
    //       {
    //         bmp = new Bitmap(this.width, this.height, PixelFormat.Format32bppArgb);
    //         BitmapData bmpData = bmp.LockBits(rect_, ImageLockMode.WriteOnly, PixelFormat.Format32bppArgb);
    //
    //         DecompressImageDXT3(rawBytes, this.width, this.height, bmp, bmpData);
    //         break;
    //       }
    //     case 2050: // new
    //       {
    //         bmp = new Bitmap(width, height, PixelFormat.Format32bppArgb);
    //         BitmapData bmpData = bmp.LockBits(rect_, ImageLockMode.WriteOnly, PixelFormat.Format32bppArgb);
    //
    //         DecompressImageDXT5(rawBytes, Width, Height, bmp, bmpData);
    //         break;
    //       }
    //     default:
    //       Helpers.ErrorLogger.Log(
    //           Helpers.ErrorLevel.MissingFeature, string.Format("Unknown PNG format {0} {1}", format, format2));
    //       break;
    //   }
    //   if (bmp != null) {
    //     if (texture2d != null) {
    //       Microsoft.Xna.Framework.Rectangle rect = new Microsoft.Xna.Framework.Rectangle(
    //           Microsoft.Xna.Framework.Point.Zero,
    //           new Microsoft.Xna.Framework.Point(width, height));
    //       texture2d.SetData(0, 0, rect, rawBytes, 0, rawBytes.Length);
    //     }
    //   }
    //
    //   png = bmp;
    // }
    // catch (InvalidDataException) {
    //   png = null;
    // }
  }

  /// 将 png (Bitmap) 图像解析成 wz 数据，相反的过程是[ParsePng]
  void CompressPng(Bitmap bmp) {
    throw UnimplementedError('TODO: implement PngProperty.CompressPng()');
    //   byte[] buf = new byte[bmp.Width * bmp.Height * 8];
    //   format = 2;
    //   format2 = 0;
    //   width = bmp.Width;
    //   height = bmp.Height;
    //
    //   int curPos = 0;
    //   for (int i = 0; i < height; i++) {
    //     for (int j = 0; j < width; j++) {
    //       Color curPixel = bmp.GetPixel(j, i);
    //       buf[curPos] = curPixel.B;
    //       buf[curPos + 1] = curPixel.G;
    //       buf[curPos + 2] = curPixel.R;
    //       buf[curPos + 3] = curPixel.A;
    //       curPos += 4;
    //     }
    //   }
    //   compressedImageBytes = Compress(buf);
    //
    //   buf = null;
    //
    //   if (listWzUsed) {
    //     using(MemoryStream memStream = new MemoryStream())
    //   {
    //   using (WzBinaryWriter writer = new WzBinaryWriter(memStream, WzTool.GetIvByMapleVersion(WzMapleVersion.GMS)))
    //   {
    //   writer.Write(2);
    //   for (int i = 0; i < 2; i++)
    //   {
    //   writer.Write((byte)(compressedImageBytes[i] ^ writer.WzKey[i]));
    //   }
    //   writer.Write(compressedImageBytes.Length - 2);
    //   for (int i = 2; i < compressedImageBytes.Length; i++)
    //   writer.Write((byte)(compressedImageBytes[i] ^ writer.WzKey[i - 2]));
    //   compressedImageBytes = memStream.GetBuffer();
    //   }
    //   }
    // }
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
    throw UnimplementedError('TODO: implement PngProperty._Decompress()');
    // using (MemoryStream memStream = new MemoryStream())
    // {
    // memStream.Write(compressedBuffer, 2, compressedBuffer.Length - 2);
    // byte[] buffer = new byte[decompressedSize];
    // memStream.Position = 0;
    //
    // using (DeflateStream zip = new DeflateStream(memStream, CompressionMode.Decompress))
    // {
    // zip.Read(buffer, 0, buffer.Length);
    // return buffer;
    // }
    // }
  }

  /// 目前被 [CompressPng] 调用，使用 zip deflate 算法压缩 png（Bitmap）数据。
  /// 并在前面插入 0x78 0x9C 两个字节，最终数据存放在 [compressedImageBytes].
  Uint8List _Compress(Uint8List decompressedBuffer) {
    throw UnimplementedError('TODO: implement PngProperty._Compress()');
    // using(MemoryStream memStream = new MemoryStream())
    // {
    // using (DeflateStream zip = new DeflateStream(memStream, CompressionMode.Compress, true))
    // {
    // zip.Write(decompressedBuffer, 0, decompressedBuffer.Length);
    // }
    // memStream.Position = 0;
    // byte[] buffer = new byte[memStream.Length + 2];
    // memStream.Read(buffer, 2, buffer.Length - 2);
    //
    // System.Buffer.BlockCopy(new byte[] { 0x78, 0x9C }, 0, buffer, 0, 2);
    //
    // return buffer;
    // }
  }

  Uint8List _GetRawImage(bool saveInMemory) {
    throw UnimplementedError('TODO: implement PngProperty._GetRawImage()');
  }

  //region Decoders
  // TODO: Decoders Code Region: not implemented
  //endregion

  //endregion

  @override
  void writeValue(WzBinaryWriter writer) {
    throw UnimplementedError('Cannot write a PngProperty');
  }

  @override
  WzObject? operator [](String name) {
    throw UnimplementedError('Invalid operation: PngProperty not supported');
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
