import 'dart:async';

import 'package:flutter/widgets.dart';

import '../auth/auth_repository.dart';
import '../network/api_exceptions.dart';
import 'sync_engine.dart';

/// Whatever can run one round of sending and downloading. [SyncEngine] does; tests use a fake.
abstract interface class SyncRunner {
  Future<SyncRunSummary> syncActiveSchool();
}

enum SyncStatus {
  /// Nothing to report: the last round finished, or none has run yet.
  idle,
  syncing,

  /// The server could not be reached. Work is kept and tried again with growing gaps.
  offline,

  /// The sign-in ended. Nothing more is sent until the person signs in again.
  needsSignIn,

  /// The server says the person no longer belongs to the school they are in.
  lostAccess,

  /// Something unexpected. It is tried again on the next round.
  error,
}

/// Keeps the device and the school in step, without any screen having to ask.
///
/// A round runs when the app starts, when a change is queued (after a short
/// pause, so a burst of edits is one round), when the app comes back to the
/// front, and on a timer. If the server cannot be reached the next try comes
/// later each time, up to [maxBackoff], and starts over at once when the app
/// comes back to the front. Only one round runs at a time; a change queued
/// during a round makes another round follow.
class SyncCoordinator extends ChangeNotifier with WidgetsBindingObserver {
  SyncCoordinator({
    required SyncRunner runner,
    AuthRepository? auth,
    this.interval = const Duration(minutes: 1),
    this.debounce = const Duration(seconds: 2),
    this.firstBackoff = const Duration(seconds: 15),
    this.maxBackoff = const Duration(minutes: 5),
    this.afterRound,
    bool observeLifecycle = true,
  }) : _runner = runner,
       _auth = auth,
       _observeLifecycle = observeLifecycle;

  final SyncRunner _runner;
  final AuthRepository? _auth;
  final Duration interval;
  final Duration debounce;
  final Duration firstBackoff;
  final Duration maxBackoff;

  /// Runs after every round that reached the server (not when offline or signed out).
  /// Anything it throws is ignored: it must never stop syncing.
  final Future<void> Function(SyncRunSummary summary)? afterRound;
  final bool _observeLifecycle;

  SyncStatus _status = SyncStatus.idle;
  SyncRunSummary? _lastSummary;
  DateTime? _lastSyncedAt;
  String? _message;
  int _changes = 0;
  int _remoteChanges = 0;

  bool _started = false;
  bool _running = false;
  bool _again = false;
  Duration? _backoff;
  Timer? _periodic;
  Timer? _pending;

  SyncStatus get status => _status;
  SyncRunSummary? get lastSummary => _lastSummary;
  DateTime? get lastSyncedAt => _lastSyncedAt;

  /// Words for the person when the status is not idle.
  String? get message => _message;

  /// Goes up whenever a round brought in or sent something, so a screen can
  /// listen for it and reload what it shows.
  int get changes => _changes;

  /// Goes up only when a round brought in changes made by someone else (or on another device).
  int get remoteChanges => _remoteChanges;

  /// Begins keeping in step. Safe to call again (for instance after signing in).
  void start() {
    if (_status == SyncStatus.needsSignIn || _status == SyncStatus.lostAccess) {
      _status = SyncStatus.idle;
      _message = null;
      notifyListeners();
    }
    if (!_started) {
      _started = true;
      if (_observeLifecycle) WidgetsBinding.instance.addObserver(this);
    }
    _periodic?.cancel();
    _periodic = Timer.periodic(interval, (_) => _tick());
    requestSync(immediately: true);
  }

  /// Stops all sending and downloading (signed out, or the app is closing).
  void stop() {
    _started = false;
    _periodic?.cancel();
    _pending?.cancel();
    _periodic = _pending = null;
    if (_observeLifecycle) WidgetsBinding.instance.removeObserver(this);
  }

  /// Asks for a round soon. Many asks close together make one round.
  void requestSync({bool immediately = false}) {
    if (!_started || _blocked) return;
    _pending?.cancel();
    _pending = Timer(immediately ? Duration.zero : debounce, syncNow);
  }

  bool get _blocked =>
      _status == SyncStatus.needsSignIn || _status == SyncStatus.lostAccess;

  void _tick() {
    if (_status == SyncStatus.offline && _pending != null) {
      return; // a retry is already waiting
    }
    requestSync(immediately: true);
  }

  /// Runs a round now (or as soon as the one in progress ends).
  Future<void> syncNow() async {
    if (!_started || _blocked) return;
    if (_running) {
      _again = true;
      return;
    }
    _running = true;
    _pending?.cancel();
    _pending = null;
    _setStatus(SyncStatus.syncing);

    try {
      do {
        _again = false;
        await _round();
      } while (_again &&
          _started &&
          !_blocked &&
          _status != SyncStatus.offline);
    } finally {
      _running = false;
    }
  }

  Future<void> _round() async {
    try {
      final summary = await _runner.syncActiveSchool();
      _lastSummary = summary;

      if (summary.needsSignIn) {
        _setStatus(
          SyncStatus.needsSignIn,
          'Your sign-in has ended. Sign in again to keep syncing.',
        );
      } else if (summary.accessLost) {
        await _lostAccess();
      } else if (summary.stoppedOffline) {
        _goOffline();
      } else {
        _backoff = null;
        _lastSyncedAt = DateTime.now();
        if (summary.synced > 0 || summary.pulled > 0) _changes += 1;
        if (summary.pulled > 0) _remoteChanges += 1;
        final problem = summary.pullError;
        await _followUp(summary);
        _setStatus(
          problem == null ? SyncStatus.idle : SyncStatus.error,
          problem,
        );
      }
    } on StateError {
      // No school is chosen yet (or it was just cleared): nothing to do.
      _setStatus(SyncStatus.idle);
    } on ApiOfflineException {
      _goOffline();
    } on SessionExpiredException {
      _setStatus(
        SyncStatus.needsSignIn,
        'Your sign-in has ended. Sign in again to keep syncing.',
      );
    } catch (error) {
      _setStatus(
        SyncStatus.error,
        'Syncing hit a problem and will try again. ($error)',
      );
    }
  }

  Future<void> _followUp(SyncRunSummary summary) async {
    try {
      await afterRound?.call(summary);
    } catch (_) {
      // Never let the follow-up stop syncing.
    }
  }

  void _goOffline() {
    _backoff = _backoff == null
        ? firstBackoff
        : _min(_backoff! * 2, maxBackoff);
    _setStatus(
      SyncStatus.offline,
      'You are offline. Your work is saved and will be sent when you are back online.',
    );
    _pending?.cancel();
    if (_started) _pending = Timer(_backoff!, syncNow);
  }

  Future<void> _lostAccess() async {
    // The school list may have changed: ask the server, so the person is only
    // offered schools they still belong to.
    try {
      await _auth?.refreshProfile();
    } catch (_) {
      // Offline or signed out: the message below still stands.
    }
    _setStatus(
      SyncStatus.lostAccess,
      'You no longer have access to this school.',
    );
  }

  Duration _min(Duration a, Duration b) => a < b ? a : b;

  void _setStatus(SyncStatus status, [String? message]) {
    if (_status == status && _message == message && status != SyncStatus.idle) {
      return;
    }
    _status = status;
    _message = message;
    notifyListeners();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _backoff = null;
      requestSync(immediately: true);
    }
  }

  @override
  void dispose() {
    stop();
    super.dispose();
  }
}
