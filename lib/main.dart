import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:flutter/material.dart';

import 'app/app.dart';
import 'app/app_services.dart';
import 'core/network/api_config.dart';
import 'features/invitations/domain/invitation_link.dart';

Future<void> main(List<String> arguments) async {
  WidgetsFlutterBinding.ensureInitialized();
  assertApiConfiguredForRelease(ApiConfig.fromEnvironment, isRelease: kReleaseMode);
  final services = await AppServices.bootstrap();
  // Opened from an invitation link (the operating system passes it as an argument).
  final link = arguments.where((a) => invitationTokenFrom(a) != null).firstOrNull;
  runApp(SchoolOsApp(services: services, initialInvitationLink: link));
}
