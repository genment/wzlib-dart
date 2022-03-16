import 'dart:collection';
import 'dart:io';
import 'dart:typed_data';

import 'wz_tool.dart';

import '../wz_file.dart';
import '../crypto/wz_keys.dart';

class WzBinaryWriter extends _BinaryWriter {
  late WzMutableKey WzKey;
  late int Hash;
  late WzHeader Header;
  late HashMap<String, int> StringCache;

  WzBinaryWriter(RandomAccessFile raf, Uint8List wzIv) : super(raf) {
    WzKey = WzKeyGenerator.generateWzKey(wzIv);
    Hash = 0; //TODO: should not???
    Header = WzHeader(); //TODO: should not???
    StringCache = HashMap<String, int>();
  }

  void WriteStringValue(String s, int withoutOffset, int withOffset) {
    if (s.length > 4 && StringCache.containsKey(s)) {
      WriteByte(withOffset);
      WriteInt32(StringCache[s]!);
    } else {
      WriteByte(withoutOffset);
      var sOffset = position;
      WriteString(s);
      if (!StringCache.containsKey(s)) {
        StringCache[s] = sOffset;
      }
    }
  }

  void WriteWzObjectValue(String s, int type) {
    var storeName = '${type}_$s';
    if (s.length > 4 && StringCache.containsKey(storeName)) {
      WriteByte(2);
      WriteInt32(StringCache[storeName]!);
    } else {
      var sOffset = position - Header.fstart;
      WriteByte(type);
      WriteString(s);
      if (!StringCache.containsKey(storeName)) {
        StringCache[storeName] = sOffset;
      }
    }
  }

  @override
  void WriteString(String value) {
    if (value.isEmpty) {
      WriteByte(0);
      return;
    }

    var unicode = false;
    var chars = value.codeUnits;

    for (var i in chars) {
      if (i > 127) {
        unicode = true;
        break;
      }
    }

    if (unicode) {
      var mask = 0xAAAA;

      if (value.length >= 127) {
        // Bugfix - >= because if value.Length = MaxValue, MaxValue will be written and then treated as a long-length marker
        WriteSByte(127);
        WriteInt32(value.length);
      } else {
        WriteSByte(value.length);
      }

      for (var i = 0; i < value.length; i++) {
        var encryptedChar = chars[i];
        encryptedChar ^= (WzKey[i * 2 + 1] << 8) + WzKey[i * 2];
        encryptedChar ^= mask;
        mask++;
        WriteUint16(encryptedChar);
      }
    } else {
      // ASCII
      var mask = 0xAA;

      if (value.length > 127) {
        // Note - no need for >= here because of 2's complement (MinValue == -(MaxValue + 1))
        WriteSByte(-128);
        WriteInt32(value.length);
      } else {
        WriteSByte(-value.length);
      }

      for (var i = 0; i < value.length; i++) {
        var encryptedChar = chars[i];
        encryptedChar ^= WzKey[i];
        encryptedChar ^= mask;
        mask++;
        WriteByte(encryptedChar);
      }
    }
  }

  void WriteNullTerminatedString(String value) {
    WriteBytes(Uint8List.fromList(value.codeUnits + [0]));
  }

  void WriteCompressedInt(int value) {
    if (value > 127 || value <= -128) {
      WriteSByte(-128);
      WriteInt32(value);
    } else {
      WriteSByte(value);
    }
  }

  void WriteCompressedLong(int value) {
    if (value > 127 || value <= -128) {
      WriteSByte(-128);
      WriteInt64(value);
    } else {
      WriteSByte(value);
    }
  }

  void WriteOffset(int value) {
    var encOffset = position;
    encOffset = (encOffset - Header.fstart) ^ 0xFFFFFFFF;
    encOffset *= Hash;
    encOffset -= Constants.WZ_OffsetConstant;
    encOffset = WzTool.RotateLeft(encOffset, (encOffset & 0x1F));
    var writeOffset = encOffset ^ (value - (Header.fstart * 2));
    WriteUint32(writeOffset);
  }

  /// <summary>
  /// The amount of bytes available remaining in the stream
  /// </summary>
  /// <returns></returns>
  int available() {
    return _file.lengthSync() - position;
  }

  Uint16List EncryptString(String stringToDecrypt) {
    throw UnimplementedError('WzListFile');
    var outputChars = Uint16List(stringToDecrypt.length);
    var chars = stringToDecrypt.codeUnits;
    for (var i = 0; i < chars.length; i++) {
      outputChars[i] = chars[i] ^ ((WzKey[i * 2 + 1] << 8) + WzKey[i * 2]);
    }
    return outputChars;
  }
}

abstract class _BinaryWriter {
  final RandomAccessFile _file;
  final Endian _endian = Endian.little;
  final ByteData _byteData = ByteData(8);

  int get position => _file.positionSync();

  set position(int p) => _file.setPositionSync(p);

  _BinaryWriter(this._file);

  void WriteBoolean(bool b) => _file.writeByteSync(b ? 1 : 0);

  void WriteSByte(int byte) {
    // _buffer.setUint8(0, byte);
    // _file.writeFromSync(_buffer.buffer.asUint8List());
    _file.writeByteSync(byte);
  }

  void WriteByte(int byte) {
    // _buffer.setUint8(0, byte);
    // _file.writeFromSync(_buffer.buffer.asUint8List());
    _file.writeByteSync(byte);
  }

  void WriteInt16(int value) {
    _byteData.setInt16(0, value, _endian);
    _file.writeFromSync(_byteData.buffer.asUint8List(0, 16));
  }

  void WriteUint16(int value) {
    _byteData.setUint16(0, value, _endian);
    _file.writeFromSync(_byteData.buffer.asUint8List(0, 16));
  }

  void WriteInt32(int value) {
    _byteData.setInt32(0, value, _endian);
    _file.writeFromSync(_byteData.buffer.asUint8List(0, 32));
  }

  void WriteUint32(int value) {
    _byteData.setUint32(0, value, _endian);
    _file.writeFromSync(_byteData.buffer.asUint8List(0, 32));
  }

  void WriteInt64(int value) {
    _byteData.setInt64(0, value, _endian);
    _file.writeFromSync(_byteData.buffer.asUint8List(0, 64));
  }

  void WriteUint64(int value) {
    _byteData.setUint64(0, value, _endian);
    _file.writeFromSync(_byteData.buffer.asUint8List(0, 64));
  }

  void WriteSingle(double value) {
    _byteData.setFloat32(0, value, _endian);
    _file.writeFromSync(_byteData.buffer.asUint8List(0, 32));
  }

  void WriteDouble(double value) {
    _byteData.setFloat64(0, value, _endian);
    _file.writeFromSync(_byteData.buffer.asUint8List(0, 64));
  }

  void WriteBytes(Uint8List bytes) => _file.writeFrom(bytes);

  void Write(Uint8List buffer, int index, int count) {
    _file.writeFromSync(buffer, index, index + count);
  }

  void WriteString(String s);

  void close() async {
    await _file.close();
  }
// void skipBytes([int skipCount = 1]) => _file.readSync(skipCount);

}
