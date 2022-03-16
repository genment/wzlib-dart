import 'dart:collection';
import 'dart:typed_data';

import '../crypto/wz_keys.dart';
import '../wz_types.dart';

class WzTool {
  static var StringCache = HashMap();

  static int RotateLeft(int x, int n) {
    return ((x) << (n) | (x) >> (32 - (n))) & 0xFFFFFFFF;
  }

  static int RotateRight(int x, int n) {
    return ((x) >> (n) | (x) << (32 - (n))) & 0xFFFFFFFF;
  }

  static int GetCompressedIntLength(int i) {
    if (i > 127 || i < -127) {
      return 5;
    }
    return 1;
  }

  static int GetEncodedStringLength(String? s) {
    var len = 0;
    if (s == null || s.isEmpty) {
      return 1;
    }
    var unicode = false;
    for (var c in s.codeUnits) {
      if (c > 255) {
        unicode = true;
      }
    }
    if (unicode) {
      if (s.length > 126) {
        len += 5;
      } else {
        len += 1;
      }
      len += s.length * 2;
    } else {
      if (s.length > 127) {
        len += 5;
      } else {
        len += 1;
      }
      len += s.length;
    }
    return len;
  }

  static int GetWzObjectValueLength(String s, int type) {
    var storeName = '${type}_$s';
    if (s.length > 4 && StringCache.containsKey(storeName)) {
      return 5;
    } else {
      StringCache[storeName] = 1;
      return 1 + GetEncodedStringLength(s);
    }
  }

  static T StringToEnum<T>(String name) {
    throw UnimplementedError();
  }

  /// <summary>
  /// Get WZ encryption IV from maple version
  /// </summary>
  /// <param name="ver"></param>
  /// <param name="fallbackCustomIv">The custom bytes to use as IV</param>
  /// <returns></returns>
  static Uint8List GetIvByMapleVersion(WzMapleVersion ver) {
    switch (ver) {
      case WzMapleVersion.EMS:
        return Constants.WZ_MSEAIV; //?
      case WzMapleVersion.GMS:
        return Constants.WZ_GMSIV;
      // case WzMapleVersion.CUSTOM: // custom WZ encryption bytes from stored app setting
      //   {
      //     ConfigurationManager config = new ConfigurationManager();
      //     return config.GetCusomWzIVEncryption(); // fallback with BMS
      //   }
      case WzMapleVersion.GENERATE: // dont fill anything with GENERATE, it is not supposed to load anything
      case WzMapleVersion.BMS:
      case WzMapleVersion.CLASSIC:
      default:
        return Uint8List(4);
    }
  }

  // static const int WzHeader = 0x31474B50; //PKG1

  static bool IsListFile(String path) {
    throw UnimplementedError();
  }

  /// <summary>
  /// Checks if the input file is Data.wz hotfix file [not to be mistaken for Data.wz for pre v4x!]
  /// </summary>
  /// <param name="path"></param>
  /// <returns></returns>
  static bool IsDataWzHotfixFile(String path) {
    throw UnimplementedError();
  }
}
