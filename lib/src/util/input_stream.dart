part of util;
abstract class InputStreamBase {
  /// How many bytes are left in the stream.
  int get length;

  /// The current read position relative to the start of the buffer.
  int get position;
  set position(int p);

  /// Is the current position at the end of the stream?
  bool get isEOS;

  /// Read a boolean value from the stream.
  bool readBoolean();

  /// Read a byte from the stream.
  int readByte();

  /// Read a signed 8-bit byte from the stream.
  int readSByte();

  /// Read a signed 16-bit word from the stream.
  int readInt16();

  /// Read a unsigned 16-bit word from the stream.
  int readUint16();

  /// Read a signed 32-bit word from the stream.
  int readInt32();

  /// Read a unsigned 32-bit word from the stream.
  int readUint32();

  /// Read a signed 64-bit word from the stream.
  int readInt64();

  /// Read a unsigned 64-bit word from the stream.
  int readUint64();

  /// Read a 32-bit float value from the stream.
  double readFloat32();

  /// Read a 64-bit float value from the stream.
  double readFloat64();

  /// Read a set of bytes to the output stream.
  InputStreamBase readBytes(int count);

  /// Read an InputStream to the output stream.
  // void readOutputStream(OutputStreamBase stream);

  /// Reset to the beginning of the stream.
  void reset();

  /// Skip bytes (go forward)
  void skip([int count = 1]);

  /// Rewind bytes (go backward)
  void rewind([int count = 1]);

  /// Subset of bytes in the stream
  InputStreamBase subset([int? position, int? length]);

  /// Read [count] bytes from an [offset] of the current read position, without
  /// moving the read position.
  InputStreamBase peekBytes(int count, [int offset = 0]);

  Uint8List toUint8List();

  Future<void> close();
  void closeSync();
}

/// A buffer that can be read as a stream of bytes
class InputStream extends InputStreamBase {
  List<int> buffer;
  int start;
  int offset;
  late int _length; //

  @override
  int get length => _length - (offset - start);

  @override
  int get position => offset - start;

  @override
  set position(int v) {
    offset = start + v;
    // if (v < 0) {
    //   offset = start;
    // } else if (offset > buffer.length) {
    //   throw ArgumentError.value(v, 'new position');
    // }
  }

  @override
  bool get isEOS => offset >= (start + _length);

  /// Create a InputStream for reading from a List<int>
  InputStream(dynamic data, {this.start = 0, int? length})
      : buffer = data is TypedData
            ? Uint8List.view(
                data.buffer, data.offsetInBytes, data.lengthInBytes)
            : data is List<int>
                ? data
                : List<int>.from(data as Iterable<dynamic>),
        offset = start {
    _length = length ?? buffer.length;
  }

  /// Create a copy of [other].
  InputStream.from(InputStream other)
      : buffer = other.buffer,
        offset = other.offset,
        start = other.start,
        _length = other._length;

  /// Access the buffer relative from the current position.
  int operator [](int index) => buffer[offset + index];

  /// Return a InputStream to read a subset of this stream.  It does not
  /// move the read position of this stream.  [position] is specified relative
  /// to the start of the buffer.  If [position] is not specified, the current
  /// read position is used. If [length] is not specified, the remainder of this
  /// stream is used.
  @override
  InputStreamBase subset([int? position, int? length]) {
    if (position == null) {
      position = offset;
    } else {
      position += start;
    }

    if (length == null || length < 0) {
      length = _length - (position - start);
    }

    return InputStream(buffer, start: position, length: length);
  }

  /// Read [count] bytes from an [offset] of the current read position, without
  /// moving the read position.
  @override
  InputStreamBase peekBytes(int count, [int offset = 0]) {
    return subset((this.offset - start) + offset, count);
  }

  @override
  bool readBoolean() {
    return buffer[offset++] != 0;
  }

  /// Read a single byte.
  @override
  int readByte() {
    return buffer[offset++];
  }

  @override
  int readSByte() {
    final b = buffer[offset++];
    return b < 0x80 ? b : (b | 0xffffffffffffff00);
  }

