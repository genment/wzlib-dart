part of util;

class WzBinaryReader extends _BinaryReaderBase {
  late WzMutableKey WzKey;
  late int Hash;
  late WzHeader Header;

  WzBinaryReader(super._stream, Uint8List wzIv) {
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
    return _stream.length - position;
  }

  int ReadOffset() {
    var offset = position;
    offset = (offset - Header.fstart) ^ 0xFFFFFFFF;
    offset *= Hash;
    offset &= 0xFFFFFFFF;  // keep the LSB (32 bits)
    offset -= Constants.WZ_OffsetConstant;
    offset = WzTool.RotateLeft(offset, (offset & 0x1F));
    var encryptedOffset = ReadUInt32();
    offset ^= encryptedOffset;
    offset += Header.fstart * 2;
    offset &= 0xFFFFFFFF;  // keep the LSB (32 bits)
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

abstract class _BinaryReaderBase {
  final InputStreamBase _stream;

  int get position => _stream.position;

  set position(int p) => _stream.position = p;

  _BinaryReaderBase(this._stream);

  int peekChar() {
    var p = _stream.position;
    var c = _stream.readByte();
    _stream.position = p;
    return c;
  }

  bool readBoolean() => _stream.readBoolean();

  int ReadByte() => _stream.readByte();

  int ReadSByte() => _stream.readSByte();

  int ReadInt16() => _stream.readInt16();

  int ReadUInt16() =>_stream.readUint16();

  int ReadInt32() => _stream.readInt32();

  int ReadUInt32() => _stream.readUint32();

  int ReadInt64() => _stream.readInt64();

  int ReadUInt64() => _stream.readUint64();

  double ReadSingle() => _stream.readFloat32();

  double ReadDouble() => _stream.readFloat64();

  Uint8List ReadBytes(int count) => _stream.readBytes(count).toUint8List();

  // int Read(Uint8List buffer, int index, int count) {
  //   return _stream.readIntoSync(buffer, index, index + count);
  // }

  String ReadString();

  void skipBytes([int skipCount = 1]) => _stream.skip(skipCount);

  void close() {
    _stream.close();
  }
}
