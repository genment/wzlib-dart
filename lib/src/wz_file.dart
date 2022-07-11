part of wzlib;

class WzFile extends WzObject {
  // var logger = Logger(output: MultiOutput([ConsoleOutput(), StreamOutput()]));

  //region Fields

  /// [filePath] can be null if WzFile is created in memory, and not saved to disk yet.
  String? filePath;

  WzHeader header = WzHeader();
  late WzDirectory wzDir; // top level directory (same name as wzfile)

  late Uint8List wzIv;

  int wzVersionHeader = 0; // ???
  static const int wzVersionHeader64bit = 777;
  int versionHash = 0;

  /// like GMSv230, where 230 is a version
  int Version = -1;

  /// GMS/KMS/CMS..
  WzMapleVersion mapleLocalVersion = WzMapleVersion.UNKNOWN;
  bool missingEncVer = false;

  //endregion

  //region Fields (override)

  @override
  WzObjectType get objectType => WzObjectType.File;

  @override
  WzFile get wzFileParent => this;

  //endregion

  //region Constructors

  /// Create a new WzFile Object
  WzFile.createNew(this.Version, this.mapleLocalVersion) {
    wzIv = WzTool.GetIvByMapleVersion(mapleLocalVersion);
    wzDir = WzDirectory(name, this);
    header = WzHeader();
  }

  /// Open a wz file from a file on the disk
  WzFile.fromFile(this.filePath, this.mapleLocalVersion, [this.Version = -1, autoParse = false]) {
    name = p.basename(filePath!);

    if (mapleLocalVersion == WzMapleVersion.GETFROMZLZ) {
      throw UnimplementedError('Not support yet');
    }

    wzIv = WzTool.GetIvByMapleVersion(mapleLocalVersion);

    if (autoParse) ParseMainWzDirectory();
  }

  /// Open a wz file from a file on the disk with a custom WzIv key
  WzFile.fromFileWithCustomKey(this.filePath, this.wzIv, [bool autoParse = false]) {
    name = p.basename(filePath!);
    mapleLocalVersion = WzMapleVersion.CUSTOM;

    if (autoParse && !ParseMainWzDirectory()) {
      throw Exception('parse WzDirectory fail');
    }
  }

  //endregion

  //region Methods

  /// Parse WzFile
  ///
  /// If a different [wzIv] is given, update and use the new [wzIv],
  /// else use the existing one.
  bool ParseWzFile(Uint8List? wzIv) {
    if (wzIv != null) {
      this.wzIv = wzIv;
    }
    return ParseMainWzDirectory();
  }

  bool ParseMainWzDirectory() {
    if (filePath == null) {
      // logger.e('Path is null');
      return false;
    }

    var reader = WzBinaryReader(InputFileStream(filePath!), wzIv);

    header.ident = reader.ReadPlainString(4);
    header.fsize = reader.ReadUInt64();
    header.fstart = reader.ReadUInt32();
    header.copyright = reader.ReadPlainString(header.fstart - 17);

    reader.ReadByte(); // unknown byte
    reader.ReadBytes(header.fstart - reader.position); // unknown bytes (if exists)
    reader.Header = header;

    checkMissingEncVer(reader);

    // the value of wzVersionHeader is less important. It is used for reading/writing from/to WzFile Header, and calculating the versionHash.
    // it can be any number if the client is 64-bit. Assigning 777 is just for convenience when calculating the versionHash.
    wzVersionHeader = missingEncVer ? wzVersionHeader64bit : reader.ReadUInt16();

    if (Version == -1) {
      // for 64-bit client, return immediately if version 777 works correctly.
      if (missingEncVer && TryDecodeWithWZVersionNumber(reader, wzVersionHeader, wzVersionHeader64bit)) {
        return true;
      }

      var start = missingEncVer ? wzVersionHeader64bit : 0;

      // this step is actually not needed if we know the maplestory patch version (the client .exe), but since we dont..
      // we'll need a bruteforce way around it.
      const MAX_PATCH_VERSION = 1000; // wont be reached for the forseeable future.

      for (var j = start; j < MAX_PATCH_VERSION; j++) {
        if (TryDecodeWithWZVersionNumber(reader, wzVersionHeader, j)) {
          return true;
        }
      }
      //parseErrorMessage = "Error with game version hash : The specified game version is incorrect and WzLib was unable to determine the version itself";
      return false;
    } else {
      versionHash = CheckAndGetVersionHash(wzVersionHeader, Version);
      reader.Hash = versionHash;
      wzDir = WzDirectory(name, this, reader, versionHash, wzIv)..ParseDirectory();
    }
    return true;
  }

