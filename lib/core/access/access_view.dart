import 'package:flutter/foundation.dart';

/// Which screens the person signed in right now may use. Menus ask this; nothing else.
///
/// Two things answer it: the school server's answer (`AccessController`), and, in the
/// demo with no server, the owner's decisions kept on the device (`LocalOwnerAccess`).
/// It is a [Listenable], so a menu redraws the moment the owner changes something.
abstract interface class AccessView implements Listenable {
  /// True once the person's access is known. Until then nothing is hidden.
  bool get known;

  /// May the person use this screen (`<workspace>.<screen>`)?
  bool allows(String activity);
}
