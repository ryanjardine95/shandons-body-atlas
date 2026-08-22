import 'dart:convert';

/// The atlas layer manifest — the single source of truth shared with the
/// three.js viewer (assets/models/atlas.json).
class AtlasManifest {
  AtlasManifest({
    required this.layers,
    required this.descriptions,
    required this.layerBlurbs,
    required this.attribution,
  });

  factory AtlasManifest.fromJsonString(String source) {
    final json = jsonDecode(source) as Map<String, dynamic>;
    return AtlasManifest(
      layers: [
        for (final l in json['layers'] as List)
          LayerSpec.fromJson(l as Map<String, dynamic>),
      ],
      descriptions: (json['descriptions'] as Map<String, dynamic>? ?? {})
          .cast<String, String>(),
      layerBlurbs: (json['layerBlurbs'] as Map<String, dynamic>? ?? {})
          .cast<String, String>(),
      attribution: json['attribution'] as String? ?? '',
    );
  }

  final List<LayerSpec> layers;
  final Map<String, String> descriptions;
  final Map<String, String> layerBlurbs;
  final String attribution;
}

class LayerSpec {
  LayerSpec({
    required this.id,
    required this.label,
    required this.defaultVisible,
    required this.defaultOpacity,
  });

  factory LayerSpec.fromJson(Map<String, dynamic> json) => LayerSpec(
        id: json['id'] as String,
        label: json['label'] as String,
        defaultVisible: json['defaultVisible'] as bool? ?? false,
        defaultOpacity: (json['defaultOpacity'] as num? ?? 1).toDouble(),
      );

  final String id;
  final String label;
  final bool defaultVisible;
  final double defaultOpacity;
}
