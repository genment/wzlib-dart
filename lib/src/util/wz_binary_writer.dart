part of util;

class WzBinaryWriter extends _BinaryWriterBase {
  late WzMutableKey WzKey;
  late int Hash;
  late WzHeader Header;
  late HashMap<String, int> StringCache;

  WzBinaryWriter(super._stream, Uint8List wzIv) {
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
    encOffset &= 0xFFFFFFFF;  // keep the LSB (32 bits)
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

class _BinaryWriterBase {
  bool _isMemoryStream = true;

  int get position => _stream.position;
  set position(int p) => _stream.position = p;

  final OutputStreamBase _stream;

  _BinaryWriterBase(this._stream) {
    _isMemoryStream = _stream is OutputStream;
  }

  void WriteBoolean(bool b) => _stream.writeByte(b ? 1 : 0);

// Signed Byte
  void WriteSByte(int byte) {
    _stream.writeByte(byte);
  }

// Unsigned Byte
  void WriteByte(int byte) {
    _stream.writeByte(byte);
  }

  void WriteInt16(int value) {
    _stream.writeUint16(value);
  }

  void WriteUint16(int value) {
    _stream.writeUint16(value);
  }

  void WriteInt32(int value) {
    _stream.writeUint32(value);
  }

  void WriteUint32(int value) {
    _stream.writeUint32(value);
  }

  void WriteInt64(int value) {
    _stream.writeInt64(value);
  }

  void WriteUint64(int value) {
    _stream.writeUint64(value);
  }

  void WriteSingle(double value) {
    _stream.writeFloat32(value);
  }

  void WriteDouble(double value) {
    _stream.writeFloat64(value);
  }

  void WriteBytes(Uint8List bytes, [int? len]) =>
      _stream.writeBytes(bytes, len);

  void Write(Uint8List buffer, int index, int count) {
    _stream.writeBytes(buffer.sublist(index, index + count));
  }

  void WriteString(String s) {}

  int get length => _stream.length;

  Uint8List getBytes() {
    return _isMemoryStream
        ? (_stream as OutputStream).getBytes()
        : throw UnsupportedError(
            "getBytes() can only be invoked when the internal stream is a memory stream.");
  }

  void flush() {
    _stream.flush();
  }

  void clear() {
    if (_isMemoryStream) {
      (_stream as OutputStream).clear();
    }
  }

  void reset() {
    if (_isMemoryStream) {
      (_stream as OutputStream).reset();
    }
  }

  void close() {
    _stream.close();
  }

// void skipBytes([int skipCount = 1]) => _file.readSync(skipCount);

}