  /// Read [count] bytes from the stream.
  @override
  InputStreamBase readBytes(int count) {
    final bytes = subset(offset, count);
    offset += bytes.length;
    return bytes as InputStream;
  }

  /// Read a 16-bit word from the stream.
  @override
  int readInt16() {
    final b1 = buffer[offset++] & 0xff;
    final b2 = buffer[offset++] & 0xff;
    if (b2 < 0x80) {
      return (b2 << 8) | b1;
    } else {
      return (b2 << 8) | b1 | 0xffffffffffff0000;
    }
  }

  /// Read a 16-bit word from the stream.
  @override
  int readUint16() {
    final b1 = buffer[offset++] & 0xff;
    final b2 = buffer[offset++] & 0xff;
    return (b2 << 8) | b1;
  }

  /// Read a 32-bit word from the stream.
  @override
  int readInt32() {
    final b1 = buffer[offset++] & 0xff;
    final b2 = buffer[offset++] & 0xff;
    final b3 = buffer[offset++] & 0xff;
    final b4 = buffer[offset++] & 0xff;
    if (b4 < 0x80) {
      return (b4 << 24) | (b3 << 16) | (b2 << 8) | b1;
    } else {
      return (b4 << 24) | (b3 << 16) | (b2 << 8) | b1 | 0xffffffff00000000;
    }
  }

  /// Read a 32-bit word from the stream.
  @override
  int readUint32() {
    final b1 = buffer[offset++] & 0xff;
    final b2 = buffer[offset++] & 0xff;
    final b3 = buffer[offset++] & 0xff;
    final b4 = buffer[offset++] & 0xff;
    return (b4 << 24) | (b3 << 16) | (b2 << 8) | b1;
  }

  /// Read a 64-bit word form the stream.
  @override
  int readInt64() {
    final b1 = buffer[offset++] & 0xff;
    final b2 = buffer[offset++] & 0xff;
    final b3 = buffer[offset++] & 0xff;
    final b4 = buffer[offset++] & 0xff;
    final b5 = buffer[offset++] & 0xff;
    final b6 = buffer[offset++] & 0xff;
    final b7 = buffer[offset++] & 0xff;
    final b8 = buffer[offset++] & 0xff;
    return (b8 << 56) |
        (b7 << 48) |
        (b6 << 40) |
        (b5 << 32) |
        (b4 << 24) |
        (b3 << 16) |
        (b2 << 8) |
        b1;
  }

  /// Read a 64-bit word form the stream.
  /// 
  /// Warning:
  /// Dart does NOT support unsigned int (64 bit) so far.
  /// Therefore a number greater than 0x7fffffffffffffff ([b8] > 0x7f)
  /// will be represented as negative.
  @override
  int readUint64() {
    final b1 = buffer[offset++] & 0xff;
    final b2 = buffer[offset++] & 0xff;
    final b3 = buffer[offset++] & 0xff;
    final b4 = buffer[offset++] & 0xff;
    final b5 = buffer[offset++] & 0xff;
    final b6 = buffer[offset++] & 0xff;
    final b7 = buffer[offset++] & 0xff;
    final b8 = buffer[offset++] & 0xff;
    return (b8 << 56) |
        (b7 << 48) |
        (b6 << 40) |
        (b5 << 32) |
        (b4 << 24) |
        (b3 << 16) |
        (b2 << 8) |
        b1;
  }

  @override
  double readFloat32() {
    final b1 = buffer[offset++] & 0xff;
    final b2 = buffer[offset++] & 0xff;
    final b3 = buffer[offset++] & 0xff;
    final b4 = buffer[offset++] & 0xff;
    return Uint8List.fromList([b1, b2, b3, b4])
        .buffer
        .asByteData()
        .getFloat32(0, Endian.little);
  }

  @override
  double readFloat64() {
    final b1 = buffer[offset++] & 0xff;
    final b2 = buffer[offset++] & 0xff;
    final b3 = buffer[offset++] & 0xff;
    final b4 = buffer[offset++] & 0xff;
    final b5 = buffer[offset++] & 0xff;
    final b6 = buffer[offset++] & 0xff;
    final b7 = buffer[offset++] & 0xff;
    final b8 = buffer[offset++] & 0xff;
    return Uint8List.fromList([b1, b2, b3, b4, b5, b6, b7, b8])
        .buffer
        .asByteData()
        .getFloat64(0, Endian.little);
  }

