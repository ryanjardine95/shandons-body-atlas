import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shandons_body_atlas/src/atlas_screen.dart';
import 'package:shandons_body_atlas/src/manifest.dart';
import 'package:shandons_body_atlas/src/viewer/controller.dart';

/// Behavioral tests for the atlas workflow: the user drives the layer panel,
/// the viewer answers with events, the info card explains what was tapped.
class FakeViewerController implements AtlasViewerController {
  final sent = <ViewerCommand>[];
  final _events = StreamController<ViewerEvent>.broadcast();

  void emit(ViewerEvent event) => _events.add(event);

  @override
  Widget buildView() => const ColoredBox(color: Color(0xFF101820));

  @override
  Stream<ViewerEvent> get events => _events.stream;

  @override
  void send(ViewerCommand command) => sent.add(command);

  @override
  void dispose() => _events.close();
}

const _manifestJson = '''
{
  "layers": [
    {"id": "skin", "label": "Skin", "file": "skin.glb", "renderOrder": 6,
     "defaultVisible": true, "defaultOpacity": 0.35},
    {"id": "skeleton", "label": "Skeleton", "file": "skeleton.glb",
     "renderOrder": 4, "defaultVisible": true, "defaultOpacity": 1.0},
    {"id": "muscles", "label": "Muscles", "file": "muscles.glb",
     "renderOrder": 5, "defaultVisible": false, "defaultOpacity": 1.0}
  ],
  "layerBlurbs": {"skeleton": "Bones, joints, and ligaments."},
  "descriptions": {"Kidney": "Filters waste from the blood."},
  "attribution": "Z-Anatomy CC-BY-SA 4.0"
}
''';

void main() {
  late FakeViewerController viewer;

  Future<void> pumpAtlas(WidgetTester tester) async {
    viewer = FakeViewerController();
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      home: AtlasScreen(
        manifest: AtlasManifest.fromJsonString(_manifestJson),
        controller: viewer,
      ),
    ));
  }

  Finder layerTile(String label) =>
      find.ancestor(of: find.text(label), matching: find.byType(Card));

  testWidgets(
      'GIVEN a hidden layer WHEN the user switches it on '
      'THEN the viewer is told to show it and a loading indicator appears',
      (tester) async {
    await pumpAtlas(tester);

    await tester.tap(find.descendant(
        of: layerTile('Muscles'), matching: find.byType(Switch)));
    await tester.pump();

    final cmd = viewer.sent.whereType<SetLayerVisible>().single;
    expect(cmd.layer, 'muscles');
    expect(cmd.visible, isTrue);
    expect(
        find.descendant(
            of: layerTile('Muscles'),
            matching: find.byType(CircularProgressIndicator)),
        findsOneWidget);

    viewer.emit(const LayerLoaded('muscles', 675, 400000));
    await tester.pump();
    expect(
        find.descendant(
            of: layerTile('Muscles'),
            matching: find.byType(CircularProgressIndicator)),
        findsNothing);
  });

  testWidgets(
      'GIVEN a visible layer WHEN the user drags its opacity slider '
      'THEN the viewer receives the new opacity', (tester) async {
    await pumpAtlas(tester);

    final slider = find.descendant(
        of: layerTile('Skeleton'), matching: find.byType(Slider));
    await tester.drag(slider, const Offset(-80, 0));
    await tester.pump();

    final cmds = viewer.sent.whereType<SetLayerOpacity>().toList();
    expect(cmds, isNotEmpty);
    expect(cmds.last.layer, 'skeleton');
    expect(cmds.last.opacity, lessThan(1.0));
  });

  testWidgets(
      'GIVEN the atlas WHEN the viewer reports a tapped structure '
      'THEN the info card shows its pretty name, layer, and description',
      (tester) async {
    await pumpAtlas(tester);
    expect(find.text('Tap any structure in the model to identify it.'),
        findsOneWidget);

    viewer.emit(const StructureSelected('Kidney L', 'skeleton'));
    await tester.pump();

    expect(find.text('Left kidney'), findsOneWidget);
    expect(find.text('SKELETON'), findsOneWidget);
    expect(find.text('Filters waste from the blood.'), findsOneWidget);
  });

  testWidgets(
      'GIVEN a selected structure WHEN the user closes the card '
      'THEN the viewer selection is cleared and the hint returns',
      (tester) async {
    await pumpAtlas(tester);
    viewer.emit(const StructureSelected('Kidney L', 'skeleton'));
    await tester.pump();

    await tester.tap(find.byIcon(Icons.close));
    await tester.pump();

    expect(viewer.sent.whereType<ClearSelection>(), hasLength(1));
    expect(find.text('Tap any structure in the model to identify it.'),
        findsOneWidget);
  });

  testWidgets(
      'GIVEN the atlas WHEN the user resets the view '
      'THEN the viewer receives resetCamera', (tester) async {
    await pumpAtlas(tester);
    await tester.tap(find.text('Reset view'));
    expect(viewer.sent.whereType<ResetCamera>(), hasLength(1));
  });

  group('on a phone-sized screen', () {
    Future<void> pumpPhoneAtlas(WidgetTester tester) async {
      viewer = FakeViewerController();
      // Compact-layout width (breakpoint is 760) with all three chips visible.
      tester.view.physicalSize = const Size(700, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        home: AtlasScreen(
          manifest: AtlasManifest.fromJsonString(_manifestJson),
          controller: viewer,
        ),
      ));
    }

    testWidgets(
        'GIVEN the compact layout WHEN the user taps a layer chip '
        'THEN the viewer is told to show that layer', (tester) async {
      await pumpPhoneAtlas(tester);

      expect(find.byType(FilterChip), findsNWidgets(3));
      expect(find.byType(Switch), findsNothing);

      await tester.tap(find.widgetWithText(FilterChip, 'Muscles'));
      await tester.pump();

      final cmd = viewer.sent.whereType<SetLayerVisible>().single;
      expect(cmd.layer, 'muscles');
      expect(cmd.visible, isTrue);
    });

    testWidgets(
        'GIVEN the compact layout WHEN the user expands the controls '
        'THEN opacity sliders appear and drive the viewer', (tester) async {
      await pumpPhoneAtlas(tester);
      expect(find.byType(Slider), findsNothing);

      await tester.tap(find.byIcon(Icons.tune));
      await tester.pumpAndSettle();
      expect(find.byType(Slider), findsNWidgets(3));

      final slider = find.descendant(
          of: find.ancestor(
              of: find.text('Skeleton'), matching: find.byType(Card)),
          matching: find.byType(Slider));
      await tester.drag(slider, const Offset(-60, 0));
      await tester.pump();

      final cmds = viewer.sent.whereType<SetLayerOpacity>().toList();
      expect(cmds, isNotEmpty);
      expect(cmds.last.layer, 'skeleton');
    });

    testWidgets(
        'GIVEN the compact layout WHEN the viewer reports a tapped structure '
        'THEN the info card shows it above the chip bar', (tester) async {
      await pumpPhoneAtlas(tester);

      viewer.emit(const StructureSelected('Kidney L', 'skeleton'));
      await tester.pump();

      expect(find.text('Left kidney'), findsOneWidget);
      expect(find.text('Filters waste from the blood.'), findsOneWidget);
    });
  });
}
