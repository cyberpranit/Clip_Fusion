import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ClipboardState {
  final String? detectedUrl;
  final String? platform; // youtube, instagram, tiktok, facebook, x, none

  ClipboardState({this.detectedUrl, this.platform});

  bool get hasLink => detectedUrl != null && platform != null;
}

class ClipboardNotifier extends Notifier<ClipboardState> with WidgetsBindingObserver {
  String _lastCheckedText = '';

  @override
  ClipboardState build() {
    WidgetsBinding.instance.addObserver(this);
    checkClipboard();
    
    ref.onDispose(() {
      WidgetsBinding.instance.removeObserver(this);
    });

    return ClipboardState();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      checkClipboard();
    }
  }

  Future<void> checkClipboard() async {
    try {
      final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
      final text = clipboardData?.text?.trim();

      if (text == null || text.isEmpty || text == _lastCheckedText) return;

      final platform = _detectPlatform(text);
      if (platform != null) {
        state = ClipboardState(detectedUrl: text, platform: platform);
      }
    } catch (e) {
      // Handle permission/clipboard access errors gracefully
    }
  }

  String? _detectPlatform(String url) {
    final cleanUrl = url.toLowerCase();
    if (cleanUrl.contains('youtube.com/') || cleanUrl.contains('youtu.be/')) {
      return 'youtube';
    } else if (cleanUrl.contains('instagram.com/')) {
      return 'instagram';
    } else if (cleanUrl.contains('tiktok.com/')) {
      return 'tiktok';
    } else if (cleanUrl.contains('facebook.com/') || cleanUrl.contains('fb.watch/')) {
      return 'facebook';
    } else if (cleanUrl.contains('x.com/') || cleanUrl.contains('twitter.com/')) {
      return 'x';
    }
    return null;
  }

  void clear() {
    if (state.detectedUrl != null) {
      _lastCheckedText = state.detectedUrl!;
    }
    state = ClipboardState();
  }
}

final clipboardProvider = NotifierProvider<ClipboardNotifier, ClipboardState>(() {
  return ClipboardNotifier();
});
