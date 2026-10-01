import 'package:flutter/material.dart';

import '../data/alumni_events_repository.dart';
import '../domain/alumni_event_models.dart';

class AlumniEventsPage extends StatefulWidget {
  const AlumniEventsPage({super.key, required this.repository});

  final AlumniEventsRepository repository;

  @override
  State<AlumniEventsPage> createState() => _AlumniEventsPageState();
}

class _AlumniEventsPageState extends State<AlumniEventsPage> {
  List<AlumniEvent>? _events;
  bool _loading = true;
  String? _error;
  final _rsvping = <String>{};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!widget.repository.hasServer) {
      setState(() {
        _loading = false;
        _events = null;
        _error = null;
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final events = await widget.repository.load();
      if (!mounted) return;
      setState(() {
        _events = events;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '$error';
      });
    }
  }

  Future<void> _rsvp(AlumniEvent event, bool attending) async {
    if (!_rsvping.add(event.id)) return;
    setState(() {});
    try {
      final updated = await widget.repository.rsvp(event.id, attending: attending);
      if (!mounted) return;
      setState(() {
        final events = [...?_events];
        final index = events.indexWhere((item) => item.id == event.id);
        if (index != -1) events[index] = updated;
        _events = events;
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$error')));
    } finally {
      _rsvping.remove(event.id);
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.repository.hasServer) {
      return const _BackendRequiredCard();
    }
    if (_loading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(40),
          child: CircularProgressIndicator(),
        ),
      );
    }
    if (_error != null) {
      return _EventsError(message: _error!, onRetry: _load);
    }

    final events = _events ?? const [];
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          'Events & Reunions',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 5),
        const Text('Real reunions and events the school has organised for its Alumni.'),
        const SizedBox(height: 18),
        if (events.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(22),
              child: Text('No reunion or event has been scheduled yet.'),
            ),
          )
        else
          for (final event in events) ...[
            _EventCard(
              event: event,
              busy: _rsvping.contains(event.id),
              onRsvp: (attending) => _rsvp(event, attending),
            ),
            const SizedBox(height: 10),
          ],
      ],
    );
  }
}

class _EventCard extends StatelessWidget {
  const _EventCard({required this.event, required this.busy, required this.onRsvp});

  final AlumniEvent event;
  final bool busy;
  final ValueChanged<bool> onRsvp;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              event.title,
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17),
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 14,
              runSpacing: 4,
              children: [
                _Meta(Icons.calendar_today_outlined, event.timeText.isEmpty ? event.date : '${event.date} · ${event.timeText}'),
                if (event.venue.trim().isNotEmpty) _Meta(Icons.place_outlined, event.venue),
                _Meta(Icons.people_outline, '${event.attendingCount} attending'),
              ],
            ),
            if (event.note.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(event.note),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                FilledButton.icon(
                  onPressed: busy ? null : () => onRsvp(true),
                  icon: Icon(event.myRsvp == true ? Icons.check_circle : Icons.check_circle_outline, size: 18),
                  label: const Text("I'm attending"),
                ),
                OutlinedButton.icon(
                  onPressed: busy ? null : () => onRsvp(false),
                  icon: Icon(event.myRsvp == false ? Icons.cancel : Icons.cancel_outlined, size: 18),
                  label: const Text('Not attending'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta(this.icon, this.text);

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: Theme.of(context).colorScheme.onSurfaceVariant),
        const SizedBox(width: 4),
        Text(text, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _BackendRequiredCard extends StatelessWidget {
  const _BackendRequiredCard();

  @override
  Widget build(BuildContext context) => const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Card(
            child: Padding(
              padding: EdgeInsets.all(22),
              child: Text('Connect to your school to see Alumni events and reunions.'),
            ),
          ),
        ),
      );
}

class _EventsError extends StatelessWidget {
  const _EventsError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(message),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
}
