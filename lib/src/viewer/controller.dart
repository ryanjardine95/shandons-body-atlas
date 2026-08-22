import 'package:flutter/widgets.dart';

import 'viewer_stub.dart' if (dart.library.js_interop) 'viewer_web.dart'
    as impl;

/// The one contract between the Flutter shell and the embedded three.js
/// viewer: JSON commands in, JSON events out (see assets/viewer/viewer.html).
sealed class ViewerCommand {
  Map<String, Object?> toJson();
}

class SetLayerVisible extends ViewerCommand {
  SetLayerVisible(this.layer, this.visible);
  final String layer;
  final bool visible;

  @override
  Map<String, Object?> toJson() =>
      {'cmd': 'setLayerVisible', 'layer': layer, 'visible': visible};
}

class SetLayerOpacity extends ViewerCommand {
  SetLayerOpacity(this.layer, this.opacity);
  final String layer;
  final double opacity;

  @override
  Map<String, Object?> toJson() =>
      {'cmd': 'setLayerOpacity', 'layer': layer, 'opacity': opacity};
}

class ResetCamera extends ViewerCommand {
  @override
  Map<String, Object?> toJson() => {'cmd': 'resetCamera'};
}

class ClearSelection extends ViewerCommand {
  @override
  Map<String, Object?> toJson() => {'cmd': 'clearSelection'};
}

sealed class ViewerEvent {
  const ViewerEvent();

  /// Returns null for malformed or unknown payloads.
  static ViewerEvent? fromJson(Map<String, Object?> json) {
    try {
      return switch (json['event']) {
        'ready' => ViewerReady(
            (json['layers'] as List?)?.cast<String>() ?? const []),
        'layerLoaded' => LayerLoaded(
            json['layer'] as String,
            (json['meshCount'] as num?)?.toInt() ?? 0,
            (json['triangles'] as num?)?.toInt() ?? 0,
          ),
        'progress' => LoadProgress(
            json['layer'] as String,
            (json['loaded'] as num).toDouble(),
            (json['total'] as num).toDouble(),
          ),
        'selected' =>
          StructureSelected(json['name'] as String?, json['layer'] as String?),
        'error' => ViewerError(json['message'] as String? ?? 'unknown error'),
        _ => null,
      };
    } catch (_) {
      return null;
    }
  }
}

class ViewerReady extends ViewerEvent {
  const ViewerReady(this.layers);
  final List<String> layers;
}

class LayerLoaded extends ViewerEvent {
  const LayerLoaded(this.layer, this.meshCount, this.triangles);
  final String layer;
  final int meshCount;
  final int triangles;
}

class LoadProgress extends ViewerEvent {
  const LoadProgress(this.layer, this.loaded, this.total);
  final String layer;
  final double loaded;
  final double total;
}

class StructureSelected extends ViewerEvent {
  const StructureSelected(this.name, this.layer);
  final String? name;
  final String? layer;
}

class ViewerError extends ViewerEvent {
  const ViewerError(this.message);
  final String message;
}

/// Platform-agnostic handle on the embedded viewer.
abstract class AtlasViewerController {
  Widget buildView();
  Stream<ViewerEvent> get events;
  void send(ViewerCommand command);
  void dispose();
}

AtlasViewerController createViewerController() => impl.createController();
