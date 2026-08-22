import 'package:flutter/material.dart';

import 'manifest.dart';
import 'structure_name.dart';
import 'viewer/controller.dart';

class InfoCard extends StatelessWidget {
  const InfoCard({
    super.key,
    required this.selected,
    required this.manifest,
    required this.onClose,
  });

  final StructureSelected? selected;
  final AtlasManifest manifest;
  final VoidCallback onClose;

  String? _layerLabel(String? id) {
    if (id == null) return null;
    for (final l in manifest.layers) {
      if (l.id == id) return l.label;
    }
    return null;
  }

  String _description(String rawName, String? layerId) {
    return manifest.descriptions[rawName.trim()] ??
        manifest.descriptions[structureBaseName(rawName)] ??
        manifest.layerBlurbs[layerId] ??
        '';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sel = selected;
    if (sel?.name == null) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          border: Border.all(color: theme.colorScheme.outlineVariant),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(Icons.touch_app_outlined,
                size: 18, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(width: 10),
            Expanded(
              child: Text('Tap any structure in the model to identify it.',
                  style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant)),
            ),
          ],
        ),
      );
    }

    final layerLabel = _layerLabel(sel!.layer);
    final description = _description(sel.name!, sel.layer);
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.35),
        border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (layerLabel != null)
                      Text(layerLabel.toUpperCase(),
                          style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.primary,
                              letterSpacing: 1.1)),
                    Text(prettifyStructureName(sel.name!),
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                iconSize: 16,
                onPressed: onClose,
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          if (description.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(description, style: theme.textTheme.bodySmall),
          ],
        ],
      ),
    );
  }
}