  void checkMissingEncVer(WzBinaryReader reader) {
    if (header.fsize >= 2) {
      wzVersionHeader = reader.ReadUInt16();
      if (wzVersionHeader > 0xff) {
        missingEncVer = true;
      } else if (wzVersionHeader == 0x80) {
        // there's an exceptional case that the first field of data part is a compressed int which determines the property count,
        // if the value greater than 127 and also to be a multiple of 256, the first 5 bytes will become to
        // 80 00 xx xx xx
        // so we additional check the int value, at most time the child node count in a WzFile won't greater than 65536 (0xFFFF).
        if (header.fsize >= 5) {
          reader.position = header.fstart; // go back to 0x3C
          var propCount = reader.readCompressedInt();
          if (propCount > 0 && (propCount & 0xFF) == 0 && propCount <= 0xFFFF) {
            missingEncVer = true;
          }
        }
      }
    } else {
      // Obviously, if data part have only 1 byte, encVer must be deleted.
      missingEncVer = true;
    }

    // reset position
    reader.position = header.fstart;
  }

  bool TryDecodeWithWZVersionNumber(WzBinaryReader reader, int useWzVersionHeader, int useMapleStoryPatchVersion) {
    Version = useMapleStoryPatchVersion;

    versionHash = CheckAndGetVersionHash(useWzVersionHeader, useMapleStoryPatchVersion);
    if (versionHash == 0) {
      return false;
    }

    reader.Hash = versionHash;
    // save position to rollback to, if should parsing fail from here
    var fallbackOffsetPosition = reader.position;
    WzDirectory testDirectory;
    try {
      testDirectory = WzDirectory(name, this, reader, versionHash, wzIv)..ParseDirectory();
    } on Exception catch (_, exp) {
      // logger.d(exp.toString());

      reader.position = fallbackOffsetPosition;
      return false;
    }

    // test the image and see if its correct by parsing it
    var bCloseTestDirectory = true;
    try {
      var testImage = testDirectory.wzImages.firstOrNull;
      if (testImage != null) {
        try {
          reader.position = testImage.offset;
          var checkByte = reader.ReadByte();
          reader.position = fallbackOffsetPosition;

          switch (checkByte) {
            case 0x73:
            case 0x1b:
              {
                wzDir = WzDirectory(name, this, reader, versionHash, wzIv)..ParseDirectory();
                return true;
              }
            case 0x30:
            case 0x6C: // idk
            case 0xBC: // Map002.wz? KMST?
            default:
              {
                // logger.e('[WzFile.cs] New Wz image header found. checkByte = $checkByte. File Name = $name');
                // log or something
                break;
              }
          }
          reader.position = fallbackOffsetPosition; // reset
        } on Exception {
          reader.position = fallbackOffsetPosition; // reset
          return false;
        }
        return true;
      } else // if there's no image in the WZ file (new KMST Base.wz), test the directory instead
      {
        // coincidentally in msea v194 Map001.wz, the hash matches exactly using mapleStoryPatchVersion of 113, and it fails to decrypt later on (probably 1 in a million chance? o_O).
        // damn, technical debt accumulating here
        if (Version == 113) {
          // hack for now
          reader.position = fallbackOffsetPosition; // reset
          return false;
        } else {
          wzDir = testDirectory;
          bCloseTestDirectory = false;

          return true;
        }
      }
    } finally {
      if (bCloseTestDirectory) {
        testDirectory.dispose();
      }
    }
  }

  /// Check and gets the version hash.
  ///
  /// [wzVersionHeader] The version header from .wz file.
  /// [maplestoryPatchVersion]
  int CheckAndGetVersionHash(int wzVersionHeader, int maplestoryPatchVersion) {
    var VersionNumber = maplestoryPatchVersion;
    var VersionHash = 0;

    for (var ch in VersionNumber.toString().codeUnits) {
      VersionHash = (32 * VersionHash) + ch + 1;
    }

    if (wzVersionHeader == wzVersionHeader64bit) {
      return VersionHash; // always 59192
    }

    var a = (VersionHash >> 24) & 0xFF,
        b = (VersionHash >> 16) & 0xFF,
        c = (VersionHash >> 8) & 0xFF,
        d = VersionHash & 0xFF;
    var DecryptedVersionNumber = (0xFF ^ a ^ b ^ c ^ d);

    if (wzVersionHeader == DecryptedVersionNumber) {
      return VersionHash;
    }
    return 0; // invalid
  }

