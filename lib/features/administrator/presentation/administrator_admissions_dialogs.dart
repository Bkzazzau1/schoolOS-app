import 'package:flutter/material.dart';

import '../data/administrator_admissions_repository.dart';

class NewApplicantChoice {
  const NewApplicantChoice({
    required this.name,
    required this.section,
    required this.className,
    required this.guardian,
    required this.phone,
    required this.source,
  });

  final String name;
  final String section;
  final String className;
  final String guardian;
  final String phone;
  final String source;
}

/// Asks for the details of a new application taken at the school. Returns null when cancelled.
/// The dialog owns and disposes its own text boxes.
Future<NewApplicantChoice?> askNewApplicant(BuildContext context) => showDialog<NewApplicantChoice>(
      context: context,
      builder: (context) => const _NewApplicantDialog(),
    );

class _NewApplicantDialog extends StatefulWidget {
  const _NewApplicantDialog();

  @override
  State<_NewApplicantDialog> createState() => _NewApplicantDialogState();
}

class _NewApplicantDialogState extends State<_NewApplicantDialog> {
  final _name = TextEditingController();
  final _class = TextEditingController();
  final _guardian = TextEditingController();
  final _phone = TextEditingController();
  String _section = AdministratorAdmissionsRepository.sections[1];
  String _source = 'Walk-in';

  @override
  void dispose() {
    _name.dispose();
    _class.dispose();
    _guardian.dispose();
    _phone.dispose();
    super.dispose();
  }

  bool get _ready =>
      _name.text.trim().isNotEmpty && _class.text.trim().isNotEmpty && _guardian.text.trim().isNotEmpty && _phone.text.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('New application'),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  key: const ValueKey('applicant-name'),
                  controller: _name,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(labelText: "Child's full name"),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                isExpanded: true,
                  key: const ValueKey('applicant-section'),
                  initialValue: _section,
                  decoration: const InputDecoration(labelText: 'Section'),
                  items: [for (final s in AdministratorAdmissionsRepository.sections) DropdownMenuItem(value: s, child: Text(s))],
                  onChanged: (v) => setState(() => _section = v ?? _section),
                ),
                const SizedBox(height: 10),
                TextField(
                  key: const ValueKey('applicant-class'),
                  controller: _class,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(labelText: 'Applying for which class', hintText: 'For example Primary 2'),
                ),
                const SizedBox(height: 10),
                TextField(
                  key: const ValueKey('applicant-guardian'),
                  controller: _guardian,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(labelText: "Guardian's name"),
                ),
                const SizedBox(height: 10),
                TextField(
                  key: const ValueKey('applicant-phone'),
                  controller: _phone,
                  onChanged: (_) => setState(() {}),
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: "Guardian's phone", hintText: '0803 123 4567'),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                isExpanded: true,
                  initialValue: _source,
                  decoration: const InputDecoration(labelText: 'How they applied'),
                  items: const [
                    DropdownMenuItem(value: 'Walk-in', child: Text('Walk-in')),
                    DropdownMenuItem(value: 'Phone call', child: Text('Phone call')),
                    DropdownMenuItem(value: 'Referral', child: Text('Referral')),
                  ],
                  onChanged: (v) => setState(() => _source = v ?? _source),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            key: const ValueKey('applicant-add'),
            onPressed: _ready
                ? () => Navigator.pop(
                      context,
                      NewApplicantChoice(
                        name: _name.text.trim(),
                        section: _section,
                        className: _class.text.trim(),
                        guardian: _guardian.text.trim(),
                        phone: _phone.text.trim(),
                        source: _source,
                      ),
                    )
                : null,
            child: const Text('Add application'),
          ),
        ],
      );
}
