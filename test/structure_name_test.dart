import 'package:glados/glados.dart';
import 'package:shandons_body_atlas/src/structure_name.dart';

/// Property tests for structure-name prettification (asset node names use
/// the dot-free `Name L` / `Name R` convention; `.l`/`.r` kept for safety).
void main() {
  final baseName = any.combine2(
    any.choose(['Hip bone', 'Kidney', 'Vagus nerve (X)', 'Biceps brachii',
        'Superior lobe of right lung', 'Atlas (C1)']),
    any.positiveIntOrZero,
    (String name, int n) => name,
  );

  Glados(baseName).test('side suffix L becomes a Left prefix', (base) {
    final pretty = prettifyStructureName('$base L');
    expect(pretty, 'Left ${base[0].toLowerCase()}${base.substring(1)}');
  });

  Glados(baseName).test('side suffix R becomes a Right prefix', (base) {
    expect(prettifyStructureName('$base R'), startsWith('Right '));
  });

  Glados(baseName).test('legacy .l/.r suffixes are handled too', (base) {
    expect(prettifyStructureName('$base.l'), prettifyStructureName('$base L'));
    expect(prettifyStructureName('$base.r'), prettifyStructureName('$base R'));
  });

  Glados(baseName).test('base name lookup key strips the side, keeps the rest',
      (base) {
    expect(structureBaseName('$base L'), base);
    expect(structureBaseName(base), base);
  });

  Glados(any.lowercaseLetters).test('never throws on arbitrary input', (s) {
    expect(() => prettifyStructureName(s), returnsNormally);
    expect(() => splitSide(s), returnsNormally);
  });

  Glados(baseName).test('prettification is idempotent', (base) {
    final once = prettifyStructureName('$base L');
    expect(prettifyStructureName(once), once);
  });

  Glados(baseName).test('numeric dedup suffixes from Blender are dropped',
      (base) {
    expect(prettifyStructureName('$base.001'), prettifyStructureName(base));
  });
}
