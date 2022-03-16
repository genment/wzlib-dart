import 'dart:typed_data';

import '../wz_types.dart';
import '../wz_object.dart';
import '../crypto/wz_keys.dart';
import '../util/wz_binary_writer.dart';
import 'base_property.dart';

class WzLuaProperty extends WzImageProperty {
  //#region Fields
  Uint8List? _encryptedBytes;
  late final WzMutableKey wzKey;

  //#endregion

  //#region Fields (override)
  @override
  Uint8List get wzValue => _encryptedBytes!;

  @override
  set wzValue(Object value) => _encryptedBytes = value as Uint8List;

  @override
  WzPropertyType get propertyType => WzPropertyType.Lua;

  /// Not available
  @override
  List<WzImageProperty> get wzProperties =>
      throw UnimplementedError('WzLuaProperty has no sub properties');

  //#endregion

  //#region Constructors
  WzLuaProperty(String name,
      [this._encryptedBytes, WzObject? parent, WzMutableKey? key])
      : super(name, parent) {
    wzKey = key ?? WzKeyGenerator.GenerateLuaWzKey();
  }

  //#endregion

  //#region Methods

  /// Encodes or decoded a selected chunk of bytes with the xor encryption used with lua property.
  ///
  /// Note: encoding and decoding are exactly the same process for XOR
  Uint8List EncodeDecode(Uint8List input) {
    var newArray = Uint8List(input.length);
    for (var i = 0; i < input.length; i++) {
      // TODO: Why is it wzKey[i]??? Won't it cause IndexOutOfBounds error?
      var encryptedChar = (input[i] ^ wzKey[i]);
      newArray[i] = encryptedChar;
    }
    return newArray;
  }

  String getString() {
    var decoded = EncodeDecode(_encryptedBytes!);
    return String.fromCharCodes(decoded); // TODO: not sure if this works
  }

  //#endregion

  //#region Methods (override)

  @override
  WzImageProperty operator [](String name) {
    throw UnimplementedError('WzLuaProperty has no sub properties');
  }

  @override
  void writeValue(WzBinaryWriter writer) {
    writer.WriteByte(0x01);
    writer.WriteCompressedInt(_encryptedBytes!.length);
    writer.WriteBytes(_encryptedBytes!);
  }

  @override
  WzImageProperty deepClone() {
    var copy = Uint8List.fromList(_encryptedBytes!);
    return WzLuaProperty(name, copy);
  }

  @override
  String toString() {
    return getString();
  }

  @override
  void dispose() {
    _encryptedBytes = null;
  }

//#endregion

}
