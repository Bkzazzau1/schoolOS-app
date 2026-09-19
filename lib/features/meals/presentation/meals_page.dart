import 'package:flutter/material.dart';

import '../data/meal_demo_data.dart';
import '../data/meal_repository.dart';
import '../domain/meal_models.dart';

class MealsPage extends StatefulWidget {
  const MealsPage({
    super.key,
    required this.schoolName,
    required this.repository,
    required this.onBack,
    this.onMealsChanged,
  });

  final String schoolName;
  final MealRepository repository;
  final VoidCallback onBack;
  final VoidCallback? onMealsChanged;

  @override
  State<MealsPage> createState() => _MealsPageState();
}

class _MealsPageState extends State<MealsPage> {
  final _searchController = TextEditingController();
  MealSnapshot? _snapshot;
  String _selectedDay = 'Wednesday';
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final snapshot = await widget.repository.load();
      if (!mounted) return;
      final selectedExists = snapshot.meals.any((meal) => meal.day == _selectedDay);
      setState(() {
        _snapshot = snapshot;
        if (!selectedExists && snapshot.meals.isNotEmpty) {
          _selectedDay = snapshot.meals.first.day;
        }
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

  SchoolMealDay get _selectedMeal {
    final meals = _snapshot?.meals ?? const <SchoolMealDay>[];
    return meals.firstWhere(
      (meal) => meal.day == _selectedDay,
      orElse: () => meals.first,
    );
  }

  List<SchoolMealDay> get _visibleMeals {
    final meals = _snapshot?.meals ?? const <SchoolMealDay>[];
    return meals.where((meal) => meal.matches(_searchController.text)).toList(growable: false);
  }

  Future<void> _editSelectedMeal() async {
    final snapshot = _snapshot;
    if (snapshot == null || !snapshot.permissions.canEditMenu) return;
    final original = _selectedMeal;
    final breakfast = TextEditingController(text: original.breakfast);
    final lunch = TextEditingController(text: original.lunch);
    final snack = TextEditingController(text: original.snack);
    final servings = TextEditingController(text: '${original.servings}');
    final note = TextEditingController(text: original.note);
    var status = original.status;

    final updated = await showDialog<SchoolMealDay>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Edit ${original.day} menu'),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: breakfast,
                    decoration: const InputDecoration(
                      labelText: 'Breakfast',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: lunch,
                    decoration: const InputDecoration(
                      labelText: 'Lunch',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: snack,
                    decoration: const InputDecoration(
                      labelText: 'Snack',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: servings,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Servings',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<MealServiceStatus>(
                    initialValue: status,
                    decoration: const InputDecoration(
                      labelText: 'Service status',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      for (final item in MealServiceStatus.values)
                        DropdownMenuItem(
                          value: item,
                          child: Text(item.label),
                        ),
                    ],
                    onChanged: (value) {
                      if (value != null) setDialogState(() => status = value);
                    },
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: note,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'General menu note',
                      helperText: 'Do not enter child allergy, diagnosis, religion or medical history here.',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final servingCount = int.tryParse(servings.text.trim());
                if (servingCount == null || servingCount < 0) return;
                Navigator.of(dialogContext).pop(
                  original.copyWith(
                    breakfast: breakfast.text.trim(),
                    lunch: lunch.text.trim(),
                    snack: snack.text.trim(),
                    servings: servingCount,
                    status: status,
                    note: note.text.trim(),
                  ),
                );
              },
              child: const Text('Save offline'),
            ),
          ],
        ),
      ),
    );

    breakfast.dispose();
    lunch.dispose();
    snack.dispose();
    servings.dispose();
    note.dispose();

