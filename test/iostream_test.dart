import 'package:test/test.dart';
import 'package:wzlib/src/util/util.dart';

void main() {
  group("test inputStream", () {
    test("read", (() {
      final stream = InputStream([0xff, 0xff, 0xff, 0xff]);
      expect(stream.readBoolean(), true);
      expect(stream.readByte(), 0xff);
      expect(stream.readSByte(), -1);
      expect(stream.length, equals(1));
      expect(stream.length, 1);
      expect(stream.offset, 3);
      // expect(stream.readInt16(), throwsA(isA<RangeError>()));
      stream.reset();

      expect(stream.readUint16(), 0xffff);
      expect(stream.isEOS, false);
      stream.reset();

      expect(stream.readInt16(), isNot(0xffff));
      expect(stream.readInt16(), equals(-1));
      stream.reset();

      expect(stream.readUint32(), 0xffffffff);
      stream.reset();

      expect(stream.readInt32(), -1);
      stream.rewind(4);
      expect(stream.length, 4);
    }));
  });

  group('test reading signed types', () {
    test('boolean', () {
      final bs = InputStream([
        // bool
        0x00,
        0x01,
        0x7f,
        0x80,
        0x81,
        0xff,
      ]);
      expect(bs.readBoolean(), false);
      expect(bs.readBoolean(), true);
      expect(bs.readBoolean(), true);
      expect(bs.readBoolean(), true);
      expect(bs.readBoolean(), true);
      expect(bs.readBoolean(), true);
    });

    test('int8', () {
      final i8s = InputStream([
        // signed byte
        0x00,
        0x01,
        0x7f,
        0x80,
        0x81,
        0xff,
      ]);
      expect(i8s.readSByte(), 0);
      expect(i8s.readSByte(), 1);
      expect(i8s.readSByte(), 127);
      expect(i8s.readSByte(), -128);
      expect(i8s.readSByte(), -127);
      expect(i8s.readSByte(), -1);

      i8s.reset();

      expect(i8s.readByte(), 0);
      expect(i8s.readByte(), 1);
      expect(i8s.readByte(), 127);
      expect(i8s.readByte(), 128);
      expect(i8s.readByte(), 129);
      expect(i8s.readByte(), 255);
    });

    test('int16', () {
      final i16s = InputStream([
        // signed int16
        0x00, 0x00, // 0
        0x01, 0x00, // 1
        0x7f, 0x00, // 127
        0x80, 0x00, // 128
        0x81, 0x00, // 129
        0xff, 0x00, // 255
        0x00, 0x7f, // 32512
        0x01, 0x7f, // 32513
        0x7f, 0x7f, // 32639
        0xff, 0x7f, // 32767
        0x00, 0x80, // -32768
        0x01, 0x80, // -32767
        0x81, 0x80, // -32766
        0xff, 0xff, // -1
      ]);
      expect(i16s.readInt16(), 0);
      expect(i16s.readInt16(), 1);
      expect(i16s.readInt16(), 127);
      expect(i16s.readInt16(), 128);
      expect(i16s.readInt16(), 129);
      expect(i16s.readInt16(), 255);
      expect(i16s.readInt16(), 32512);
      expect(i16s.readInt16(), 32513);
      expect(i16s.readInt16(), 32639);
      expect(i16s.readInt16(), 32767);
      expect(i16s.readInt16(), -32768);
      expect(i16s.readInt16(), -32767);
      expect(i16s.readInt16(), -32639);
      expect(i16s.readInt16(), -1);

      i16s.reset();

      expect(i16s.readUint16(), 0);
      expect(i16s.readUint16(), 1);
      expect(i16s.readUint16(), 127);
      expect(i16s.readUint16(), 128);
      expect(i16s.readUint16(), 129);
      expect(i16s.readUint16(), 255);
      expect(i16s.readUint16(), 32512);
      expect(i16s.readUint16(), 32513);
      expect(i16s.readUint16(), 32639);
      expect(i16s.readUint16(), 32767);
      expect(i16s.readUint16(), 32768);
      expect(i16s.readUint16(), 32769);
      expect(i16s.readUint16(), 32897);
      expect(i16s.readUint16(), 65535);
    });

    test('int32', () {
      final i32s = InputStream([
        // signed int32
        0x00, 0x00, 0x00, 0x00, // 0
        0x01, 0x00, 0x00, 0x00, // 1
        0x7f, 0x00, 0x7f, 0x00, // 8323199
        0x80, 0x00, 0x80, 0x00, // 8388736
        0x81, 0x00, 0x81, 0x00, // 8454273
        0xff, 0xff, 0xff, 0x00, // 16777215
        0x00, 0x7f, 0x00, 0x7f, // 2130738944
        0x01, 0x7f, 0x01, 0x7f, // 2130804481
        0xfe, 0xff, 0xff, 0x7f, // 2147483646
        0xff, 0xff, 0xff, 0x7f, // 2147483647
        0x00, 0x00, 0x00, 0x80, // -2147483648
        0x01, 0x00, 0x00, 0x80, // -2147483647
        0x81, 0x80, 0x00, 0x80, // -2147450751
        0xff, 0xff, 0xff, 0xff, // -1
      ]);
      expect(i32s.readInt32(), 0);
      expect(i32s.readInt32(), 1);
      expect(i32s.readInt32(), 8323199);
      expect(i32s.readInt32(), 8388736);
      expect(i32s.readInt32(), 8454273);
      expect(i32s.readInt32(), 16777215);
      expect(i32s.readInt32(), 2130738944);
      expect(i32s.readInt32(), 2130804481);
      expect(i32s.readInt32(), 2147483646);
      expect(i32s.readInt32(), 2147483647);
      expect(i32s.readInt32(), -2147483648);
      expect(i32s.readInt32(), -2147483647);
      expect(i32s.readInt32(), -2147450751);
      expect(i32s.readInt32(), -1);

      i32s.reset();

      expect(i32s.readUint32(), 0);
      expect(i32s.readUint32(), 1);
      expect(i32s.readUint32(), 8323199);
      expect(i32s.readUint32(), 8388736);
      expect(i32s.readUint32(), 8454273);
      expect(i32s.readUint32(), 16777215);
      expect(i32s.readUint32(), 2130738944);
      expect(i32s.readUint32(), 2130804481);
      expect(i32s.readUint32(), 2147483646);
      expect(i32s.readUint32(), 2147483647);
      expect(i32s.readUint32(), 2147483648);
      expect(i32s.readUint32(), 2147483649);
      expect(i32s.readUint32(), 2147516545);
      expect(i32s.readUint32(), 4294967295);
    });

    test('int64', () {
      final i64s = InputStream([
        // signed int64
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, // 0
        0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, // 1
        0x7f, 0x00, 0x7f, 0x00, 0x7f, 0x00, 0x7f, 0x00, // 35747867511423103
        0x80, 0x00, 0x80, 0x00, 0x80, 0x00, 0x80, 0x00, // 36029346783166592
        0x81, 0x00, 0x81, 0x00, 0x81, 0x00, 0x81, 0x00, // 36310826054910081
        0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0x00, // 72057594037927935
        0x00, 0x7f, 0x00, 0x7f, 0x00, 0x7f, 0x00, 0x7f, // 9151454082924314368
        0x01, 0x7f, 0x01, 0x7f, 0x01, 0x7f, 0x01, 0x7f, // 9151735562196057857
        0xfe, 0xff, 0xff, 0x7f, 0xfe, 0xff, 0xff, 0x7f, // 9223372030412324862
        0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0x7f, // 9223372036854775807
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x80, // -9223372036854775808
        0x01, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x80, // -9223372032559808511
        0x81, 0x80, 0x00, 0x80, 0x81, 0x80, 0x00, 0x80, // -9223230743168122751
        0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, // -1
      ]);
      expect(i64s.readInt64(), 0);
      expect(i64s.readInt64(), 1);
      expect(i64s.readInt64(), 35747867511423103);
      expect(i64s.readInt64(), 36029346783166592);
      expect(i64s.readInt64(), 36310826054910081);
      expect(i64s.readInt64(), 72057594037927935);
      expect(i64s.readInt64(), 9151454082924314368);
      expect(i64s.readInt64(), 9151735562196057857);
      expect(i64s.readInt64(), 9223372030412324862);
      expect(i64s.readInt64(), 9223372036854775807);
      expect(i64s.readInt64(), -9223372036854775808);
      expect(i64s.readInt64(), -9223372032559808511);
      expect(i64s.readInt64(), -9223230743168122751);
      expect(i64s.readInt64(), -1);

      i64s.reset();

      expect(i64s.readUint64(), 0);
      expect(i64s.readUint64(), 1);
      expect(i64s.readUint64(), 35747867511423103);
      expect(i64s.readUint64(), 36029346783166592);
      expect(i64s.readUint64(), 36310826054910081);
      expect(i64s.readUint64(), 72057594037927935);
      expect(i64s.readUint64(), 9151454082924314368);
      expect(i64s.readUint64(), 9151735562196057857);
      expect(i64s.readUint64(), 9223372030412324862);
      expect(i64s.readUint64(), 9223372036854775807);
      expect(i64s.readUint64(), -9223372036854775808);
      expect(i64s.readUint64(), -9223372032559808511);
      expect(i64s.readUint64(), -9223230743168122751);
      expect(i64s.readUint64(), -1);
    });
  });
}
