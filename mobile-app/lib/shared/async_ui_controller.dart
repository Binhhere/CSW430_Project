import 'dart:async';

import 'package:flutter/material.dart';

import 'request_timeout.dart';

class LatestRequestGate {
  int _generation = 0;

  int begin() => ++_generation;

  bool isCurrent(int token) => token == _generation;

  void invalidate() => _generation++;
}

mixin AppResumeRefreshMixin<T extends StatefulWidget> on State<T> {
  late final _AppResumeObserver _appResumeObserver;
  bool _resumeRefreshRunning = false;

  @override
  void initState() {
    super.initState();
    _appResumeObserver = _AppResumeObserver(_handleAppLifecycleState);
    WidgetsBinding.instance.addObserver(_appResumeObserver);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(_appResumeObserver);
    super.dispose();
  }

  @protected
  Future<void> refreshAfterAppResume();

  void _handleAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_runResumeRefresh());
    }
  }

  Future<void> _runResumeRefresh() async {
    if (_resumeRefreshRunning || !mounted) return;
    _resumeRefreshRunning = true;
    try {
      await withRelayRequestTimeout(refreshAfterAppResume());
    } catch (_) {
      // Resume refreshes are best-effort background work. Each screen owns its
      // visible refresh state, so a network failure must not escape from the
      // unawaited lifecycle callback.
    } finally {
      _resumeRefreshRunning = false;
    }
  }
}

class _AppResumeObserver with WidgetsBindingObserver {
  _AppResumeObserver(this.onStateChanged);

  final ValueChanged<AppLifecycleState> onStateChanged;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    onStateChanged(state);
  }
}

class SearchDebouncer {
  SearchDebouncer(this.delay);

  final Duration delay;
  Timer? _timer;

  void call(VoidCallback action) {
    _timer?.cancel();
    _timer = Timer(delay, action);
  }

  void dispose() => _timer?.cancel();
}
