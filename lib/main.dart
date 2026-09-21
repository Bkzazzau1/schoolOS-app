import 'package:flutter/material.dart';

import 'app/app.dart';
import 'app/app_services.dart';
import 'features/invitations/domain/invitation_link.dart';

Future<void> main(List<String> arguments) async {
  WidgetsFlutterBinding.ensureInitialized();
  final services = await AppServices.bootstrap();
  // Opened from an invitation link (the operating system passes it as an argument).
  final link = arguments.where((a) => invitationTokenFrom(a) != null).firstOrNull;
  runApp(SchoolOsApp(services: services, initialInvitationLink: link));
}
