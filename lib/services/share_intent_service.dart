import 'dart:async';

import 'package:flutter/services.dart';

abstract interface class ShareIntentReceiver {
  Stream<String> get productLinks;

  Future<String?> initialProductLink();

  Future<void> reset();
}

class NoopShareIntentReceiver implements ShareIntentReceiver {
  const NoopShareIntentReceiver();

  @override
  Stream<String> get productLinks => const Stream.empty();

  @override
  Future<String?> initialProductLink() async => null;

  @override
  Future<void> reset() async {}
}

class SystemShareIntentReceiver implements ShareIntentReceiver {
  SystemShareIntentReceiver() {
    _installHandler();
  }

  static const _channel = MethodChannel('com.compete.youcam2/share');
  static final _links = StreamController<String>.broadcast();
  static bool _handlerInstalled = false;

  static void _installHandler() {
    if (_handlerInstalled) return;
    _handlerInstalled = true;
    _channel.setMethodCallHandler((call) async {
      if (call.method != 'sharedText') return;
      final value = call.arguments;
      if (value is! String) return;
      final link = extractProductLink(value);
      if (link != null) _links.add(link);
    });
  }

  @override
  Stream<String> get productLinks => _links.stream;

  @override
  Future<String?> initialProductLink() async {
    final value = await _channel.invokeMethod<String>('getInitialSharedText');
    return value == null ? null : extractProductLink(value);
  }

  @override
  Future<void> reset() => _channel.invokeMethod<void>('resetSharedText');

  static String? extractProductLink(String value) {
    final match = RegExp(
      r'https?://[^\s<>"\u201c\u201d]+',
      caseSensitive: false,
    ).firstMatch(value);
    if (match == null) return null;
    return match.group(0)?.replaceFirst(RegExp(r'[),.;!?]+$'), '');
  }
}
