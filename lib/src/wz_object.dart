part of wzlib;

abstract class WzObject implements Disposable {

  //region Fields
  String name = '';
  WzObject? parent;

  WzObjectType get objectType; // get
  /// The parent [WzFile] object of this object.
  ///
  /// Note: It's nullable because an [WzImage] can be stand-alone.
  WzFile? get wzFileParent; // get
  //endregion

  //region Constructor
  WzObject([this.name = '', this.parent]);
  //endregion

  //region Methods

  WzObject topMostWzDirectory() {
    var p = parent;
    if (p == null) {
      return this;
    } // this

    while (p?.parent != null) {
      p = p?.parent;
    }
    return p!;
  }

  String get fullPath {
    if (this is WzFile) return (this as WzFile).wzDir.name;
    var result = name;
    WzObject? currObj = this;
    while (currObj?.parent != null) {
      currObj = currObj?.parent;
      result = currObj!.name + '\\' + result;
    }
    return result;
  }

  WzObject? operator [](String name);
  void remove();

  @override
  String toString() {
    return name;
  }
  //endregion
}

abstract class Disposable {
  void dispose();
}
