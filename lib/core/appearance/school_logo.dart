import 'package:flutter/material.dart';

import 'school_appearance_controller.dart';

/// The school's logo in a small round frame, or the first letter of the school's name when no logo has been chosen.
class SchoolLogo extends StatelessWidget {
  const SchoolLogo({super.key, required this.schoolName, this.size = 40, this.appearance});

  final String schoolName;
  final double size;

  /// Defaults to the running app's appearance.
  final SchoolAppearanceController? appearance;

  @override
  Widget build(BuildContext context) {
    final source = appearance ?? SchoolAppearanceController.shared;
    if (source == null) return _initial(context);
    return ListenableBuilder(
      listenable: source,
      builder: (context, _) {
        final logo = source.logo;
        if (logo == null) return _initial(context);
        return ClipRRect(
          key: const ValueKey('school-logo-image'),
          borderRadius: BorderRadius.circular(size * 0.28),
          child: Image.memory(
            logo,
            width: size,
            height: size,
            fit: BoxFit.contain,
            gaplessPlayback: true,
            errorBuilder: (context, error, stack) => _initial(context),
          ),
        );
      },
    );
  }

  Widget _initial(BuildContext context) {
    final theme = Theme.of(context);
    final letter = schoolName.trim().isEmpty ? 'S' : schoolName.trim().characters.first.toUpperCase();
    return CircleAvatar(
      radius: size / 2,
      backgroundColor: theme.colorScheme.primaryContainer,
      foregroundColor: theme.colorScheme.onPrimaryContainer,
      child: Text(letter),
    );
  }
}
