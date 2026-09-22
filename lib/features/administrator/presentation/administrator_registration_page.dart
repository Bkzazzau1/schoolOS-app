import 'package:flutter/material.dart';

import '../data/administrator_registration_demo_data.dart';
import '../data/administrator_registration_repository.dart';
import '../domain/administrator_admissions_models.dart';
import '../domain/administrator_registration_models.dart';

class AdministratorRegistrationPage extends StatefulWidget {
  const AdministratorRegistrationPage({
    super.key,
    required this.schoolName,
    required this.repository,
    this.sourceApplicant,
    this.onRegistrationChanged,
  });

  final String schoolName;
  final AdministratorRegistrationRepository repository;
  final AdmissionApplicant? sourceApplicant;
  final VoidCallback? onRegistrationChanged;

  @override
  State<AdministratorRegistrationPage> createState() =>
      _AdministratorRegistrationPageState();
}

class _AdministratorRegistrationPageState
    extends State<AdministratorRegistrationPage> {
  final _firstName = TextEditingController();
  final _surname = TextEditingController();
  final _otherName = TextEditingController();
  final _dateOfBirth = TextEditingController();
  final _previousSchool = TextEditingController();
  final _address = TextEditingController();
  final _guardian = TextEditingController();
  final _guardianPhone = TextEditingController();
  final _guardianEmail = TextEditingController();

  StudentRegistrationRecord? _record;
  RegistrationPermissions? _permissions;
  bool _loading = true;
  bool _saving = false;
  String? _error;
  String _gender = 'Female';
  String _section = 'Primary';
  String _proposedClass = 'Primary 2';
  String _relationship = 'Father';
  String _familyAccount = 'Create new family account';
  String _siblingLink = 'No existing sibling';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant AdministratorRegistrationPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sourceApplicant?.reference != widget.sourceApplicant?.reference) {
      _load();
    }
  }

  @override
  void dispose() {
    _firstName.dispose();
    _surname.dispose();
    _otherName.dispose();
    _dateOfBirth.dispose();
    _previousSchool.dispose();
    _address.dispose();
    _guardian.dispose();
    _guardianPhone.dispose();
    _guardianEmail.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final snapshot = await widget.repository.load(
        sourceApplicant: widget.sourceApplicant,
      );
      if (!mounted) return;
      _applyRecord(snapshot.record);
      setState(() {
        _record = snapshot.record;
        _permissions = snapshot.permissions;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = '$error';
        _loading = false;
      });
    }
  }

  void _applyRecord(StudentRegistrationRecord record) {
    _firstName.text = record.firstName;
    _surname.text = record.surname;
    _otherName.text = record.otherName;
    _dateOfBirth.text = record.dateOfBirth;
    _previousSchool.text = record.previousSchool;
    _address.text = record.address;
    _guardian.text = record.primaryGuardian;
    _guardianPhone.text = record.guardianPhone;
    _guardianEmail.text = record.guardianEmail;
    _gender = record.gender;
    _section = record.academicSection;
    _proposedClass = record.proposedClass;
    _relationship = registrationRelationships.contains(record.relationship)
        ? record.relationship
        : registrationRelationships.first;
    _familyAccount = registrationFamilyAccounts.contains(record.familyAccount)
        ? record.familyAccount
        : registrationFamilyAccounts.first;
    _siblingLink = registrationSiblingLinks.contains(record.siblingLink)
        ? record.siblingLink
        : registrationSiblingLinks.first;
  }

  StudentRegistrationRecord _draftFromForm() {
    final current = _record ?? administratorRegistrationWebsiteSeed;
    final serial = RegExp(r'(\d{3})$').firstMatch(current.admissionNumber)?.group(1) ??
        '014';
    final baseAdmission = admissionNumberForSection(_section);
    final admission = baseAdmission.replaceFirst(RegExp(r'\d{3}$'), serial);
    return current.copyWith(
      firstName: _firstName.text.trim(),
      surname: _surname.text.trim(),
      otherName: _otherName.text.trim(),
      dateOfBirth: _dateOfBirth.text.trim(),
      gender: _gender,
      academicSection: _section,
      proposedClass: _proposedClass,
      previousSchool: _previousSchool.text.trim(),
      address: _address.text.trim(),
      admissionNumber: admission,
      primaryGuardian: _guardian.text.trim(),
      relationship: _relationship,
      guardianPhone: _guardianPhone.text.trim(),
      guardianEmail: _guardianEmail.text.trim(),
      familyAccount: _familyAccount,
      siblingLink: _siblingLink,
    );
  }

  Future<void> _save({required bool complete}) async {
    if (_saving) return;
    setState(() => _saving = true);
    final draft = _draftFromForm();
    final result = complete
        ? await widget.repository.completeRegistration(draft)
        : await widget.repository.saveDraft(draft);
    if (!mounted) return;
    if (result.record != null) {
      _applyRecord(result.record!);
      _record = result.record;
    }
    setState(() => _saving = false);
    if (result.success) widget.onRegistrationChanged?.call();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(result.message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded, size: 42),
              const SizedBox(height: 12),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 14),
              FilledButton(onPressed: _load, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    final record = _record ?? administratorRegistrationWebsiteSeed;
    final canManage = _permissions?.canRegisterStudent ?? false;

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 980;
        return ListView(
          padding: EdgeInsets.all(wide ? 28 : 16),
          children: [
            _Header(
              schoolName: widget.schoolName,
              sourceReference: record.sourceApplicantReference,
              canManage: canManage && !_saving,
              onSaveDraft: () => _save(complete: false),
              onComplete: () => _save(complete: true),
            ),
            const SizedBox(height: 18),
            if (wide)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 3, child: _studentInformation()),
                  const SizedBox(width: 16),
                  Expanded(flex: 2, child: _admissionIdentity(record)),
                ],
              )
            else ...[
              _studentInformation(),
              const SizedBox(height: 16),
              _admissionIdentity(record),
            ],
            const SizedBox(height: 16),
            if (wide)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _guardianCard()),
                  const SizedBox(width: 16),
                  Expanded(child: _documentsCard(record)),
                ],
              )
            else ...[
              _guardianCard(),
              const SizedBox(height: 16),
              _documentsCard(record),
            ],
          ],
        );
      },
    );
  }

  Widget _studentInformation() {
    final classOptions = registrationClasses.contains(_proposedClass)
        ? registrationClasses
        : <String>[_proposedClass, ...registrationClasses];
    return _SectionCard(
      title: 'Student information',
      subtitle: 'Core identity and school placement.',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final two = constraints.maxWidth >= 620;
          final fields = <Widget>[
            _field('First name', _firstName),
            _field('Surname', _surname),
            _field('Other name', _otherName),
            _field('Date of birth', _dateOfBirth, hint: 'YYYY-MM-DD'),
            _dropdown(
              'Gender',
              value: _gender,
              items: const ['Female', 'Male'],
              onChanged: (value) => setState(() => _gender = value),
            ),
            _dropdown(
              'Academic section',
              value: _section,
              items: registrationSections,
              onChanged: (value) => setState(() => _section = value),
            ),
            _dropdown(
              'Proposed class',
              value: _proposedClass,
              items: classOptions,
              onChanged: (value) => setState(() => _proposedClass = value),
            ),
            _field('Previous school', _previousSchool),
          ];
          return Column(
            children: [
              if (two)
                for (var i = 0; i < fields.length; i += 2)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: fields[i]),
                        const SizedBox(width: 12),
                        Expanded(
                          child: i + 1 < fields.length
                              ? fields[i + 1]
                              : const SizedBox.shrink(),
                        ),
                      ],
                    ),
                  )
              else
                for (final field in fields)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: field,
                  ),
              TextField(
                controller: _address,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(labelText: 'Address'),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _admissionIdentity(StudentRegistrationRecord record) {
    final serial = RegExp(r'(\d{3})$').firstMatch(record.admissionNumber)?.group(1) ??
        '014';
    final shownAdmission = admissionNumberForSection(_section)
        .replaceFirst(RegExp(r'\d{3}$'), serial);
    return _SectionCard(
      title: 'Admission identity',
      subtitle: 'Generated school identifiers.',
      child: Column(
        children: [
          _InfoRow(
            label: 'Admission number',
            value: shownAdmission,
            note: 'Permanent and never reused',
          ),
          _InfoRow(
            label: 'Student ID',
            value: record.studentId,
            note: 'QR/barcode uses this safe opaque identifier',
          ),
          _InfoRow(
            label: 'Status',
            value: record.status.label,
            note: record.isActive
                ? 'Registration completed'
                : 'Becomes Active after completion',
          ),
          const SizedBox(height: 12),
          const _BoundaryBox(text: registrationQrSafetyBoundary),
        ],
      ),
    );
  }

  Widget _guardianCard() {
    return _SectionCard(
      title: 'Guardian / Family account',
      subtitle: 'Link this child to authorized guardians.',
      child: Column(
        children: [
          _field('Primary guardian', _guardian),
          const SizedBox(height: 12),
          _dropdown(
            'Relationship',
            value: _relationship,
            items: registrationRelationships,
            onChanged: (value) => setState(() => _relationship = value),
          ),
          const SizedBox(height: 12),
          _field('Phone', _guardianPhone),
          const SizedBox(height: 12),
          _field('Email', _guardianEmail),
          const SizedBox(height: 12),
          _dropdown(
            'Family account',
            value: _familyAccount,
            items: registrationFamilyAccounts,
            onChanged: (value) => setState(() => _familyAccount = value),
          ),
          const SizedBox(height: 12),
          _dropdown(
            'Sibling link',
            value: _siblingLink,
            items: registrationSiblingLinks,
            onChanged: (value) => setState(() => _siblingLink = value),
          ),
        ],
      ),
    );
  }

  Widget _documentsCard(StudentRegistrationRecord record) {
    return _SectionCard(
      title: 'Documents & handoff',
      subtitle: 'Registration completeness checklist.',
      child: Column(
        children: [
          _InfoRow(
            label: 'Birth certificate',
            value: record.birthCertificateStatus,
          ),
          _InfoRow(
            label: 'Previous school record',
            value: record.previousSchoolRecordStatus,
          ),
          _InfoRow(
            label: 'Guardian identification',
            value: record.guardianIdentificationStatus,
          ),
          _InfoRow(
            label: 'Finance account setup',
            value: record.financeSetupStatus,
          ),
          _InfoRow(
            label: 'Transport / meal enrollment',
            value: record.transportMealStatus,
          ),
          const SizedBox(height: 12),
          const _BoundaryBox(text: registrationActivationBoundary),
        ],
      ),
    );
  }

  Widget _field(
    String label,
    TextEditingController controller, {
    String? hint,
  }) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(labelText: label, hintText: hint),
    );
  }

  Widget _dropdown(
    String label, {
    required String value,
    required List<String> items,
    required ValueChanged<String> onChanged,
  }) {
    final safeValue = items.contains(value) ? value : items.first;
    return DropdownButtonFormField<String>(
    isExpanded: true,
      initialValue: safeValue,
      decoration: InputDecoration(labelText: label),
      items: [
        for (final item in items)
          DropdownMenuItem<String>(value: item, child: Text(item)),
      ],
      onChanged: (value) {
        if (value != null) onChanged(value);
      },
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.schoolName,
    required this.sourceReference,
    required this.canManage,
    required this.onSaveDraft,
    required this.onComplete,
  });

  final String schoolName;
  final String? sourceReference;
  final bool canManage;
  final VoidCallback onSaveDraft;
  final VoidCallback onComplete;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 16,
      runSpacing: 12,
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'ADMINISTRATION · ADMISSIONS',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
              ),
              const SizedBox(height: 5),
              Text(
                'Student Registration',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
              ),
              const SizedBox(height: 6),
              Text(
                'Create a complete student record from admission through family linking and class placement. · $schoolName',
              ),
              if (sourceReference != null) ...[
                const SizedBox(height: 5),
                Text(
                  'Admissions handoff: $sourceReference',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ],
          ),
        ),
        Wrap(
          spacing: 8,
          children: [
            OutlinedButton(
              onPressed: canManage ? onSaveDraft : null,
              child: const Text('Save draft'),
            ),
            FilledButton(
              onPressed: canManage ? onComplete : null,
              child: const Text('Complete registration'),
            ),
          ],
        ),
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: 4),
            Text(subtitle),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value, this.note});

  final String label;
  final String value;
  final String? note;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 11),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
          if (note != null) ...[
            const SizedBox(height: 2),
            Text(note!, style: Theme.of(context).textTheme.bodySmall),
          ],
        ],
      ),
    );
  }
}

class _BoundaryBox extends StatelessWidget {
  const _BoundaryBox({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(text),
    );
  }
}