  /// <summary>
  /// Version hash
  /// </summary>[
  void _CreateWZVersionHash() {
    versionHash = 0;
    for (final ch in Version.toString().codeUnits) {
      versionHash = (versionHash * 32) + ch + 1;
    }
    final a = (versionHash >> 24),
        b = (versionHash >> 16),
        c = (versionHash >> 8),
        d = versionHash;
    wzVersionHeader = ~(a ^ b ^ c ^ d);
    wzVersionHeader &= 0xff;  // keep the LSB (8 bits)
  }

  /// Saves a wz file to the disk, AKA repacking.
  void SaveToDisk(String path, [WzMapleVersion savingToPreferredWzVer = WzMapleVersion.UNKNOWN]) {
    // WZ IV
    if (savingToPreferredWzVer == WzMapleVersion.UNKNOWN) {
      wzIv = WzTool.GetIvByMapleVersion(mapleLocalVersion);
    } else {
      wzIv = WzTool.GetIvByMapleVersion(savingToPreferredWzVer);
    } // custom selected

    var bIsWzIvSimilar = ListEquality().equals(wzIv, wzDir.wzIv); // check if its saving to the same IV.
    wzDir.wzIv = wzIv;

    // MapleStory UserKey
    var bIsWzUserKeyDefault = Constants.IsDefaultMapleStoryUserKey(); // check if its saving to the same UserKey.
    //

    _CreateWZVersionHash();
    wzDir.SetVersionHash(versionHash);

    // this .TEMP file will contain everything except Header
    var tempFile = File(p.basenameWithoutExtension(path) + '.TEMP');
    var raFile = tempFile.openSync(mode: FileMode.write); // replace with or create a new empty file
    wzDir.GenerateDataFile(bIsWzIvSimilar ? null : wzIv, bIsWzUserKeyDefault, raFile);
    raFile.closeSync(); // must close

    WzTool.StringCache.clear();

    var wzWriter = WzBinaryWriter(OutputFileStream(path), wzIv);

    wzWriter.Hash = versionHash;

    var totalLen = wzDir.GetImgOffsets(wzDir.GetOffsets(header.fstart + (missingEncVer ? 0 : 2)));
    header.fsize = totalLen - header.fstart;

    wzWriter.WriteBytes(Uint8List.fromList(header.ident.codeUnits));
    wzWriter.WriteUint64(header.fsize);
    wzWriter.WriteUint32(header.fstart);
    wzWriter.WriteNullTerminatedString(header.copyright);

    var extraHeaderLength = header.fstart - wzWriter.position;
    if (extraHeaderLength > 0) {
      wzWriter.WriteBytes(Uint8List(extraHeaderLength)); // fill 0s
    }
    if (!missingEncVer) {
      wzWriter.WriteUint16(wzVersionHeader);
    }

    wzWriter.Header = header;
    wzDir.SaveDirectory(wzWriter);
    wzWriter.StringCache.clear();

    // open TEMP file again for reading
    var fs = tempFile.openSync();
    wzDir.SaveImages(wzWriter, fs);
    fs.closeSync(); // must close

    // delete TEMP file
    tempFile.deleteSync();

    wzWriter.StringCache.clear();

    // close writer
    wzWriter.close();

    // GC.Collect();
    // GC.WaitForPendingFinalizers();
  }

  //endregion

  //region Methods (override)

  @override
  WzObject? operator [](String name) {
    return wzDir[name];
  }

  bool _disposed = false;
  @override
  void dispose() {
    if (_disposed) return;
    wzDir.reader?.close();
    wzDir.dispose();
    _disposed = true;
  }

  @override
  void remove() {
    dispose();
  }

  @override
  String toString() {
    return name;
  }

//endregion

}

class WzHeader {
  static const String defaultWzHeaderCopyright =
      'Package file v1.0 Copyright 2002 Wizet, ZMS';

  String ident = 'PKG1';
  String copyright = defaultWzHeaderCopyright;
  int fsize = 0; // 8-byte
  int fstart = 0x3C; // 4-byte

  /// Re-calculate the FStart.
  void recalculateFileStart() =>
      fstart = ident.length + 8 + 4 + copyright.length;
}
