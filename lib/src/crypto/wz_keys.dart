import 'dart:io';
import 'dart:typed_data';
import 'package:encrypt/encrypt.dart';

class WzMutableKey {
  static const int _batchSize = 4096;
  late final Uint8List _iv;
  late final Uint8List _aesUserKey;
  Uint8List? _keys;

  WzMutableKey(this._iv, this._aesUserKey);

  int operator [](int index) {
    if (_keys == null || _keys!.length <= index) {
      ensureKeySize(index + 1);
    }
    return _keys![index];
  }

  void ensureKeySize(int size) {
    if (_keys != null && _keys!.length >= size) return;

    size = (1.0 * size / _batchSize).ceil() * _batchSize;
    var newKeys = Uint8List(size);

    if (_iv.buffer.asByteData().getInt32(0) == 0) {
      _keys = newKeys;
      return;
    }

    var startIndex = 0;

    if (_keys != null) {
      newKeys.setAll(0, _keys!);
      startIndex = _keys!.length;
    }

    var zeroIv = IV(Uint8List(0)); // ECB mode does not use IV.
    final aes = AES(Key(_aesUserKey), mode: AESMode.ecb);

    Uint8List encrypted;

    // Encrypted [block] is the first 16 bytes (iv * 4) of the keys.
    // From 17 to size-1 bytes, every 16-byte block is encrypted from the previous block.
    if (startIndex == 0) {
      var block = Uint8List.fromList([..._iv, ..._iv, ..._iv, ..._iv]);
      encrypted = aes.encrypt(block, iv: zeroIv).bytes;
      newKeys.setRange(0, 16, encrypted);
      startIndex += 16;
    } else {
      encrypted = newKeys.sublist(startIndex - 16, startIndex);
    }

    for (var i = startIndex; i < size; i += 16) {
      encrypted = aes.encrypt(encrypted, iv: zeroIv).bytes;
      newKeys.setRange(i, i + 16, encrypted);
    }

    _keys = newKeys;
  }
}

class WzKeyGenerator {
  static Uint8List GetIvFromZlz(RandomAccessFile zlzFile) {
    zlzFile.setPositionSync(0x10040);
    return zlzFile.readSync(4);
  }

  static Uint8List _GetAesKeyFromZlz(RandomAccessFile zlzFile) {
    throw UnimplementedError('Not Used');
  }

  /// <summary>
  /// Generates the WZ Key for .Lua property
  /// </summary>
  /// <returns></returns>
  static WzMutableKey GenerateLuaWzKey() {
    return WzMutableKey(Constants.WZ_MSEAIV,
        Constants.GetTrimmedUserKey(Constants.MAPLESTORY_USERKEY_DEFAULT));
  }

  static WzMutableKey generateWzKey(Uint8List wzIv) {
    return WzMutableKey(
        wzIv, Constants.GetTrimmedUserKey(Constants.UserKey_WzLib));
  }
}

class Constants {

  /// <summary>
  /// Default AES UserKey used by MapleStory
  /// This key may be replaced with custom bytes by the user. (private server)
  /// </summary>
  static Uint8List MAPLESTORY_USERKEY_DEFAULT = Uint8List.fromList([ // 16 * 8
    0x13, 0x00, 0x00, 0x00, 0x52, 0x00, 0x00, 0x00, 0x2A, 0x00, 0x00, 0x00, 0x5B, 0x00, 0x00, 0x00,
    0x08, 0x00, 0x00, 0x00, 0x02, 0x00, 0x00, 0x00, 0x10, 0x00, 0x00, 0x00, 0x60, 0x00, 0x00, 0x00,
    0x06, 0x00, 0x00, 0x00, 0x02, 0x00, 0x00, 0x00, 0x43, 0x00, 0x00, 0x00, 0x0F, 0x00, 0x00, 0x00,
    0xB4, 0x00, 0x00, 0x00, 0x4B, 0x00, 0x00, 0x00, 0x35, 0x00, 0x00, 0x00, 0x05, 0x00, 0x00, 0x00,
    0x1B, 0x00, 0x00, 0x00, 0x0A, 0x00, 0x00, 0x00, 0x5F, 0x00, 0x00, 0x00, 0x09, 0x00, 0x00, 0x00,
    0x0F, 0x00, 0x00, 0x00, 0x50, 0x00, 0x00, 0x00, 0x0C, 0x00, 0x00, 0x00, 0x1B, 0x00, 0x00, 0x00,
    0x33, 0x00, 0x00, 0x00, 0x55, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x09, 0x00, 0x00, 0x00,
    0x52, 0x00, 0x00, 0x00, 0xDE, 0x00, 0x00, 0x00, 0xC7, 0x00, 0x00, 0x00, 0x1E, 0x00, 0x00, 0x00
  ]);

  /// <summary>
  /// The default AES UserKey to be used by HaRepacker or HaCreator.
  /// </summary>
  static Uint8List UserKey_WzLib = MAPLESTORY_USERKEY_DEFAULT;

  /// <summary>
  /// Determines if 'UserKey_WzLib' to be used by HaRepacker/ HaCreator is equivalent to the default Maplestory User Key.
  /// </summary>
  /// <returns></returns>
  static bool IsDefaultMapleStoryUserKey() {
    bool listEquals<T>(List<T>? a, List<T>? b) {
      if (a == null) return b == null;
      if (b == null || a.length != b.length) return false;
      if (identical(a, b)) return true;
      for (int index = 0; index < a.length; index += 1) {
        if (a[index] != b[index]) return false;
      }
      return true;
    }

    return listEquals(MAPLESTORY_USERKEY_DEFAULT, UserKey_WzLib);
  }

