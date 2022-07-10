part of wzlib;

abstract class WzSimpleProperty extends WzImageProperty {
  WzSimpleProperty(String name, [Object? value, WzObject? parent]) : super(name, value, parent);

  @override
  WzObject? operator [](String name) => throw UnimplementedError('WzSimpleProperty Not supported');

  @override
  List<WzImageProperty> get wzProperties => throw UnimplementedError('WzSimpleProperty Not supported');

  /// Nothing to dispose
  @override
  void dispose() {}
}

abstract class WzNumberProperty extends WzSimpleProperty {
  num value = 0;

  @override
  num get wzValue => value;

  @override
  set wzValue(Object value) => wzValue = value; // todo ????

  WzNumberProperty(String name, [this.value = 0, WzObject? parent]) : super(name, value, parent);

  int GetShort() => value.toInt();

  int GetInt() => value.toInt();

  int GetLong() => value.toInt();

  double GetFloat() => value.toDouble();

  double GetDouble() => value.toDouble();

  String GetString() => value.toString();

  @override
  String toString() => '{$name: $value}';
}

class WzShortProperty extends WzNumberProperty {
  static const int _prefixByte = 0x02;

  @override
  WzPropertyType get propertyType => WzPropertyType.Short;

  WzShortProperty(String name, [int value = 0, WzObject? parent]) : super(name, value, parent);

  @override
  void writeValue(WzBinaryWriter writer) {
    writer.WriteByte(_prefixByte);
    writer.WriteInt16(value.toInt());
  }

  @override
  WzShortProperty deepClone() {
    return WzShortProperty(name, value as int);
  }
}

class WzIntProperty extends WzNumberProperty {
  static const int _prefixByte = 0x03;

  @override
  WzPropertyType get propertyType => WzPropertyType.Int;

  WzIntProperty(String name, [int value = 0, WzObject? parent]) : super(name, value, parent);

  @override
  void writeValue(WzBinaryWriter writer) {
    writer.WriteByte(_prefixByte);
    writer.WriteCompressedInt(
        value.toInt()); // todo: test toInt() vs as int: 'num a = 3; a as int; a.toInt(); if(a is int)...'
  }

  @override
  WzIntProperty deepClone() {
    return WzIntProperty(name, value as int);
  }
}

class WzLongProperty extends WzNumberProperty {
  static const int _prefixByte = 0x14; // = 20

  @override
  WzPropertyType get propertyType => WzPropertyType.Long;

  WzLongProperty(String name, [int value = 0, WzObject? parent]) : super(name, value, parent);

  @override
  void writeValue(WzBinaryWriter writer) {
    writer.WriteByte(_prefixByte);
    writer.WriteCompressedLong(value.toInt());
  }

  @override
  WzLongProperty deepClone() {
    return WzLongProperty(name, value as int);
  }
}

class WzFloatProperty extends WzNumberProperty {
  static const int _prefixByte = 0x04;

  @override
  WzPropertyType get propertyType => WzPropertyType.Float;

  WzFloatProperty(String name, [double value = .0, WzObject? parent]) : super(name, value, parent);

  @override
  void writeValue(WzBinaryWriter writer) {
    writer.WriteByte(_prefixByte);
    if (value == .0) {
      // todo: test 0 == .0 ???
      writer.WriteByte(0);
    } else {
      writer.WriteByte(0x80);
      writer.WriteSingle(value.toDouble());
    }
  }

  @override
  WzFloatProperty deepClone() {
    return WzFloatProperty(name, value as double);
  }
}

class WzDoubleProperty extends WzNumberProperty {
  static const int _prefixByte = 0x05;

  @override
  WzPropertyType get propertyType => WzPropertyType.Double;

  WzDoubleProperty(String name, [double value = .0, WzObject? parent]) : super(name, value, parent);

  @override
  void writeValue(WzBinaryWriter writer) {
    writer.WriteByte(_prefixByte);
    writer.WriteDouble(value.toDouble());
  }

  @override
  WzDoubleProperty deepClone() {
    return WzDoubleProperty(name, value as double);
  }
}

class WzNullProperty extends WzSimpleProperty {
  @override
  Object wzValue = 0;

  @override
  WzPropertyType get propertyType => WzPropertyType.Null;

  WzNullProperty(String name, [WzObject? parent]) : super(name, 0, parent);

  @override
  void writeValue(WzBinaryWriter writer) {
    writer.WriteByte(0x00);
  }

  @override
  WzNullProperty deepClone() {
    return WzNullProperty(name);
  }

  @override
  String toString() => '{$name: null}';
}

class WzStringProperty extends WzSimpleProperty {
  static const int _prefixByte = 0x08;
  String value = '';

  @override
  Object get wzValue => value;

  @override
  set wzValue(Object val) => value = val.toString();

  @override
  WzPropertyType get propertyType => WzPropertyType.String;

  WzStringProperty(String name, [this.value = '', WzObject? parent]) : super(name, value, parent);

  @override
  WzStringProperty deepClone() {
    return WzStringProperty(name, value);
  }

  @override
  void writeValue(WzBinaryWriter writer) {
    writer.WriteByte(_prefixByte);
    writer.WriteStringValue(value, 0, 1);
  }

  int GetShort() => int.tryParse(value) ?? 0;

  int GetInt() => int.tryParse(value) ?? 0;

  int GetLong() => int.tryParse(value) ?? 0;

  double GetFloat() => double.tryParse(value) ?? .0;

  double GetDouble() => double.tryParse(value) ?? .0;

  String GetString() => value;

  @override
  String toString() => '{$name: $value}';
}
