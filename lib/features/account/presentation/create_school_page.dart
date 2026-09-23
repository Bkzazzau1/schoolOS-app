import 'package:flutter/material.dart';

import '../../../core/network/api_exceptions.dart';
import '../../../shared/models/school_membership.dart';
import '../data/organization_repository.dart';
import '../domain/organization_membership.dart';

class CreateSchoolPage extends StatefulWidget {
  const CreateSchoolPage({
    super.key,
    required this.organization,
    required this.repository,
  });

  final OrganizationMembership organization;
  final OrganizationRepository repository;

  @override
  State<CreateSchoolPage> createState() => _CreateSchoolPageState();
}

class _CreateSchoolPageState extends State<CreateSchoolPage> {
  final _schoolKey = GlobalKey<FormState>();
  final _locationKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _locationController = TextEditingController();

  SchoolKind? _kind;
  int _step = 0;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Create a school')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 880),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
            children: [
              Text(
                'Add a school to ${widget.organization.organizationName}',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'SchoolOS will create a separate school tenant and your proprietor access together. School data will remain isolated from every other school in this account.',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 20),
                Material(
                  color: theme.colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(16),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.error_outline_rounded,
                          color: theme.colorScheme.onErrorContainer,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _error!,
                            style: TextStyle(
                              color: theme.colorScheme.onErrorContainer,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 20),
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(color: theme.colorScheme.outlineVariant),
                ),
                child: Stepper(
                  currentStep: _step,
                  onStepTapped: _busy ? null : _goToStep,
                  controlsBuilder: _controls,
                  steps: [
                    Step(
                      title: const Text('School details'),
                      subtitle: const Text('Name and school type'),
                      isActive: _step >= 0,
                      state: _step > 0 ? StepState.complete : StepState.indexed,
                      content: Form(
                        key: _schoolKey,
                        child: Column(
                          children: [
                            TextFormField(
                              controller: _nameController,
                              textCapitalization: TextCapitalization.words,
                              textInputAction: TextInputAction.next,
                              decoration: const InputDecoration(
                                labelText: 'School name',
                                hintText: 'e.g. Al-Madinah Academy',
                                prefixIcon: Icon(Icons.school_outlined),
                              ),
                              validator: (value) {
                                if (value == null || value.trim().length < 3) {
                                  return 'Enter the school name';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            DropdownButtonFormField<SchoolKind>(
                              initialValue: _kind,
                              decoration: const InputDecoration(
                                labelText: 'School type',
                                prefixIcon: Icon(Icons.category_outlined),
                              ),
                              items: [
                                for (final kind in SchoolKind.values)
                                  DropdownMenuItem(
                                    value: kind,
                                    child: Text(kind.label),
                                  ),
                              ],
                              onChanged: _busy
                                  ? null
                                  : (value) => setState(() => _kind = value),
                              validator: (value) =>
                                  value == null ? 'Choose a school type' : null,
                            ),
                          ],
                        ),
                      ),
                    ),
                    Step(
                      title: const Text('Location'),
                      subtitle: const Text('Where this school operates'),
                      isActive: _step >= 1,
                      state: _step > 1 ? StepState.complete : StepState.indexed,
                      content: Form(
                        key: _locationKey,
                        child: TextFormField(
                          controller: _locationController,
                          textCapitalization: TextCapitalization.words,
                          textInputAction: TextInputAction.done,
                          decoration: const InputDecoration(
                            labelText: 'School location',
                            hintText: 'City, state or campus address',
                            prefixIcon: Icon(Icons.location_on_outlined),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().length < 2) {
                              return 'Enter the school location';
                            }
                            return null;
                          },
                        ),
                      ),
                    ),
                    Step(
                      title: const Text('Review'),
                      subtitle: const Text('Confirm before creation'),
                      isActive: _step >= 2,
                      content: _ReviewCard(
                        schoolName: _nameController.text.trim(),
                        schoolType: _kind?.label ?? 'Not selected',
                        location: _locationController.text.trim(),
                        organization: widget.organization.organizationName,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _controls(BuildContext context, ControlsDetails details) {
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          FilledButton.icon(
            onPressed: _busy ? null : _continue,
            icon: _busy && _step == 2
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(
                    _step == 2
                        ? Icons.add_business_rounded
                        : Icons.arrow_forward_rounded,
                  ),
            label: Text(_step == 2 ? 'Create school' : 'Continue'),
          ),
          if (_step > 0)
            TextButton(
              onPressed: _busy ? null : () => setState(() => _step -= 1),
              child: const Text('Back'),
            ),
        ],
      ),
    );
  }

  void _goToStep(int target) {
    if (target >= _step) return;
    setState(() {
      _step = target;
      _error = null;
    });
  }

  Future<void> _continue() async {
    setState(() => _error = null);

    if (_step == 0) {
      if (!(_schoolKey.currentState?.validate() ?? false)) return;
      setState(() => _step = 1);
      return;
    }

    if (_step == 1) {
      if (!(_locationKey.currentState?.validate() ?? false)) return;
      setState(() => _step = 2);
      return;
    }

    await _create();
  }

  Future<void> _create() async {
    final kind = _kind;
    if (kind == null || _busy) return;

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final membership = await widget.repository.createSchool(
        widget.organization,
        CreateSchoolDraft(
          name: _nameController.text,
          kind: kind,
          location: _locationController.text,
        ),
      );
      if (!mounted) return;
      Navigator.of(context).pop<SchoolMembership>(membership);
    } on ApiOfflineException catch (error) {
      _showError(error.message);
    } on SessionExpiredException catch (error) {
      _showError(error.message);
    } on ApiException catch (error) {
      _showError(error.message);
    } catch (_) {
      _showError('The school could not be created. Please try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    setState(() => _error = message);
  }
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({
    required this.schoolName,
    required this.schoolType,
    required this.location,
    required this.organization,
  });

  final String schoolName;
  final String schoolType;
  final String location;
  final String organization;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _ReviewRow(label: 'School', value: schoolName),
        _ReviewRow(label: 'Type', value: schoolType),
        _ReviewRow(label: 'Location', value: location),
        _ReviewRow(label: 'Account', value: organization),
      ],
    );
  }
}

class _ReviewRow extends StatelessWidget {
  const _ReviewRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 92,
            child: Text(
              label,
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? 'Not provided' : value,
              style: theme.textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