  /// <summary>
  /// ShuffleBytes used by MapleStory to generate a new IV
  /// </summary>
  static Uint8List bShuffle = Uint8List.fromList([ // 16 * 16
    0xEC, 0x3F, 0x77, 0xA4, 0x45, 0xD0, 0x71, 0xBF, 0xB7, 0x98, 0x20, 0xFC, 0x4B, 0xE9, 0xB3, 0xE1,
    0x5C, 0x22, 0xF7, 0x0C, 0x44, 0x1B, 0x81, 0xBD, 0x63, 0x8D, 0xD4, 0xC3, 0xF2, 0x10, 0x19, 0xE0,
    0xFB, 0xA1, 0x6E, 0x66, 0xEA, 0xAE, 0xD6, 0xCE, 0x06, 0x18, 0x4E, 0xEB, 0x78, 0x95, 0xDB, 0xBA,
    0xB6, 0x42, 0x7A, 0x2A, 0x83, 0x0B, 0x54, 0x67, 0x6D, 0xE8, 0x65, 0xE7, 0x2F, 0x07, 0xF3, 0xAA,
    0x27, 0x7B, 0x85, 0xB0, 0x26, 0xFD, 0x8B, 0xA9, 0xFA, 0xBE, 0xA8, 0xD7, 0xCB, 0xCC, 0x92, 0xDA,
    0xF9, 0x93, 0x60, 0x2D, 0xDD, 0xD2, 0xA2, 0x9B, 0x39, 0x5F, 0x82, 0x21, 0x4C, 0x69, 0xF8, 0x31,
    0x87, 0xEE, 0x8E, 0xAD, 0x8C, 0x6A, 0xBC, 0xB5, 0x6B, 0x59, 0x13, 0xF1, 0x04, 0x00, 0xF6, 0x5A,
    0x35, 0x79, 0x48, 0x8F, 0x15, 0xCD, 0x97, 0x57, 0x12, 0x3E, 0x37, 0xFF, 0x9D, 0x4F, 0x51, 0xF5,
    0xA3, 0x70, 0xBB, 0x14, 0x75, 0xC2, 0xB8, 0x72, 0xC0, 0xED, 0x7D, 0x68, 0xC9, 0x2E, 0x0D, 0x62,
    0x46, 0x17, 0x11, 0x4D, 0x6C, 0xC4, 0x7E, 0x53, 0xC1, 0x25, 0xC7, 0x9A, 0x1C, 0x88, 0x58, 0x2C,
    0x89, 0xDC, 0x02, 0x64, 0x40, 0x01, 0x5D, 0x38, 0xA5, 0xE2, 0xAF, 0x55, 0xD5, 0xEF, 0x1A, 0x7C,
    0xA7, 0x5B, 0xA6, 0x6F, 0x86, 0x9F, 0x73, 0xE6, 0x0A, 0xDE, 0x2B, 0x99, 0x4A, 0x47, 0x9C, 0xDF,
    0x09, 0x76, 0x9E, 0x30, 0x0E, 0xE4, 0xB2, 0x94, 0xA0, 0x3B, 0x34, 0x1D, 0x28, 0x0F, 0x36, 0xE3,
    0x23, 0xB4, 0x03, 0xD8, 0x90, 0xC8, 0x3C, 0xFE, 0x5E, 0x32, 0x24, 0x50, 0x1F, 0x3A, 0x43, 0x8A,
    0x96, 0x41, 0x74, 0xAC, 0x52, 0x33, 0xF0, 0xD9, 0x29, 0x80, 0xB1, 0x16, 0xD3, 0xAB, 0x91, 0xB9,
    0x84, 0x7F, 0x61, 0x1E, 0xCF, 0xC5, 0xD1, 0x56, 0x3D, 0xCA, 0xF4, 0x05, 0xC6, 0xE5, 0x08, 0x49
  ]);

  /// <summary>
  /// Default AES Key used to generate a new IV
  /// </summary>
  static Uint8List bDefaultAESKeyValue = Uint8List.fromList([ // 16 bytes
    0xC6, 0x50, 0x53, 0xF2, 0xA8, 0x42, 0x9D, 0x7F, 0x77, 0x09, 0x1D, 0x26, 0x42, 0x53, 0x88, 0x7C,
  ]);

  /// <summary>
  /// IV used to create the WzKey for GMS
  /// </summary>
  static Uint8List WZ_GMSIV = Uint8List.fromList([0x4D, 0x23, 0xC7, 0x2B]);

  /// <summary>
  /// IV used to create the WzKey for the latest version of GMS, MSEA, or KMS
  /// </summary>
  static Uint8List WZ_MSEAIV = Uint8List.fromList([0xB9, 0x7D, 0x63, 0xE9]);

  /// <summary>
  /// Constant used in WZ offset encryption
  /// </summary>
  static int WZ_OffsetConstant = 0x581C3F6D;

  /// <summary>
  /// Trims the AES UserKey (x128 bytes -> x32 bytes) for use an AES cryptor
  /// <paramref name="UserKey">The UserKey to use to create the trimmed key.</paramref>
  /// </summary>
  static Uint8List GetTrimmedUserKey(Uint8List UserKey) {
    var key = Uint8List(32);
    for (var i = 0; i < 128; i += 16) {
      key[i ~/ 4] = UserKey[i]; // the userkey to use by WzLib.
    }
    return key;
  }
}
