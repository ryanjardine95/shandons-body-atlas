import 'package:flutter_test/flutter_test.dart';
import 'package:shandons_body_atlas/src/viewer/controller.dart';

/// Contract tests for the Dart <-> viewer.html JSON protocol.
/// The shapes asserted here mirror the `commands` map and `post` calls in
/// assets/viewer/viewer.html — change both sides together.
void main() {
  group('commands encode to the shape viewer.html handles', () {
    test('setLayerVisible', () {
      expect(SetLayerVisible('skin', false).toJson(),
          {'cmd': 'setLayerVisible', 'layer': 'skin', 'visible': false});
    });

    test('setLayerOpacity', () {
      expect(SetLayerOpacity('organs', 0.35).toJson(),
          {'cmd': 'setLayerOpacity', 'layer': 'organs', 'opacity': 0.35});
    });

    test('resetCamera and clearSelection', () {
      expect(ResetCamera().toJson(), {'cmd': 'resetCamera'});
      expect(ClearSelection().toJson(), {'cmd': 'clearSelection'});
    });
  });

  group('events decode from the payloads viewer.html posts', () {
    test('ready', () {
      final e = ViewerEvent.fromJson({
        'event': 'ready',
        'layers': ['skin', 'organs']
      });
      expect(e, isA<ViewerReady>());
      expect((e as ViewerReady).layers, ['skin', 'organs']);
    });

    test('layerLoaded', () {
      final e = ViewerEvent.fromJson(
          {'event': 'layerLoaded', 'layer': 'skeleton', 'meshCount': 690, 'triangles': 250000});
      expect(e, isA<LayerLoaded>());
      e as LayerLoaded;
      expect(e.layer, 'skeleton');
      expect(e.meshCount, 690);
      expect(e.triangles, 250000);
    });

    test('progress', () {
      final e = ViewerEvent.fromJson(
          {'event': 'progress', 'layer': 'skin', 'loaded': 512, 'total': 2048});
      expect(e, isA<LoadProgress>());
      e as LoadProgress;
      expect(e.loaded / e.total, 0.25);
    });

    test('selected carries a name or null (deselect)', () {
      final sel = ViewerEvent.fromJson(
          {'event': 'selected', 'name': 'Hip bone L', 'layer': 'skeleton'});
      expect((sel as StructureSelected).name, 'Hip bone L');
      final desel =
          ViewerEvent.fromJson({'event': 'selected', 'name': null, 'layer': null});
      expect((desel as StructureSelected).name, isNull);
    });

    test('error', () {
      final e = ViewerEvent.fromJson({'event': 'error', 'message': 'boom'});
      expect((e as ViewerError).message, 'boom');
    });

    test('unknown or malformed payloads decode to null, never throw', () {
      expect(ViewerEvent.fromJson({'event': 'nope'}), isNull);
      expect(ViewerEvent.fromJson({}), isNull);
      expect(ViewerEvent.fromJson({'event': 'progress'}), isNull);
      expect(ViewerEvent.fromJson({'event': 'layerLoaded', 'layer': 42}), isNull);
    });
  });
}
