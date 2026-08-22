import 'controller.dart';

/// Non-web fallback. The same viewer.html + JSON protocol runs in a
/// webview_flutter WebView when mobile/desktop targets are wired up.
AtlasViewerController createController() => throw UnsupportedError(
      'The 3D viewer is currently wired up for web only. '
      'Run with: flutter run -d chrome',
    );
