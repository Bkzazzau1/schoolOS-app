import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/features/teacher/data/teacher_messages_demo_data.dart';
import 'package:schoolos_app/features/teacher/data/teacher_messages_repository.dart';
import 'package:schoolos_app/features/teacher/domain/teacher_messages_models.dart';
import 'package:schoolos_app/features/teacher/presentation/teacher_messages_page.dart';
import 'package:schoolos_app/shared/models/school_membership.dart';

// The fake channels/messages this page's own rendering is tested against. Guardian-group
// (parentGroup) channels are real now - built from the teacher's real assigned classes in
// teacher_messages_repository.dart, never demo furniture - so this page-level suite exercises
// them through its own literal fixture rather than the production demo constants (which now hold
// only the two channel types with no real backend yet: staff/leadership). See
// test/teacher_messages_roster_test.dart for the real guardian-group channel's own behaviour.
const _fakeThreads = <TeacherMessageThread>[
  TeacherMessageThread(id: 'thread-1', name: 'JSS 2A Guardians', type: TeacherMessageChannelType.parentGroup, preview: 'Send a real announcement to 2 real families.', timeLabel: '', unread: 0, className: 'JSS 2A'),
  TeacherMessageThread(id: 'thread-2', name: 'Academic Office', type: TeacherMessageChannelType.schoolLeadership, preview: 'Week 6 lesson-plan review completed.', timeLabel: 'Yesterday', unread: 0),
  TeacherMessageThread(id: 'thread-4', name: 'Mathematics Department', type: TeacherMessageChannelType.staffChannel, preview: 'Department meeting moved to Thursday.', timeLabel: 'Mon', unread: 0),
];

const _fakeMessages = <TeacherMessage>[
  TeacherMessage(id: 'msg-seed-1', threadId: 'thread-2', direction: TeacherMessageDirection.outgoing, body: 'Please see the attached lesson-plan review summary.', timeLabel: 'Yesterday', deliveryState: TeacherMessageDeliveryState.read, serverMessageId: 'server-msg-1'),
];