  @override
  Uint8List toUint8List() {
    var len = length;
    if (buffer is Uint8List) {
      final b = buffer as Uint8List;
      if ((offset + len) > b.length) {
        len = b.length - offset;
      }
      final bytes = Uint8List.view(b.buffer, b.offsetInBytes + offset, len);
      return bytes;
    }
    var end = offset + len;
    if (end > buffer.length) {
      end = buffer.length;
    }
    return Uint8List.fromList(buffer.sublist(offset, end));
  }

  /// Rewind the read head of the stream by the given number of bytes.
  @override
  void rewind([int length = 1]) {
    offset -= length;
    if (offset < 0) {
      offset = 0;
    }
  }

  /// Move the read position by [count] bytes.
  @override
  void skip([int count = 1]) {
    offset += count;
    if (offset > buffer.length) {
      throw ArgumentError.value(count, "skip bytes");
    }
  }
  
  /// Reset to the beginning of the stream.
  @override
  void reset() {
    offset = start;
  }

  @override
  Future<void> close() async {
    buffer = <int>[];
    _length = 0;
  }

  @override
  void closeSync() {
    buffer = <int>[];
    _length = 0;
  }
}

class FileHandle {
  final String _path;
  RandomAccessFile? _file;
  int _position;
  late int _length;

  FileHandle(this._path)
      : _file = File(_path).openSync(),
        _position = 0 {
    _length = _file!.lengthSync();
  }

  FileHandle.fromFile(File file)
      : _position = 0,
        _path = file.path,
        _file = file.openSync() {
    _length = _file!.lengthSync();
  }

  String get path => _path;

  int get position => _position;

  set position(int p) {
    if (_file == null || p == _position) {
      return;
    }
    _position = p;
    _file!.setPositionSync(p);
  }

  int get length => _length;

  bool get isOpen => _file != null;

  Future<void> close() async {
    if (_file == null) {
      return;
    }
    var fp = _file;
    _file = null;
    _position = 0;
    await fp!.close();
  }

  void closeSync() {
    if (_file == null) {
      return;
    }
    var fp = _file;
    _file = null;
    _position = 0;
    fp!.closeSync();
  }

  void open() {
    if (_file != null) {
      return;
    }

    _file = File(_path).openSync();
    _position = 0;
  }

  int readInto(Uint8List buffer, [int? end]) {
    if (_file == null) {
      open();
    }
    final size = _file!.readIntoSync(buffer, 0, end);
    _position += size;
    return size;
  }
}

class InputFileStream extends InputStreamBase {
  final String path;
  final FileHandle _file;
  int _fileOffset = 0;
  int _fileSize = 0;
  late Uint8List _buffer;
  int _position = 0;
  int _bufferSize = 0;
  int _bufferPosition = 0;

  static const int kDefaultBufferSize = 4096;

  InputFileStream(this.path,
      {int bufferSize = kDefaultBufferSize})
      : _file = FileHandle(path) {
    _fileSize = _file.length;
    // Don't have a buffer bigger than the file itself.
    // Also, make sure it's at least 8 bytes, so reading a 64-bit value doesn't
    // have to deal with buffer overflow.
    bufferSize = max(min(bufferSize, _fileSize), 8);
    _buffer = Uint8List(bufferSize);
    _readBuffer();
  }

  InputFileStream.fromFile(File file, {int bufferSize = kDefaultBufferSize})
      : path = file.path,
        _file = FileHandle.fromFile(file) {
    _fileSize = _file.length;
    bufferSize = max(min(bufferSize, _fileSize), 8);
    _buffer = Uint8List(bufferSize);
    _readBuffer();
  }