    if (updated == null) return;
    final result = await widget.repository.updateMenuDay(updated);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result.message)));
    if (result.success) {
      widget.onMealsChanged?.call();
      await _load();
    }
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
              Text('Could not load meals: $_error'),
              const SizedBox(height: 12),
              FilledButton(onPressed: _load, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    final snapshot = _snapshot!;
    final selected = _selectedMeal;
    final stats = mealStats(snapshot.meals, selected);
    final theme = Theme.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 850;
        return ListView(
          padding: EdgeInsets.fromLTRB(compact ? 16 : 28, 22, compact ? 16 : 28, 40),
          children: [
            Row(
              children: [
                IconButton(
                  tooltip: 'Back to School Life',
                  onPressed: widget.onBack,
                  icon: const Icon(Icons.arrow_back_rounded),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Meals & Cafeteria',
                        style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
                      ),
                      Text(
                        '${widget.schoolName} · Menus, meal service and safe exceptions',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const Text(
              'Coordinate school meal plans, service counts and approved alternatives while keeping health or dietary details private and visible only to staff who need them.',
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final stat in stats)
                  SizedBox(width: compact ? 160 : 205, child: _StatCard(stat: stat)),
              ],
            ),
            const SizedBox(height: 22),
            if (compact) ...[
              _MenuCard(
                meals: _visibleMeals,
                selectedDay: _selectedDay,
                searchController: _searchController,
                canEdit: snapshot.permissions.canEditMenu,
                onQueryChanged: (_) => setState(() {}),
                onSelected: (day) => setState(() => _selectedDay = day),
                onEdit: _editSelectedMeal,
              ),
              const SizedBox(height: 16),
              _MealSidebar(selected: selected),
            ] else
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 7,
                    child: _MenuCard(
                      meals: _visibleMeals,
                      selectedDay: _selectedDay,
                      searchController: _searchController,
                      canEdit: snapshot.permissions.canEditMenu,
                      onQueryChanged: (_) => setState(() {}),
                      onSelected: (day) => setState(() => _selectedDay = day),
                      onEdit: _editSelectedMeal,
                    ),
                  ),
                  const SizedBox(width: 18),
                  Expanded(flex: 3, child: _MealSidebar(selected: selected)),
                ],
              ),
          ],
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.stat});
  final MealStat stat;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(stat.label, style: theme.textTheme.labelMedium),
            const SizedBox(height: 7),
            Text(stat.value, style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
            const SizedBox(height: 3),
            Text(
              stat.detail,
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

class _MenuCard extends StatelessWidget {
  const _MenuCard({
    required this.meals,
    required this.selectedDay,
    required this.searchController,
    required this.canEdit,
    required this.onQueryChanged,
    required this.onSelected,
    required this.onEdit,
  });

  final List<SchoolMealDay> meals;
  final String selectedDay;
  final TextEditingController searchController;
  final bool canEdit;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<String> onSelected;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Weekly menu', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
                      const SizedBox(height: 4),
                      Text(
                        'This is a sample service week, not a live calendar. Families can later see published menus; sensitive dietary notes stay in restricted staff workflows.',
                        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                if (canEdit) ...[
                  const SizedBox(width: 12),
                  FilledButton.icon(
                    onPressed: onEdit,
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    label: const Text('Edit menu'),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: searchController,
              onChanged: onQueryChanged,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search_rounded),
                hintText: 'Search menu items or day...',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 14),
            if (meals.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 30),
                child: Center(child: Text('No menu days match this search.')),
              )
            else
              for (final meal in meals) ...[
                _MealRow(
                  meal: meal,
                  selected: meal.day == selectedDay,
                  onTap: () => onSelected(meal.day),
                ),
                const SizedBox(height: 10),
              ],
          ],
        ),
      ),
    );
  }
}

class _MealRow extends StatelessWidget {
  const _MealRow({required this.meal, required this.selected, required this.onTap});

  final SchoolMealDay meal;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: selected ? theme.colorScheme.primaryContainer.withValues(alpha: 0.35) : Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            border: Border.all(color: theme.colorScheme.outlineVariant),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.restaurant_menu_rounded),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 7,
                      runSpacing: 7,
                      children: [
                        _Pill(meal.status.label),
                        _Pill('${meal.servings} servings'),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(meal.day, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
                    const SizedBox(height: 4),
                    Text('Breakfast: ${meal.breakfast}'),
                    Text('Lunch: ${meal.lunch} · Snack: ${meal.snack}'),
                    const SizedBox(height: 6),
                    Text(
                      meal.note,
                      style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
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
}

class _MealSidebar extends StatelessWidget {
  const _MealSidebar({required this.selected});
  final SchoolMealDay selected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(17),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'SELECTED DAY',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                Text(selected.day, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
                const SizedBox(height: 10),
                _MenuDetail(value: selected.breakfast, label: 'Breakfast'),
                _MenuDetail(value: selected.lunch, label: 'Lunch'),
                _MenuDetail(value: selected.snack, label: 'Snack'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(17),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'PRIVACY RULE',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(mealPrivacyRule, style: theme.textTheme.bodySmall?.copyWith(height: 1.5)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _MenuDetail extends StatelessWidget {
  const _MenuDetail({required this.value, required this.label});
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label, style: theme.textTheme.labelSmall),
    );
  }
}
