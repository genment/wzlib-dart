part of wzlib;

enum WzMapleVersion{
  GMS,
  EMS,
  BMS,
  CLASSIC,
  GENERATE,
  GETFROMZLZ,
  CUSTOM,

  UNKNOWN
}

enum WzObjectType
{
  File,
  Image,
  Directory,
  Property,
  List
}

enum WzPropertyType {
// Regular
  Null,
  Short,
  Int,
  Long,
  Float,
  Double,
  String,

// Extended
  SubProperty,
  Canvas,
  Vector,
  Convex,
  Sound,
  UOL,

// Others
  PNG,
  Lua
}
