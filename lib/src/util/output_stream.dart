part of util;

abstract class OutputStreamBase {

  /// How many bytes have been written into the stream.
  int get length;

  /// The current read position relative to the start of the buffer.
  int position = 0;

  /// Write a boolean value to the stream.
  void writeBoolean(bool value);

  /// Write a byte to the stream.
  void writeByte(int value);

  /// Write a signed 8-bit byte to the stream.
  void writeSByte(int value);

  /// Write a signed 16-bit word to the stream.
  void writeInt16(int value);

  /// Write a unsigned 16-bit word to the stream.
  void writeUint16(int value);

  /// Write a signed 32-bit word to the stream.
  void writeInt32(int value);

  /// Write a unsigned 32-bit word to the stream.
  void writeUint32(int value);

  /// Write a signed 64-bit word to the stream.
  void writeInt64(int value);

  /// Write a unsigned 64-bit word to the stream.
  void writeUint64(int value);

  /// Write a 32-bit float value to the stream.
  void writeFloat32(double value);

  /// Write a 64-bit float value to the stream.
  void writeFloat64(double value);

  /// Write a set of bytes to the output stream.
  void writeBytes(List<int> bytes, [int? len]);

  /// Write an InputStream to the output stream.
  void writeInputStream(InputStreamBase stream);

  /// Write any pending data to the stream.
  void flush();

  /// Skip bytes (go forward)
  void skip([int count = 1]);

  /// Rewind bytes (go backward)
  void rewind([int count = 1]);

  /// Subset of bytes in the stream
  Uint8List subset(int start, [int? end]);

  Future<void> close() async {}
  void closeSync() {}
}

// always Little-Endian
class OutputStream extends OutputStreamBase {

  final ByteData _byteData = ByteData(8);

  int _length = 0;

  @override
  int get length => _length;

  /// Create a byte buffer for writing.
  OutputStream({dynamic buffer, int? size = _blockSize})
      : _buffer = buffer ?? Uint8List(size ?? _blockSize);

  bool get isEOS => position >= _length;
  
  @override
  void flush() {}

  /// Get the resulting bytes from the buffer.
  Uint8List getBytes() {
    return Uint8List.view(_buffer.buffer, 0, _length);
  }

  /// Clear the buffer.
  void clear() {
    _buffer = Uint8List(_blockSize);
    position = _length = 0;
  }

  /// Reset the buffer.
  void reset() {
    position = _length = 0;
  }
  
  @override
  void writeBoolean(bool value) {
    writeByte(value ? 1 : 0);
  }

  /// Write a byte to the end of the buffer.
  @override
  void writeByte(int value) {
    if (position == _buffer.length) {
      _expandBuffer();
    }
    _buffer[position++] = value & 0xff;
    if (position > _length) {
      _length = position;
    }
  }
  
  @override
  void writeSByte(int value) {
    writeByte(value);
  }
  
  @override
  void writeInt16(int value) {
    writeByte((value) & 0xff);
    writeByte((value >> 8) & 0xff);
  }

  @override
  void writeUint16(int value) {
    writeByte((value) & 0xff);
    writeByte((value >> 8) & 0xff);
  }
  
  @override
  void writeInt32(int value) {
    writeByte((value) & 0xff);
    writeByte((value >> 8) & 0xff);
    writeByte((value >> 16) & 0xff);
    writeByte((value >> 24) & 0xff);
  }

  @override
  void writeUint32(int value) {
    writeByte((value) & 0xff);
    writeByte((value >> 8) & 0xff);
    writeByte((value >> 16) & 0xff);
    writeByte((value >> 24) & 0xff);
  }
  
  @override
  void writeInt64(int value) {
    writeByte((value) & 0xff);
    writeByte((value >> 8) & 0xff);
    writeByte((value >> 16) & 0xff);
    writeByte((value >> 24) & 0xff);
    writeByte((value >> 32) & 0xff);
    writeByte((value >> 40) & 0xff);
    writeByte((value >> 48) & 0xff);
    writeByte((value >> 56) & 0xff);
  }
  
