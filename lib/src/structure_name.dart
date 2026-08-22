/// Naming helpers for anatomical structures.
///
/// Asset node names use a dot-free convention (`Hip bone L`) because
/// three.js strips dots from glTF node names at load time. `.l`/`.r` are
/// still handled for robustness against unrenamed assets.
library;

final _numericSuffix = RegExp(r'\.\d+$');

/// `Hip bone L` / `Hip bone.l` -> (`Hip bone`, `Left`); `Liver` -> (`Liver`, null).
(String, String?) splitSide(String raw) {
  var name = raw.trim().replaceAll(_numericSuffix, '').trim();
  String? side;
  if (name.endsWith(' L') || name.endsWith('.l')) {
    side = 'Left';
  } else if (name.endsWith(' R') || name.endsWith('.r')) {
    side = 'Right';
  }
  if (side != null) {
    name = name.substring(0, name.length - 2).trim();
  }
  return (name, side);
}

/// Display name for the info card: `Hip bone L` -> `Left hip bone`.
String prettifyStructureName(String raw) {
  final (base, side) = splitSide(raw);
  if (base.isEmpty) return raw.trim();
  if (side == null) return base;
  return '$side ${base[0].toLowerCase()}${base.substring(1)}';
}

/// Description lookup key: the side-free base name (`Kidney L` -> `Kidney`).
String structureBaseName(String raw) => splitSide(raw).$1;