void main() {

  test('message and thread serialization preserve communication evidence', () {
    final thread = TeacherMessageThread.fromJson(_fakeThreads.first.toJson());
    expect(thread.name, 'JSS 2A Guardians');
    expect(thread.type, TeacherMessageChannelType.parentGroup);
    expect(thread.className, 'JSS 2A');
  });

  test('delivery and AI boundaries prevent false communication claims', () {
    expect(teacherMessageDeliveryBoundary, contains('not sent, delivered or read'));
    expect(teacherMessageDeliveryBoundary, contains('authoritative'));
    expect(teacherMessagePrivacyBoundary, contains('Private guardian phone numbers'));
    expect(teacherMessageAiBoundary, contains('teacher must review'));
    expect(teacherMessageAiBoundary, contains('cannot send autonomously'));
  });

  test('teacher can queue but cannot self-confirm delivery states', () {
    final fake = _FakeMessagesRepository();
    const teacher = SchoolMembership(
      id: 'teacher-1',
      schoolId: 'school-1',
      schoolName: 'BrightGate Academy',
      role: SchoolRole.teacher,
    );
    const student = SchoolMembership(
      id: 'student-1',
      schoolId: 'school-1',
      schoolName: 'BrightGate Academy',
      role: SchoolRole.student,
    );
    final permissions = fake.permissionsFor(teacher);
    expect(permissions.canViewApprovedChannels, isTrue);
    expect(permissions.canQueueMessages, isTrue);
    expect(permissions.canUseAiDraft, isTrue);
    expect(permissions.canViewPrivateContactDetails, isFalse);
    expect(permissions.canConfirmSent, isFalse);
    expect(permissions.canConfirmDelivered, isFalse);
    expect(permissions.canConfirmRead, isFalse);
    expect(fake.permissionsFor(student).canQueueMessages, isFalse);
  });

  testWidgets('Messages renders website channels and search filters them', (tester) async {
    tester.view.physicalSize = const Size(1400, 4000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TeacherMessagesPage(
            repository: _FakeMessagesRepository(),
            onNavigate: (_) {},
            onMutationQueued: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Messages'), findsOneWidget);
    expect(find.text('JSS 2A Guardians'), findsWidgets);
    expect(find.text('Academic Office'), findsOneWidget);
    expect(find.text('Mathematics Department'), findsOneWidget);

    final fields = find.byType(TextField);
    await tester.enterText(fields.first, 'Academic');
    await tester.pump();
    expect(find.text('Academic Office'), findsOneWidget);
    expect(find.text('Mathematics Department'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('thread switching does not leak one channel\'s content into another', (tester) async {
    tester.view.physicalSize = const Size(1400, 4000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TeacherMessagesPage(
            repository: _FakeMessagesRepository(),
            onNavigate: (_) {},
            onMutationQueued: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('No cached messages in this approved channel yet.'), findsOneWidget);
    expect(find.textContaining('attached lesson-plan review summary'), findsNothing);

    await tester.tap(find.text('Academic Office'));
    await tester.pump();
    expect(find.text('No cached messages in this approved channel yet.'), findsNothing);
    expect(find.textContaining('attached lesson-plan review summary'), findsOneWidget);
  });

  testWidgets('Send queues locally without claiming Sent or Delivered', (tester) async {
    tester.view.physicalSize = const Size(1400, 4000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final fake = _FakeMessagesRepository();
    var mutations = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TeacherMessagesPage(
            repository: fake,
            onNavigate: (_) {},
            onMutationQueued: () => mutations++,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(1), 'Please review the revision guidance.');
    await tester.tap(find.widgetWithText(FilledButton, 'Send'));
    await tester.pumpAndSettle();

    expect(fake.messages.last.deliveryState, TeacherMessageDeliveryState.queued);
    expect(fake.messages.last.serverMessageId, isNull);
    expect(find.text('Queued'), findsWidgets);
    expect(find.textContaining('Sent, delivered and read status require authoritative acknowledgement'), findsOneWidget);
    expect(mutations, 1);
  });

  testWidgets('Teacher AI drafts but does not queue a message automatically', (tester) async {
    tester.view.physicalSize = const Size(1400, 4000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final fake = _FakeMessagesRepository();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TeacherMessagesPage(
            repository: fake,
            onNavigate: (_) {},
            onMutationQueued: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final before = fake.messages.length;
    await tester.tap(find.widgetWithText(OutlinedButton, 'AI draft'));
    await tester.pump();
    final fields = tester.widgetList<TextField>(find.byType(TextField)).toList();
    expect(fields[1].controller?.text, teacherMessageAiDraft);
    expect(fake.messages.length, before);
    expect(find.textContaining('Nothing has been sent'), findsOneWidget);
  });

  testWidgets('Messages routes to Students, Classes and Teacher AI', (tester) async {
    tester.view.physicalSize = const Size(1400, 4000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    String? destination;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TeacherMessagesPage(
            repository: _FakeMessagesRepository(),
            onNavigate: (value) => destination = value,
            onMutationQueued: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(OutlinedButton, 'Students'));
    expect(destination, 'students');
    await tester.tap(find.widgetWithText(OutlinedButton, 'My Classes'));
    expect(destination, 'classes');
    await tester.ensureVisible(find.text('Open Teacher AI'));
    await tester.tap(find.text('Open Teacher AI'));
    expect(destination, 'ai');
  });

  testWidgets('Messages renders on phone without exceptions', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TeacherMessagesPage(
            repository: _FakeMessagesRepository(),
            onNavigate: (_) {},
            onMutationQueued: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Conversations'), findsOneWidget);
    expect(find.text('JSS 2A Guardians'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}

class _FakeMessagesRepository implements TeacherMessagesRepository {
  List<TeacherMessageThread> threads = List<TeacherMessageThread>.from(_fakeThreads);
  List<TeacherMessage> messages = List<TeacherMessage>.from(_fakeMessages);

  @override
  Future<void> markThreadSeen(String threadId) async {}

  @override
  TeacherMessagePermissions permissionsFor(SchoolMembership membership) {
    final teacher = membership.role == SchoolRole.teacher;
    return TeacherMessagePermissions(
      canViewApprovedChannels: teacher,
      canQueueMessages: teacher,
      canViewPrivateContactDetails: false,
      canConfirmSent: false,
      canConfirmDelivered: false,
      canConfirmRead: false,
      canUseAiDraft: teacher,
    );
  }

  @override
  Future<TeacherMessagesSnapshot> load() async => TeacherMessagesSnapshot(
        threads: threads,
        messages: messages,
        permissions: permissionsFor(
          const SchoolMembership(
            id: 'teacher-1',
            schoolId: 'school-1',
            schoolName: 'BrightGate Academy',
            role: SchoolRole.teacher,
          ),
        ),
      );

  @override
  Future<TeacherMessageActionResult> queueMessage({
    required String threadId,
    required String body,
    String? attachmentName,
  }) async {
    if (body.trim().isEmpty) {
      return const TeacherMessageActionResult(success: false, message: 'Write a professional school message before sending.');
    }
    final queued = TeacherMessage(
      id: 'fake-${messages.length}',
      threadId: threadId,
      direction: TeacherMessageDirection.outgoing,
      body: body.trim(),
      timeLabel: 'Queued',
      deliveryState: TeacherMessageDeliveryState.queued,
      createdAt: '2026-09-20T04:55:00Z',
      attachmentName: attachmentName,
    );
    messages = [...messages, queued];
    return TeacherMessageActionResult(
      success: true,
      message: 'Message queued locally. Sent, delivered and read status require authoritative acknowledgement.',
      queuedMessage: queued,
    );
  }
}