  @override
  void writeUint64(int value) {
    writeByte((value) & 0xff);
    writeByte((value >> 8) & 0xff);
    writeByte((value >> 16) & 0xff);
    writeByte((value >> 24) & 0xff);
    writeByte((value >> 32) & 0xff);
    writeByte((value >> 40) & 0xff);
    writeByte((value >> 48) & 0xff);
    writeByte((value >> 56) & 0xff);
  }
  
  @override
  void writeFloat32(double value) {
    _byteData.setFloat32(0, value, Endian.little);
    writeBytes(_byteData.buffer.asUint8List(0, 4));
  }

  @override
  void writeFloat64(double value) {
    _byteData.setFloat64(0, value, Endian.little);
    writeBytes(_byteData.buffer.asUint8List(0, 8));
  }

  /// Write a set of bytes to the end of the buffer.
  @override
  void writeBytes(List<int> bytes, [int? len]) {
    len ??= bytes.length;

    while (position + len > _buffer.length) {
      _expandBuffer((position + len) - _buffer.length);
    }
    _buffer.setRange(position, position + len, bytes);
    position += len;
    if (position > _length) {
      _length = position;
    }
  }

  @override
  void writeInputStream(InputStreamBase stream) {
    var streamLen = stream.length;
    while (position + streamLen > _buffer.length) {
      _expandBuffer((position + streamLen) - _buffer.length);
    }

    if (stream is InputStream) {
      _buffer.setRange(
          position, position + streamLen, stream.buffer, stream.offset);
    } else {
      var bytes = stream.toUint8List();
      _buffer.setRange(position, position + streamLen, bytes, 0);
    }
    position += streamLen;
    if (position > _length) {
      _length = position;
    }
  }

  /// Return the subset of the buffer in the range [start:end].
  ///
  /// If [start] or [end] are < 0 then it is relative to the end of the buffer.
  /// If [end] is not specified (or null), then it is the end of the buffer.
  /// This is equivalent to the python list range operator.
  @override
  Uint8List subset(int start, [int? end]) {
    if (start < 0) {
      start = (_length) + start;
    }

    if (end == null) {
      end = _length;
    } else if (end < 0) {
      end = _length + end;
    }

    return Uint8List.view(_buffer.buffer, start, end - start);
  }
  
  @override
  void rewind([int count = 1]) {
    if (count > position) {
      position = 0;
    } else {
      position -= count;
    }
  }
  
  @override
  void skip([int count = 1]) {
    if (position + count > _buffer.length) {
      // out of buffer
      _expandBuffer(position + count - _buffer.length);
    }
    position += count;
  }

  /// Grow the buffer to accommodate additional data.
  void _expandBuffer([int? required]) {
    var blockSize = _blockSize;
    if (required != null) {
      if (required > blockSize) {
        blockSize = required;
      }
    }
    final newLength = (_buffer.length + blockSize) * 2;
    final newBuffer = Uint8List(newLength);
    newBuffer.setRange(0, _buffer.length, _buffer);
    _buffer = newBuffer;
  }

  static const _blockSize = 0x8000; // 32k block-size
  Uint8List _buffer;
}


class _FileHandle {
  final String _path;
  RandomAccessFile? _file;
  int _position;

  _FileHandle(this._path,
      {FileMode mode = FileMode.read, bool recursive = false})
      : _position = 0 {
    final file = File(_path);
    file.createSync(recursive: recursive);
    _file = file.openSync(mode: mode);
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

  bool get isOpen => _file != null;

  void open({FileMode mode = FileMode.read}) {
    if (_file != null) {
      return;
    }
    final f = File(_path);
    if (mode != FileMode.read) {
      f.createSync(recursive: true);
    }
    _file = f.openSync(mode: mode);
    _position = 0;
  }

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

  int readInto(List<int> buffer, [int? end]) {
    if (_file == null) {
      open();
    }
    final size = _file!.readIntoSync(buffer, 0, end);
    _position += size;
    return size;
  }

  void writeFrom(List<int> buffer, [int start = 0, int? end]) {
    if (_file == null) {
      open(mode: FileMode.write);
    }
    _file!.writeFromSync(buffer, start, end);
    _position += (end == null ? buffer.length : end - start);
  }
}

class OutputFileStream extends OutputStreamBase {
  String path;
  int _length;
  int _position;
  final _FileHandle _file;
  final Uint8List _buffer;
  final ByteData _number;
  int _bufferPosition;

