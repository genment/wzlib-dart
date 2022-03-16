import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'wz_tool.dart';

import '../wz_file.dart';
import '../crypto/wz_keys.dart';

class WzBinaryReader extends _BinaryReader {
  late WzMutableKey WzKey;
  late int Hash;
  late WzHeader Header;

  WzBinaryReader(RandomAccessFile raf, Uint8List wzIv) : super(raf) {
    WzKey = WzKeyGenerator.generateWzKey(wzIv);
    Hash = 0; //TODO: should not???
    Header = WzHeader(); //TODO: should not???
  }

  String ReadStringAtOffset(int offset, [bool skipByte = false]) {
    var currOffset = position;
    position = offset;
    if (skipByte) {
      skipBytes(1);
    }
    var retString = ReadString();
    position = currOffset;
    return retString;
  }

  @override
  String ReadString() {
    var smallLength = ReadSByte();
    if (smallLength == 0) {
      return '';
    }

    int length;
    var retString = StringBuffer();

    if (smallLength > 0) {
      // Unicode
      var mask = 0xAAAA;
      length = smallLength == 127 ? ReadInt32() : smallLength;
      if (length <= 0) return '';

      for (var i = 0; i < length; i++) {
        var encryptedChar = ReadUInt16();
        encryptedChar ^= mask;
        encryptedChar ^= (WzKey[i * 2 + 1] << 8) + WzKey[i * 2];
        retString.writeCharCode(encryptedChar); // TODO: check if OK
        mask++;
      }
    } else {
      // ASCII
      var mask = 0xAA;
      length = smallLength == -128 ? ReadInt32() : (-smallLength);
      if (length <= 0) return '';

      for (var i = 0; i < length; i++) {
        var encryptedChar = ReadByte();
        encryptedChar ^= mask;
        encryptedChar ^= WzKey[i];
        retString.writeCharCode(encryptedChar); // TODO: check if OK
        mask++;
      }
    }
    return retString.toString();
  }

  /// <summary>
  /// Reads an ASCII string, without decryption
  /// </summary>
  /// <param name="filePath">Length of bytes to read</param>
  String ReadPlainString(int length) {
    return Encoding.getByName('ascii')!.decoder.convert(ReadBytes(length));
  }

  String ReadNullTerminatedString() {
    var retString = StringBuffer();
    var b = ReadByte();
    while (b != 0) {
      retString.writeCharCode(b);
      b = ReadByte();
    }
    return retString.toString();
  }

  int readCompressedInt() {
    var sb = ReadSByte();
    return sb == -128 ? ReadInt32() : sb;
  }

  int ReadLong() {
    var sb = ReadSByte();
    return sb == -128 ? ReadInt64() : sb;
  }

  /// <summary>
  /// The amount of bytes available remaining in the stream
  /// </summary>
  /// <returns></returns>
  int available() {
    return _file.lengthSync() - position;
  }

  int ReadOffset() {
    var offset = position;
    offset = (offset - Header.fstart) ^ 0xFFFFFFFF;
    offset *= Hash;
    offset &= 0xFFFFFFFF;  // truncate higher bits
    offset -= Constants.WZ_OffsetConstant;
    offset = WzTool.RotateLeft(offset, (offset & 0x1F));
    var encryptedOffset = ReadUInt32();
    offset ^= encryptedOffset;
    offset += Header.fstart * 2;
    return offset;
  }

  String DecryptString(Uint16List stringToDecrypt) {
    throw UnimplementedError('only used for WzListFile');
  }

  String DecryptNonUnicodeString(Uint16List stringToDecrypt) {
    throw UnimplementedError('not used');
  }

  String ReadStringBlock(int offset) {
    switch (ReadByte()) {
      case 0:
      case 0x73:
        return ReadString();
      case 1:
      case 0x1B:
        return ReadStringAtOffset(offset + ReadInt32());
      default:
        return '';
    }
  }
}

abstract class _BinaryReader {
  final RandomAccessFile _file;
  final Endian _endian = Endian.little;

  // BinaryReader(Stream input);
  // BinaryReader(Stream input, Encoding encoding);
  // BinaryReader(Stream input, Encoding encoding, bool leaveOpen);
  //  Stream BaseStream { get; }
  //  void Close();
  //  void Dispose(bool disposing);
  //  void Dispose();

  int get position => _file.positionSync();

  set position(int p) => _file.setPositionSync(p);

  _BinaryReader(this._file);

  int peekChar() {
    var p = _file.positionSync();
    var c = _file.readByteSync();
    _file.setPositionSync(p);
    return c;
  }

  bool readBoolean() => _file.readByteSync() != 0;

  int ReadByte() => _readByteData1().getUint8(0);

  int ReadSByte() => _readByteData1().getInt8(0);

  int ReadInt16() => _readByteData2().getInt16(0, _endian);

  int ReadUInt16() => _readByteData2().getUint16(0, _endian);

  int ReadInt32() => _readByteData4().getInt32(0, _endian);

  int ReadUInt32() => _readByteData4().getUint32(0, _endian);

  int ReadInt64() => _readByteData8().getInt64(0, _endian);

  int ReadUInt64() => _readByteData8().getUint64(0, _endian);

  double ReadSingle() => _readByteData4().getFloat32(0, _endian);

  double ReadDouble() => _readByteData8().getFloat64(0, _endian);

  Uint8List ReadBytes(int count) => _file.readSync(count);

  int Read(Uint8List buffer, int index, int count) {
    return _file.readIntoSync(buffer, index, index + count);
  }

  String ReadString();

  ByteData _readByteData1() => _file.readSync(1).buffer.asByteData();

  ByteData _readByteData2() => _file.readSync(2).buffer.asByteData();

  ByteData _readByteData4() => _file.readSync(4).buffer.asByteData();

  ByteData _readByteData8() => _file.readSync(8).buffer.asByteData();

  void skipBytes([int skipCount = 1]) => _file.readSync(skipCount);

  void close() {
    _file.closeSync();
  }
// int read();
// int read(char[] buffer, int index, int count);
// char readChar();
// char[] readChars(int count);
// decimal readDecimal();
}