  InputFileStream.clone(InputFileStream other, {int? position, int? length})
      : path = other.path,
        _file = other._file,
        _fileOffset = other._fileOffset + (position ?? 0),
        _fileSize = length ?? other._fileSize,
        _buffer = Uint8List(kDefaultBufferSize) {
    _readBuffer();
  }

  @override
  int get length => _fileSize;

  @override
  int get position => _position;

  @override
  set position(int v) {
    if (v < _position) {
      rewind(_position - v);
    } else if (v > _position) {
      skip(v - _position);
    }
  }

  @override
  bool get isEOS => _position >= _fileSize;

  int get bufferSize => _bufferSize;

  int get bufferPosition => _bufferPosition;

  int get bufferRemaining => _bufferSize - _bufferPosition;

  int get fileRemaining => _fileSize - _position;

  @override
  InputStreamBase subset([int? position, int? length]) {
    return InputFileStream.clone(this, position:position, length:length);
  }

  /// Read [count] bytes from an [offset] of the current read position, without
  /// moving the read position.
  @override
  InputStreamBase peekBytes(int count, [int offset = 0]) {
    return subset(_position + offset, count);
  }

  @override
  bool readBoolean() {
    return readByte() != 0;
  }

  @override
  int readByte() {
    if (isEOS) {
      return 0;
    }
    if (_bufferPosition >= _bufferSize) {
      _readBuffer();
    }
    if (_bufferPosition >= _bufferSize) {
      return 0;
    }
    _position++;
    return _buffer[_bufferPosition++] & 0xff;
  }

  @override
  int readSByte() {
    int v = readByte();
    return v < 0x80 ? v : (v | 0xffffffffffffff00);
  }

  /// Read a 16-bit word from the stream.
  @override
  int readUint16() {
    var b1 = 0;
    var b2 = 0;
    if ((_bufferPosition + 2) < _bufferSize) {
      b1 = _buffer[_bufferPosition++] & 0xff;
      b2 = _buffer[_bufferPosition++] & 0xff;
      _position += 2;
    } else {
      b1 = readByte();
      b2 = readByte();
    }
    return (b2 << 8) | b1;
  }

  @override
  int readInt16() {
    int v = readUint16();
    return v < 0x8000 ? v : (v | 0xffffffffffff0000);
  }

  /// Read a 32-bit word from the stream.
  @override
  int readUint32() {
    var b1 = 0;
    var b2 = 0;
    var b3 = 0;
    var b4 = 0;
    if ((_bufferPosition + 4) < _bufferSize) {
      b1 = _buffer[_bufferPosition++] & 0xff;
      b2 = _buffer[_bufferPosition++] & 0xff;
      b3 = _buffer[_bufferPosition++] & 0xff;
      b4 = _buffer[_bufferPosition++] & 0xff;
      _position += 4;
    } else {
      b1 = readByte();
      b2 = readByte();
      b3 = readByte();
      b4 = readByte();
    }
    return (b4 << 24) | (b3 << 16) | (b2 << 8) | b1;
  }

  @override
  int readInt32() {
    int v = readUint32();
    return v < 0x80000000 ? v : (v | 0xffffffff00000000);
  }

  /// Read a 64-bit word form the stream.
  /// 
  /// Warning:
  /// Dart does NOT support unsigned int (64 bit) so far.
  /// Therefore a number greater than 0x7fffffffffffffff ([b8] > 0x7f)
  /// will be represented as negative.
  @override
  int readUint64() {
    return readInt64();
  }

  @override
  int readInt64() {
    var b1 = 0;
    var b2 = 0;
    var b3 = 0;
    var b4 = 0;
    var b5 = 0;
    var b6 = 0;
    var b7 = 0;
    var b8 = 0;
    if ((_bufferPosition + 8) < _bufferSize) {
      b1 = _buffer[_bufferPosition++] & 0xff;
      b2 = _buffer[_bufferPosition++] & 0xff;
      b3 = _buffer[_bufferPosition++] & 0xff;
      b4 = _buffer[_bufferPosition++] & 0xff;
      b5 = _buffer[_bufferPosition++] & 0xff;
      b6 = _buffer[_bufferPosition++] & 0xff;
      b7 = _buffer[_bufferPosition++] & 0xff;
      b8 = _buffer[_bufferPosition++] & 0xff;
      _position += 8;
    } else {
      b1 = readByte();
      b2 = readByte();
      b3 = readByte();
      b4 = readByte();
      b5 = readByte();
      b6 = readByte();
      b7 = readByte();
      b8 = readByte();
    }
    return (b8 << 56) |
        (b7 << 48) |
        (b6 << 40) |
        (b5 << 32) |
        (b4 << 24) |
        (b3 << 16) |
        (b2 << 8) |
        b1;
  }

