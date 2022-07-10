import 'dart:io';
import 'dart:typed_data';

import 'wz_types.dart';
import 'wz_object.dart';
import 'wz_file.dart';
import 'wz_image.dart';

import 'util/output_stream.dart';
import 'util/wz_tool.dart';
import 'util/wz_binary_reader.dart';
import 'util/wz_binary_writer.dart';

class WzDirectory extends WzObject {
  //region Fields
  WzFile wzFile;
  List<WzDirectory> wzDirectories = [];
  List<WzImage> wzImages = [];

  WzBinaryReader? reader;

  Uint8List? wzIv;

  int offset = 0;
  int hash = 0;
  int blockSize = 0, checksum = 0, offsetSize = 0;

  //endregion

  //region Fields (override)
  @override
  WzObjectType get objectType => WzObjectType.Directory;

  @override
  WzFile get wzFileParent => wzFile;

  //endregion

  //region Constructor

  WzDirectory(String name, this.wzFile, [this.reader, this.hash = 0, this.wzIv]) : super(name) {
    hash = hash == 0 ? wzFile.versionHash : hash;
    wzIv = wzIv ?? wzFile.wzIv;
  }

  //endregion

  //region Methods
  void ParseDirectory() {
    if (reader == null) throw ArgumentError.notNull('reader');
    final _reader = reader!;

    var available = _reader.available();
    if (available == 0) return;

    var entryCount = _reader.readCompressedInt();
    if (entryCount < 0 || entryCount > 100000) {
      // probably nothing > 100k folders for now.
      throw Exception('Invalid wz version used for decryption, try parsing other version numbers.');
    }
    for (var i = 0; i < entryCount; i++) {
      var type = _reader.ReadByte();
      String fname;
      int fsize;
      int checksum;
      int offset;

      var rememberPos = 0;
      switch (type) {
        case 1: //01 XX 00 00 00 00 00 OFFSET (4 bytes)
          {
            _reader.ReadInt32(); // unknown
            _reader.ReadInt16();
            var offs = _reader.ReadOffset();
            continue;
          }
        case 2:
          {
            var stringOffset = _reader.ReadInt32();
            rememberPos = _reader.position;
            _reader.position = _reader.Header.fstart + stringOffset;
            type = _reader.ReadByte();
            fname = _reader.ReadString();
            break;
          }
        case 3:
        case 4:
          {
            fname = _reader.ReadString();
            rememberPos = _reader.position;
            break;
          }
        default:
          {
            throw Exception('[WzDirectory] Unknown directory. type = $type');
          }
      }
      _reader.position = rememberPos;
      fsize = _reader.readCompressedInt();
      checksum = _reader.readCompressedInt();
      offset = _reader.ReadOffset();

      if (type == 3) {
        wzDirectories.add(WzDirectory(fname, wzFile, _reader, hash, wzIv)
          ..blockSize = fsize
          ..checksum = checksum
          ..offset = offset
          ..parent = this);
      } else {
        wzImages.add(WzImage(fname, _reader, checksum)
          ..blockSize = fsize
          ..offset = offset
          ..parent = this);
      }
    }

    for (var subdir in wzDirectories) {
      // TODO: I don't know how disabling this code would fix a KMS Base.wz issue.
      // see: commit 63e2d72a
      // [MapleLib] Fixed a parsing issue with the new KMS Base.wz without WzImage

      _reader.position = subdir.offset;
      subdir.ParseDirectory();
    }
  }

  void SaveImages(WzBinaryWriter wzWriter, RandomAccessFile raf) {
    for (var img in wzImages) {
      if (img.changed) {
        // read from .TEMP file
        raf.setPositionSync(img.tempFileStart);
        var buffer = Uint8List(img.blockSize);
        raf.readIntoSync(buffer, 0, img.blockSize);
        wzWriter.WriteBytes(buffer);
      } else {
        // read from original .wz file
        img.reader.position = img.tempFileStart;
        wzWriter.WriteBytes(img.reader.ReadBytes(img.tempFileEnd - img.tempFileStart));
      }
    }
    for (var dir in wzDirectories) {
      dir.SaveImages(wzWriter, raf);
    }
  }

