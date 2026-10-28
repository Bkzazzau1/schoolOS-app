import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

bool _firebaseAttempted = false;
bool _firebaseAvailable = false;

Future<bool> _ensureFirebaseApp() async {
  if (_firebaseAttempted) return _firebaseAvailable;
  _firebaseAttempted = true;
  try {
    await Firebase.initializeApp();
    _firebaseAvailable = true;
  } catch (_) {
    _firebaseAvailable = false;
  }
  return _firebaseAvailable;
}

/// A push notification delivered while the app has no UI running (background
/// or terminated, Android only). There is nothing to do here: FCM already
/// shows a system notification for the "notification" payload
/// `FirebasePushProvider.send` always sends on the backend, and the in-app
/// inbox is filled in separately, the next time this device syncs.
@pragma('vm:entry-point')
Future<void> handleBackgroundPushMessage(RemoteMessage message) async {}

/// Registers the handler above, if push is available on this build. Call once
/// from `main()`, before `runApp` - never throws: Firebase may not be
/// configured yet, or this platform (Windows has no Firebase Cloud Messaging
/// support at all) may never support push, and both are normal, honest
/// outcomes here, not failures.
Future<void> registerPushBackgroundHandlerIfAvailable() async {
  if (!await _ensureFirebaseApp()) return;
  try {
    FirebaseMessaging.onBackgroundMessage(handleBackgroundPushMessage);
  } catch (_) {
    // Not available on this build/platform - see function doc above.
  }
}

/// The device's own push-notification token (Firebase Cloud Messaging), if
/// any.
///
/// Firebase is not configured yet on this server/app (no
/// google-services.json, no GoogleService-Info.plist) - every call here fails
/// safely and [enabled] stays false, the same way `ApiConfig.enabled` gates a
/// missing backend. Windows has no Firebase Cloud Messaging support at all,
/// so this stays disabled there too, through the same catch rather than a
/// platform check on its own.
class PushTokenProvider {
  bool _checked = false;
  bool _enabled = false;
  String? _platform;

  bool get enabled => _enabled;
  String? get platform => _platform;

  Future<void> ensureReady() async {
    if (_checked) return;
    _checked = true;
    if (!await _ensureFirebaseApp()) return;
    _platform = Platform.isAndroid ? 'android' : (Platform.isIOS ? 'ios' : null);
    if (_platform == null) return;
    try {
      // Android 13+ and iOS both require this before a system notification can
      // ever show. A denial is a normal outcome, not a failure: getToken()
      // below still works without it, this device just won't display anything.
      await FirebaseMessaging.instance.requestPermission();
    } catch (_) {
      // See above.
    }
    _enabled = true;
  }

  Future<String?> currentToken() async {
    await ensureReady();
    if (!_enabled) return null;
    try {
      return await FirebaseMessaging.instance.getToken();
    } catch (_) {
      return null;
    }
  }

  /// Fires with each new token FCM issues while this device stays enabled (a
  /// fresh install, a restored backup, or a periodic rotation); empty when
  /// push is not available here. Call [ensureReady] (or [currentToken]) at
  /// least once first.
  Stream<String> get onRefresh {
    if (!_enabled) return const Stream.empty();
    try {
      return FirebaseMessaging.instance.onTokenRefresh;
    } catch (_) {
      return const Stream.empty();
    }
  }
}