  OutputFileStream(this.path, {int? bufferSize})
      : _length = 0
      , _file = _FileHandle(path, mode: FileMode.write, recursive: true)
      , _buffer = Uint8List(bufferSize == null ? 8192 : bufferSize < 1 ? 1 :
                            bufferSize)
      , _bufferPosition = 0
      , _position = 0
      , _number = ByteData(8);

  @override
  int get position => _position;

  @override
  set position(int v) {
    if (v < 0) {
      throw ArgumentError.value(v, 'position', 'Invalid position');
    }
    if (v < _position) {
      rewind(_position - v);
    } else if (v > _position) {
      skip(v - _position);
    }
  }

  @override
  int get length => _length;

  void _updateLength() {
    if (_position > _length) {
      _length = _position;
    }
  }

  /// Move position pointer back to the end of stream.
  void resumePosition() {
    position = _length;
  }

  @override
  void flush() {
    if (_bufferPosition > 0) {
      if (_file.isOpen) {
        _file.writeFrom(_buffer, 0, _bufferPosition);
      }
      _bufferPosition = 0;
    }
  }

  @override
  Future<void> close() async {
    if (!_file.isOpen) {
      return;
    }
    flush();
    await _file.close();
    _position = 0;
  }

  @override
  void closeSync() {
    if (!_file.isOpen) {
      return;
    }
    flush();
    _file.closeSync();
    _position = 0;
  }

  @override
  void writeBoolean(bool value) {
    writeByte(value ? 1 : 0);
  }

  /// Write a byte to the end of the buffer.
  @override
  void writeByte(int value) {
    _buffer[_bufferPosition++] = value & 0xff;
    if (_bufferPosition == _buffer.length) {
      flush();
    }
    _position++;
    _updateLength();
  }

  @override
  void writeSByte(int value) {
    writeByte(value & 0xff);
  }

  @override
  void writeInt16(int value) {
    writeByte((value) & 0xff);
    writeByte((value >> 8) & 0xff);
  }

  /// Write a 16-bit word to the end of the buffer.
  @override
  void writeUint16(int value) {
    writeByte((value) & 0xff);
    writeByte((value >> 8) & 0xff);
  }

  @override
  void writeInt32(int value) {
    writeByte((value) & 0xff);
    writeByte((value >> 8) & 0xff);
    writeByte((value >> 16) & 0xff);
    writeByte((value >> 24) & 0xff);
  }

  /// Write a 32-bit word to the end of the buffer.
  @override
  void writeUint32(int value) {
    writeByte((value) & 0xff);
    writeByte((value >> 8) & 0xff);
    writeByte((value >> 16) & 0xff);
    writeByte((value >> 24) & 0xff);
  }

  @override
  void writeInt64(int value) {
    writeByte((value) & 0xff);
    writeByte((value >> 8) & 0xff);
    writeByte((value >> 16) & 0xff);
    writeByte((value >> 24) & 0xff);
    writeByte((value >> 32) & 0xff);
    writeByte((value >> 40) & 0xff);
    writeByte((value >> 48) & 0xff);
    writeByte((value >> 56) & 0xff);
  }

  @override
  void writeUint64(int value) {
    writeByte((value) & 0xff);
    writeByte((value >> 8) & 0xff);
    writeByte((value >> 16) & 0xff);
    writeByte((value >> 24) & 0xff);
    writeByte((value >> 32) & 0xff);
    writeByte((value >> 40) & 0xff);
    writeByte((value >> 48) & 0xff);
    writeByte((value >> 56) & 0xff);
  }