  /// Generate .TEMP file
  ///
  /// [useIv] The IV to use while generating the data file. If null, it'll use the WzDirectory default.
  /// [bIsWzUserKeyDefault] Uses the default MapleStory UserKey or a custom key.
  /// [prevOpenedStream] The previously opened file stream.
  int GenerateDataFile(Uint8List? useIv, bool bIsWzUserKeyDefault, RandomAccessFile prevOpenedStream) {
    // whole shit gonna be re-written if its a custom IV specified
    var useCustomIv = useIv != null;

    blockSize = 0;
    var entryCount = wzDirectories.length + wzImages.length;
    if (entryCount == 0) {
      offsetSize = 1;
      return (blockSize = 0);
    }
    blockSize = WzTool.GetCompressedIntLength(entryCount);
    offsetSize = WzTool.GetCompressedIntLength(entryCount);

    for (var img in wzImages) {
      if (useCustomIv || // everything needs to be re-written when a custom IV is used.
          !bIsWzUserKeyDefault || //  everything needs to be re-written when a custom UserKey is used too
          img.changed) // or when an image is changed
      {
        var imgWriter = WzBinaryWriter(OutputStream(), useCustomIv ? useIv : wzIv!);
        img.SaveImage(imgWriter, bIsWzUserKeyDefault, useCustomIv);
        var imgBytes = imgWriter.getBytes();
        img.CalculateAndSetImageChecksum(imgBytes);
        img.tempFileStart = prevOpenedStream.positionSync();
        prevOpenedStream.writeFromSync(imgBytes);
        img.tempFileEnd = prevOpenedStream.positionSync();
        // imgWriter.close();
      } else {
        img.tempFileStart = img.offset;
        img.tempFileEnd = img.offset + img.blockSize;
      }
      img.UnparseImage(); // todo: why???

      var nameLen = WzTool.GetWzObjectValueLength(img.name, 4);
      blockSize += nameLen;
      var imgLen = img.blockSize;
      blockSize += WzTool.GetCompressedIntLength(imgLen);
      blockSize += imgLen;
      blockSize += WzTool.GetCompressedIntLength(img.checksum);
      blockSize += 4;
      offsetSize += nameLen;
      offsetSize += WzTool.GetCompressedIntLength(imgLen);
      offsetSize += WzTool.GetCompressedIntLength(img.checksum);
      offsetSize += 4;

      // otherwise Item.wz (300MB) probably uses > 4GB
      // if (useCustomIv || !bIsWzUserKeyDefault) {
      // when using custom IV, or changing IVs, all images have to be re-read and re-written..
      // GC.Collect(); // GC slows down writing of maps in HaCreator
      // GC.WaitForPendingFinalizers();
      // }

      //Debug.WriteLine("Writing image :" + img.FullPath);
    }

    for (var dir in wzDirectories) {
      var nameLen = WzTool.GetWzObjectValueLength(dir.name, 3);
      blockSize += nameLen;
      blockSize += dir.GenerateDataFile(useIv, bIsWzUserKeyDefault, prevOpenedStream);
      blockSize += WzTool.GetCompressedIntLength(dir.blockSize);
      blockSize += WzTool.GetCompressedIntLength(dir.checksum);
      blockSize += 4;
      offsetSize += nameLen;
      offsetSize += WzTool.GetCompressedIntLength(dir.blockSize);
      offsetSize += WzTool.GetCompressedIntLength(dir.checksum);
      offsetSize += 4;

      //Debug.WriteLine("Writing dir :" + dir.FullPath);
    }
    return blockSize;
  }

