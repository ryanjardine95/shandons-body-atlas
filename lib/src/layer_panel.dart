import 'package:flutter/material.dart';

import 'atlas_screen.dart' show LayerUiState;
import 'manifest.dart';

class LayerPanel extends StatelessWidget {
  const LayerPanel({
    super.key,
    required this.manifest,
    required this.states,
    required this.onToggle,
    required this.onOpacity,
  });

  final AtlasManifest manifest;
  final Map<String, LayerUiState> states;
  final void Function(String id, bool visible) onToggle;
  final void Function(String id, double opacity) onOpacity;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      children: [
        for (final layer in manifest.layers)
          _LayerTile(
            spec: layer,
            state: states[layer.id]!,
            onToggle: (v) => onToggle(layer.id, v),
            onOpacity: (v) => onOpacity(layer.id, v),
          ),
      ],
    );
  }
}

class _LayerTile extends StatelessWidget {
  const _LayerTile({
    required this.spec,
    required this.state,
    required this.onToggle,
    required this.onOpacity,
  });

  final LayerSpec spec;
  final LayerUiState state;
  final ValueChanged<bool> onToggle;
  final ValueChanged<double> onOpacity;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final loading = state.progress != null && !state.loaded;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      color: theme.colorScheme.surfaceContainerHigh,
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(spec.label,
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w600)),
                ),
                if (loading)
                  Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, value: state.progress),
                    ),
                  ),
                Switch(
                  value: state.visible,
                  onChanged: onToggle,
                ),
              ],
            ),
            Row(
              children: [
                Icon(Icons.opacity,
                    size: 15,
                    color: state.visible
                        ? theme.colorScheme.onSurfaceVariant
                        : theme.disabledColor),
                Expanded(
                  child: Slider(
                    value: state.opacity,
                    onChanged: state.visible ? onOpacity : null,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                  ),
                ),
                SizedBox(
                  width: 38,
                  child: Text('${(state.opacity * 100).round()}%',
                      textAlign: TextAlign.right,
                      style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
