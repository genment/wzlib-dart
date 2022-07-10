import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:wzlib/wzlib.dart';

void main({String basePath = 'test_output'}) {
  group('wzfile', () {
    test('create empty file', () {
      final filename = p.join(basePath, 'TestCreation.wz');
      var wzfile = WzFile.createNew(1, WzMapleVersion.BMS);
      wzfile.SaveToDisk(filename);
      wzfile.dispose();
      expect(File(filename).existsSync(), isTrue);
    });

    test('create with one image and properties', () {
      final filename = p.join(basePath, "test_with_image.wz");

      var wzfile = WzFile.createNew(1, WzMapleVersion.BMS);
      wzfile.wzDir.AddImage(WzImage("test.img")
        ..AddProperty(
          WzStringProperty("test_name", "test_string"),
        )
        ..AddProperties([
          WzIntProperty("test_int_prop", 9999),
          WzLongProperty("test_long_prop", 999999999999),
          WzShortProperty("test_short_prop", -1),
          WzFloatProperty("test_float_prop", 9.99),
          WzDoubleProperty("test_double_prop", 9.999999999999999999999999),
          WzSubProperty("test_SUB_prop")
            ..AddProperty(
                WzStringProperty("test_SUB_prop_str", "string under sub prop"))
            ..AddProperties([
              WzSubProperty("test_SUB_SUB_prop")
                ..AddProperty(WzStringProperty(
                    "test_SUB_SUB_prop_str", "string under sub sub prop"))
                ..AddProperties([
                  WzIntProperty("test_SUB_SUB_int_prop", 9999),
                  WzLongProperty("test_SUB_SUB_long_prop", 999999999999),
                  WzShortProperty("test_SUB_SUB_short_prop", 0xFFF),
                  WzFloatProperty("test_SUB_SUB_float_prop", 9.99),
                  WzDoubleProperty("test_SUB_SUB_double_prop", 9.999999999999999999999999),
                  WzVectorProperty("test_SUB_SUB_vector_prop", WzIntProperty('RANDOM_X', 222), WzIntProperty('RANDOM_Y', 333))
                ])
            ])
        ]));
      wzfile.SaveToDisk(filename);
      wzfile.dispose();
      expect(File("test_output/test_with_image.wz").existsSync(), isTrue);
    });

    test('read created file', () {
      final filename = p.join(basePath, "test_with_image.wz");

      expect(File(filename).existsSync(), isTrue);
      var wzfile = WzFile.fromFile(filename, WzMapleVersion.BMS);
      wzfile.ParseMainWzDirectory();
      expect(wzfile.wzDir.wzImages.length, 1);

      var testimg = wzfile.wzDir['test.img'];
      expect(testimg, isNotNull);
      expect(wzfile.wzDir.wzImages[0], testimg);
      testimg = testimg!;

      expect(testimg.name, 'test.img');
      expect(testimg.fullPath, 'test_with_image.wz\\test.img');
      expect(testimg.parent, wzfile.wzDir);
      expect(testimg.wzFileParent, wzfile);

      var stringProp = testimg['test_name'] as WzStringProperty;
      expect(stringProp, isA<WzStringProperty>());
      expect(stringProp.value, 'test_string');

      var intProp = testimg['test_int_prop'] as WzIntProperty;
      expect(intProp, isA<WzIntProperty>());
      expect(intProp.value, 9999);

      var longProp = testimg['test_long_prop'] as WzLongProperty;
      expect(longProp, isA<WzLongProperty>());
      expect(longProp.value, 999999999999);

      var shortProp = testimg['test_short_prop'] as WzShortProperty;
      expect(shortProp, isA<WzShortProperty>());
      expect(shortProp.value, -1);

      var floatProp = testimg['test_float_prop'] as WzFloatProperty;
      expect(floatProp, isA<WzFloatProperty>());
      expect(floatProp.value, closeTo(9.99, 0.001));

      var doubleProp = testimg['test_double_prop'] as WzDoubleProperty;
      expect(doubleProp, isA<WzDoubleProperty>());
      expect(doubleProp.value, 9.999999999999999999999999);

      var subProp = testimg['test_SUB_prop'] as WzSubProperty;
      expect(subProp, isA<WzSubProperty>());
      expect(subProp.wzProperties.length, 2);

      // inside subProp
      stringProp = subProp['test_SUB_prop_str'] as WzStringProperty;
      expect(stringProp.value, 'string under sub prop');

      subProp = subProp['test_SUB_SUB_prop'] as WzSubProperty;

      // inside sub subProp
      expect((subProp['test_SUB_SUB_prop_str'] as WzStringProperty).value, 'string under sub sub prop');
      expect((subProp['test_SUB_SUB_int_prop'] as WzIntProperty).value, 9999);
      expect((subProp['test_SUB_SUB_long_prop'] as WzLongProperty).value, 999999999999);
      expect((subProp['test_SUB_SUB_short_prop'] as WzShortProperty).value, 0xFFF);
      expect((subProp['test_SUB_SUB_float_prop'] as WzFloatProperty).value, closeTo(9.99, 0.001));
      expect((subProp['test_SUB_SUB_double_prop'] as WzDoubleProperty).value, 9.999999999999999999999999);
      var vecProp = subProp['test_SUB_SUB_vector_prop'] as WzVectorProperty;
      expect(vecProp.x.name, isNot('RANDOM_X'));
      expect(vecProp.y.name, isNot('RANDOM_Y'));
      expect(vecProp.x.name, 'X');
      expect(vecProp.y.name, 'Y');
      expect(vecProp.x.value, 222);
      expect(vecProp.y.value, 333);

      wzfile.dispose();
    });
  });
}