  @override
  double readFloat32() {
    var b1 = 0;
    var b2 = 0;
    var b3 = 0;
    var b4 = 0;
    if ((_bufferPosition + 4) < _bufferSize) {
      b1 = _buffer[_bufferPosition++] & 0xff;
      b2 = _buffer[_bufferPosition++] & 0xff;
      b3 = _buffer[_bufferPosition++] & 0xff;
      b4 = _buffer[_bufferPosition++] & 0xff;
      _position += 4;
    } else {
      b1 = readByte();
      b2 = readByte();
      b3 = readByte();
      b4 = readByte();
    }
    return Uint8List.fromList([b1, b2, b3, b4])
        .buffer
        .asByteData()
        .getFloat32(0, Endian.little);
  }

  @override
  double readFloat64() {
    var b1 = 0;
    var b2 = 0;
    var b3 = 0;
    var b4 = 0;
    var b5 = 0;
    var b6 = 0;
    var b7 = 0;
    var b8 = 0;
    if ((_bufferPosition + 8) < _bufferSize) {
      b1 = _buffer[_bufferPosition++] & 0xff;
      b2 = _buffer[_bufferPosition++] & 0xff;
      b3 = _buffer[_bufferPosition++] & 0xff;
      b4 = _buffer[_bufferPosition++] & 0xff;
      b5 = _buffer[_bufferPosition++] & 0xff;
      b6 = _buffer[_bufferPosition++] & 0xff;
      b7 = _buffer[_bufferPosition++] & 0xff;
      b8 = _buffer[_bufferPosition++] & 0xff;
      _position += 8;
    } else {
      b1 = readByte();
      b2 = readByte();
      b3 = readByte();
      b4 = readByte();
      b5 = readByte();
      b6 = readByte();
      b7 = readByte();
      b8 = readByte();
    }
    return Uint8List.fromList([b1, b2, b3, b4, b5, b6, b7, b8])
        .buffer
        .asByteData()
        .getFloat64(0, Endian.little);
  }

  @override
  InputStreamBase readBytes(int count) {
    count = min(count, fileRemaining);
    final bytes = InputFileStream.clone(this, position: _position,
        length: count);
    skip(count);
    return bytes;
  }

  @override
  Uint8List toUint8List() {
    if (isEOS) {
      return Uint8List(0);
    }
    var length = fileRemaining;
    final bytes = Uint8List(length);
    _file.position = _fileOffset + _position;
    final readBytes = _file.readInto(bytes);
    skip(length);
    if (readBytes != bytes.length) {
      bytes.length = readBytes;
    }
    return bytes;
  }

  @override
  void rewind([int count = 1]) {
    if ((_bufferPosition - count) < 0) {
      _position = max(_position - count, 0);
      _readBuffer();
      return;
    }
    _bufferPosition -= count;
    _position -= count;
  }

  @override
  void skip([int count = 1]) {
    if ((_bufferPosition + count) < _bufferSize) {
      _bufferPosition += count;
      _position += count;
    } else {
      _position += count;
      _readBuffer();
    }
  }

  @override
  void reset() {
    _position = 0;
    _readBuffer();
  }

  @override
  Future<void> close() async {
    await _file.close();
    _fileSize = 0;
    _position = 0;
  }

  @override
  void closeSync() {
    _file.closeSync();
    _fileSize = 0;
    _position = 0;
  }

  void _readBuffer() {
    _bufferPosition = 0;
    _file.position = _fileOffset + _position;
    _bufferSize = _file.readInto(_buffer, _buffer.length);
  }
}
