import '../domain/driver_messages_models.dart';

final driverMessagesWebsiteSeed = DriverMessagesSnapshot(
  routeId: 'BUS-02',
  vehicle: 'Toyota Coaster · KAD 842 TR',
  threads: [
    DriverMessageThread(
      id: 'driver-thread-transport-control',
      participantName: 'Transport Control',
      participantRole: 'Transport Operations',
      channelLabel: 'Assigned route operations',
      preview: 'Please confirm the afternoon vehicle check before boarding.',
      timeLabel: '13:42',
      unread: true,
      approvedOperationalChannel: true,
      messages: [
        DriverMessageItem(
          id: 'driver-msg-001',
          direction: DriverMessageDirection.schoolToDriver,
          authorLabel: 'Transport Control',
          body: 'Please confirm the afternoon vehicle check before boarding.',
          timeLabel: '13:42',
          state: DriverMessageState.received,
          createdAt: DateTime(2026, 9, 20, 13, 42),
        ),
      ],
    ),
    DriverMessageThread(
      id: 'driver-thread-school-operations',
      participantName: 'School Operations',
      participantRole: 'Administration',
      channelLabel: 'Dismissal and timetable operations',
      preview: 'Primary dismissal is delayed by 10 minutes today.',
      timeLabel: '13:28',
      unread: true,
      approvedOperationalChannel: true,
      messages: [
        DriverMessageItem(
          id: 'driver-msg-002',
          direction: DriverMessageDirection.schoolToDriver,
          authorLabel: 'School Operations',
          body: 'Primary dismissal is delayed by 10 minutes today.',
          timeLabel: '13:28',
          state: DriverMessageState.received,
          createdAt: DateTime(2026, 9, 20, 13, 28),
        ),
      ],
    ),
    DriverMessageThread(
      id: 'driver-thread-maintenance',
      participantName: 'Maintenance & Dispatch',
      participantRole: 'Vehicle Support',
      channelLabel: 'Vehicle defects and replacement dispatch',
      preview: 'BUS-02 remains assigned. Report any dashboard warning before departure.',
      timeLabel: '07:01',
      unread: false,
      approvedOperationalChannel: true,
      messages: [
        DriverMessageItem(
          id: 'driver-msg-003',
          direction: DriverMessageDirection.schoolToDriver,
          authorLabel: 'Maintenance & Dispatch',
          body: 'BUS-02 remains assigned. Report any dashboard warning before departure.',
          timeLabel: '07:01',
          state: DriverMessageState.received,
          createdAt: DateTime(2026, 9, 20, 7, 1),
        ),
      ],
    ),
  ],
  alerts: [
    DriverOperationalAlert(
      id: 'driver-alert-001',
      title: 'Primary dismissal delayed',
      body: 'Primary dismissal begins 10 minutes later than normal today. Do not leave the transport holding area until Transport Control releases the route.',
      priority: DriverAlertPriority.important,
      scopeLabel: 'All afternoon routes',
      timeLabel: '13:25',
      createdAt: DateTime(2026, 9, 20, 13, 25),
    ),
    DriverOperationalAlert(
      id: 'driver-alert-002',
      title: 'Roadworks near Kakuri junction',
      body: 'Expect slower traffic near Kakuri junction. Continue only on the approved route unless Transport Control issues a route change.',
      priority: DriverAlertPriority.routine,
      scopeLabel: 'BUS-02 · Barnawa / Kakuri',
      timeLabel: '06:35',
      createdAt: DateTime(2026, 9, 20, 6, 35),
      read: true,
    ),
  ],
);

const driverMessagingBoundary =
    'Driver messaging is limited to approved internal transport and school-operations channels. Drivers do not directly message parents or guardians from this workspace.';

const driverDeliveryBoundary =
    'Offline messages are stored as Queued. Queued does not mean Sent, Delivered or Read; only server acknowledgement may advance delivery state.';