  void SaveDirectory(WzBinaryWriter writer) {
    offset = writer.position;
    var entryCount = wzDirectories.length + wzImages.length;
    if (entryCount == 0) {
      blockSize = 0;
      return;
    }
    writer.WriteCompressedInt(entryCount);
    for (var img in wzImages) {
      writer.WriteWzObjectValue(img.name, 4);
      writer.WriteCompressedInt(img.blockSize);
      writer.WriteCompressedInt(img.checksum);
      writer.WriteOffset(img.offset);
    }
    for (var dir in wzDirectories) {
      writer.WriteWzObjectValue(dir.name, 3);
      writer.WriteCompressedInt(dir.blockSize);
      writer.WriteCompressedInt(dir.checksum);
      writer.WriteOffset(dir.offset);
    }
    for (var dir in wzDirectories) {
      if (dir.blockSize > 0) {
        dir.SaveDirectory(writer);
      } else {
        writer.WriteByte(0);
      }
    }
  }

  int GetOffsets(int curOffset) {
    offset = curOffset;
    curOffset += offsetSize;
    for (var dir in wzDirectories) {
      curOffset = dir.GetOffsets(curOffset);
    }
    return curOffset;
  }

  int GetImgOffsets(int curOffset) {
    for (var img in wzImages) {
      img.offset = curOffset;
      curOffset += img.blockSize;
    }
    for (var dir in wzDirectories) {
      curOffset = dir.GetImgOffsets(curOffset);
    }
    return curOffset;
  }

  /// Parses the wz images
  void ParseImages() {
    if (reader == null) throw ArgumentError.notNull('reader');
    final _reader = reader!;
  
    for (var img in wzImages) {
      if (_reader.position != img.offset) {
        _reader.position = img.offset;
      }
      img.ParseImage();
    }
    for (var subdir in wzDirectories) {
      if (_reader.position != subdir.offset) {
        _reader.position = subdir.offset;
      }
      subdir.ParseImages();
    }
  }

  /// Sets the version hash of the directory (see WzFile.CreateVersionHash() )
  void SetVersionHash(int newHash) {
    hash = newHash;
    for (var subdir in wzDirectories) {
      subdir.SetVersionHash(newHash);
    }
  }

  /// Adds a WzImage to the list of wz images
  void AddImage(WzImage img) {
    wzImages.add(img);
    img.parent = this;
  }

  /// Adds a WzDirectory to the list of sub directories
  void AddDirectory(WzDirectory dir) {
    wzDirectories.add(dir);
    dir.wzFile = wzFile;
    dir.parent = this;
  }

  /// Removes an image from the list
  /// [image] The image to remove
  void RemoveImage(WzImage image) {
    wzImages.remove(image);
    image.dispose();
    image.parent = null;
  }

  /// Removes a sub directory from the list
  void RemoveDirectory(WzDirectory dir) {
    wzDirectories.remove(dir);
    dir.dispose();
    dir.parent = null;
  }

  WzDirectory deepClone() {
    throw UnimplementedError('not used so far.');
  }

  //endregion

  //region Methods (override)
  @override
  WzObject? operator [](String name) {
    var nameLower = name.toLowerCase();

    for (var i in wzImages) {
      if (i.name.toLowerCase() == nameLower) {
        return i;
      }
    }
    for (var d in wzDirectories) {
      if (d.name.toLowerCase() == nameLower) {
        return d;
      }
    }
    //throw new KeyNotFoundException("No wz image or directory was found with the specified name");
    return null;
  }

  operator []=(String name, WzObject value) {
    value.name = name;
    if (value is WzDirectory) {
      AddDirectory(value);
    } else if (value is WzImage) {
      AddImage(value);
    } else {
      throw ArgumentError.value(value, name, 'Value must be a Directory or Image');
    }
  }

  @override
  void dispose() {
    for (var img in wzImages) {
      img.dispose();
    }
    for (var dir in wzDirectories) {
      dir.dispose();
    }
    wzImages.clear();
    wzDirectories.clear();
  }

  @override
  void remove() {
    (parent as WzDirectory).RemoveDirectory(this);
  }

  @override
  String toString() {
    return name;
  }
//endregion
}
