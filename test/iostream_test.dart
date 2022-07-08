import 'package:test/test.dart';
import 'package:wzlib/src/util/input_stream.dart';

void main() {
  group("test inputStream", (){
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
}