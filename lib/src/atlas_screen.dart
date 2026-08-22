import 'package:flutter/material.dart';

import 'info_card.dart';
import 'layer_panel.dart';
import 'manifest.dart';
import 'viewer/controller.dart';

/// UI state of one layer row in the side panel.
class LayerUiState {
  LayerUiState({required this.visible, required this.opacity});

  bool visible;
  double opacity;
  bool loaded = false;
  double? progress; // 0..1 while downloading, null when idle/done
}

class AtlasScreen extends StatefulWidget {
  const AtlasScreen(
      {super.key, required this.manifest, required this.controller});

  final AtlasManifest manifest;
  final AtlasViewerController controller;

  @override
  State<AtlasScreen> createState() => _AtlasScreenState();
}

class _AtlasScreenState extends State<AtlasScreen> {
  late final Map<String, LayerUiState> _layers = {
    for (final l in widget.manifest.layers)
      l.id: LayerUiState(visible: l.defaultVisible, opacity: l.defaultOpacity),
  };
  StructureSelected? _selected;
  String? _lastError;

  @override
  void initState() {
    super.initState();
    widget.controller.events.listen(_onViewerEvent);
  }

  @override
  void dispose() {
    widget.controller.dispose();
    super.dispose();
  }

  void _onViewerEvent(ViewerEvent event) {
    if (!mounted) return;
    setState(() {
      switch (event) {
        case ViewerReady():
          break;
        case LoadProgress(:final layer, :final loaded, :final total):
          _layers[layer]?.progress = total > 0 ? loaded / total : null;
        case LayerLoaded(:final layer):
          _layers[layer]
            ?..loaded = true
            ..progress = null;
        case StructureSelected():
          _selected = event.name == null ? null : event;
        case ViewerError(:final message):
          _lastError = message;
      }
    });
  }

  void _toggleLayer(String id, bool visible) {
    setState(() {
      final layer = _layers[id]!;
      layer.visible = visible;
      if (visible && !layer.loaded) layer.progress = 0;
    });
    widget.controller.send(SetLayerVisible(id, visible));
  }

  void _setOpacity(String id, double opacity) {
    setState(() => _layers[id]!.opacity = opacity);
    widget.controller.send(SetLayerOpacity(id, opacity));
  }

  void _clearSelection() {
    setState(() => _selected = null);
    widget.controller.send(ClearSelection());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Row(
        children: [
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(child: widget.controller.buildView()),
                if (_lastError != null)
                  Positioned(
                    left: 16,
                    bottom: 16,
                    child: Material(
                      color: theme.colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: Text('Viewer error: $_lastError',
                            style: TextStyle(
                                color: theme.colorScheme.onErrorContainer)),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(
            width: 348,
            child: Material(
              color: theme.colorScheme.surfaceContainerLow,
              child: SafeArea(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Shandon's Body Atlas",
                              style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.2)),
                          const SizedBox(height: 2),
                          Text('Layered human anatomy explorer',
                              style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant)),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: InfoCard(
                        selected: _selected,
                        manifest: widget.manifest,
                        onClose: _clearSelection,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Expanded(
                      child: LayerPanel(
                        manifest: widget.manifest,
                        states: _layers,
                        onToggle: _toggleLayer,
                        onOpacity: _setOpacity,
                      ),
                    ),
                    const Divider(height: 1),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          OutlinedButton.icon(
                            onPressed: () =>
                                widget.controller.send(ResetCamera()),
                            icon: const Icon(Icons.center_focus_strong,
                                size: 18),
                            label: const Text('Reset view'),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            widget.manifest.attribution,
                            style: theme.textTheme.bodySmall?.copyWith(
                                fontSize: 10,
                                color: theme.colorScheme.onSurfaceVariant
                                    .withValues(alpha: 0.7)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
