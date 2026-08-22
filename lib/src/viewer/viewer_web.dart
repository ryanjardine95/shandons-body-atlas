import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:ui_web' as ui_web;

import 'package:flutter/widgets.dart';
import 'package:web/web.dart' as web;

import 'controller.dart';

AtlasViewerController createController() => _WebViewerController();

int _instanceCounter = 0;

class _WebViewerController implements AtlasViewerController {
  _WebViewerController() {
    _viewType = 'atlas-viewer-${_instanceCounter++}';
    ui_web.platformViewRegistry.registerViewFactory(_viewType, (int viewId) {
      final iframe = web.HTMLIFrameElement()
        ..src = ui_web.assetManager.getAssetUrl('assets/viewer/viewer.html')
        ..style.border = 'none'
        ..style.width = '100%'
        ..style.height = '100%';
      _iframe = iframe;
      return iframe;
    });
    _subscription = web.EventStreamProviders.messageEvent
        .forTarget(web.window)
        .listen(_onMessage);
  }

  late final String _viewType;
  web.HTMLIFrameElement? _iframe;
  StreamSubscription<web.MessageEvent>? _subscription;
  final _events = StreamController<ViewerEvent>.broadcast();
  final _pending = <ViewerCommand>[];
  var _ready = false;

  void _onMessage(web.MessageEvent e) {
    // The viewer posts JSON strings; anything else on the window is not ours.
    final data = e.data;
    if (data == null || !data.typeofEquals('string')) return;
    final Map<String, Object?> json;
    try {
      final decoded = jsonDecode((data as JSString).toDart);
      if (decoded is! Map<String, Object?>) return;
      json = decoded;
    } catch (_) {
      return;
    }
    final event = ViewerEvent.fromJson(json);
    if (event == null) return;
    if (event is ViewerReady) {
      _ready = true;
      final queued = List.of(_pending);
      _pending.clear();
      queued.forEach(send);
    }
    _events.add(event);
  }

  @override
  Widget buildView() => HtmlElementView(viewType: _viewType);

  @override
  Stream<ViewerEvent> get events => _events.stream;

  @override
  void send(ViewerCommand command) {
    final target = _iframe?.contentWindow;
    if (!_ready || target == null) {
      _pending.add(command);
      return;
    }
    target.postMessage(jsonEncode(command.toJson()).toJS, '*'.toJS);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _events.close();
  }
}