  @override
  void writeFloat32(double value) {
    _number.setFloat32(0, value, Endian.little);
    var data = _number.buffer.asUint8List(0, 4);

    int b1, b2, b3, b4;
    b4 = data[0];
    b3 = data[1];
    b2 = data[2];
    b1 = data[3];

    if (_bufferPosition + 4 < _buffer.length) {
      _buffer[_bufferPosition++] = b1;
      _buffer[_bufferPosition++] = b2;
      _buffer[_bufferPosition++] = b3;
      _buffer[_bufferPosition++] = b4;
      _position += 4;
      _updateLength();
    } else {
      writeByte(b1);
      writeByte(b2);
      writeByte(b3);
      writeByte(b4);
    }
  }

  @override
  void writeFloat64(double value) {
    _number.setFloat64(0, value, Endian.little);
    var data = _number.buffer.asUint8List(0, 8);

    int b1, b2, b3, b4, b5, b6, b7, b8;
    b8 = data[0];
    b7 = data[1];
    b6 = data[2];
    b5 = data[3];
    b4 = data[4];
    b3 = data[5];
    b2 = data[6];
    b1 = data[7];

    if (_bufferPosition + 4 < _buffer.length) {
      _buffer[_bufferPosition++] = b1;
      _buffer[_bufferPosition++] = b2;
      _buffer[_bufferPosition++] = b3;
      _buffer[_bufferPosition++] = b4;
      _buffer[_bufferPosition++] = b5;
      _buffer[_bufferPosition++] = b6;
      _buffer[_bufferPosition++] = b7;
      _buffer[_bufferPosition++] = b8;
      _position += 8;
      _updateLength();
    } else {
      writeByte(b1);
      writeByte(b2);
      writeByte(b3);
      writeByte(b4);
      writeByte(b5);
      writeByte(b6);
      writeByte(b7);
      writeByte(b8);
    }
  }

  /// Write a set of bytes to the end of the buffer.
  @override
  void writeBytes(List<int> bytes, [int? len]) {
    len ??= bytes.length;
    if (_bufferPosition + len >= _buffer.length) {
      flush();

      if (_bufferPosition + len < _buffer.length) {
        for (int i = 0, j = _bufferPosition; i < len; ++i, ++j) {
          _buffer[j] = bytes[i];
        }
        _bufferPosition += len;
        _position += len;
        _updateLength();
        return;
      }
    }

    flush();
    _file.writeFrom(bytes, 0, len);
    _position += len;
    _updateLength();
  }

  /// Write the remaining data from [stream] to the stream.
  @override
  void writeInputStream(InputStreamBase stream) {
    if (stream is InputStream) {
      final len = stream.length;   // len is the number of bytes not being read.

      if (_bufferPosition + len >= _buffer.length) {
        flush();

        if (_bufferPosition + len < _buffer.length) {
          for (int i = 0, j = _bufferPosition, k = stream.offset; i < len;
               ++i, ++j, ++k) {
            _buffer[j] = stream.buffer[k];
          }
          _bufferPosition += len;
          _position += len;
          _updateLength();
          return;
        }
      }

      flush();
      _file.writeFrom(stream.buffer, stream.offset, stream.offset + len);
      _position += len;
      _updateLength();
    } else {
      var bytes = stream.toUint8List();
      writeBytes(bytes);
    }
  }

  @override
  Uint8List subset(int start, [int? end]) {
    if (_bufferPosition > 0) {
      flush();
    }

    final pos = _file.position;
    if (start < 0) {
      start = pos + start;
    }
    var length = 0;
    if (end == null) {
      end = pos;
    } else if (end < 0) {
      end = pos + end;
    }
    length = (end - start);
    _file.position = start;
    final buffer = Uint8List(length);
    _file.readInto(buffer);
    _file.position = pos;
    return buffer;
  }

  @override
  void rewind([int count = 1]) {
    if (count > _bufferPosition) {
      // out of buffer range
      flush();
      _position -= count;
      _file.position = _position;
    } else {
      // within buffer
      _bufferPosition -= count;
      _position -= count;
    }
  }

  @override
  void skip([int count = 1]) {
    if (_bufferPosition + count > _buffer.length) {
      // out of buffer
      flush();
      _position += count;
      _file.position = _position;
    } else {
      // within buffer
      _bufferPosition += count;
      _position += count;
    }
    _updateLength();
  }
}
