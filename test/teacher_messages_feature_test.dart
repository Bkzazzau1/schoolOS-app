import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/features/teacher/data/teacher_messages_demo_data.dart';
import 'package:schoolos_app/features/teacher/data/teacher_messages_repository.dart';
import 'package:schoolos_app/features/teacher/domain/teacher_messages_models.dart';
import 'package:schoolos_app/features/teacher/presentation/teacher_messages_page.dart';
import 'package:schoolos_app/shared/models/school_membership.dart';

void main() {
  test('Messages preserves exact website conversation snapshot', () {
    expect(teacherMessageThreads, hasLength(4));
    expect(teacherMessageThreads[0].name, 'JSS 2A Guardians');
    expect(teacherMessageThreads[0].unread, 3);
    expect(teacherMessageThreads[1].name, 'Academic Office');
    expect(teacherMessageThreads[1].type, TeacherMessageChannelType.schoolLeadership);
    expect(teacherMessageThreads[2].name, 'JSS 2B Guardians');
    expect(teacherMessageThreads[2].unread, 1);
    expect(teacherMessageThreads[3].name, 'Mathematics Department');
    expect(teacherMessageThreads[3].type, TeacherMessageChannelType.staffChannel);
    expect(teacherMessageThreads.fold<int>(0, (sum, item) => sum + item.unread), 4);
  });

  test('guardian-group threads are tagged with the real class they belong to', () {
    final guardianGroups = teacherMessageThreads.where((t) => t.type == TeacherMessageChannelType.parentGroup);
    expect(guardianGroups.length, 2);
    for (final thread in guardianGroups) {
      expect(thread.className, isNotNull, reason: '${thread.name} must be scoped to a real class so it can be filtered to the teacher\'s real assignment');
    }
    expect(teacherMessageThreads.firstWhere((t) => t.name == 'JSS 2A Guardians').className, 'JSS 2A');
    // Staff/leadership channels are not class-scoped, so every teacher may see them.
    expect(teacherMessageThreads.firstWhere((t) => t.name == 'Academic Office').className, isNull);
  });

  test('JSS 2A seed conversation preserves exact three website messages', () {
    expect(teacherMessageSeedMessages, hasLength(3));
    expect(teacherMessageSeedMessages[0].body, contains('linear-equations assignment closes tomorrow at 6:00 PM'));
    expect(teacherMessageSeedMessages[1].body, 'Thank you. Is the revision sheet available inside SchoolOS?');
    expect(teacherMessageSeedMessages[2].body, contains('attached to the assignment page'));
    expect(teacherMessageSeedMessages.every((item) => item.threadId == 'thread-1'), isTrue);
  });

  test('message and thread serialization preserve communication evidence', () {
    final thread = TeacherMessageThread.fromJson(teacherMessageThreads.first.toJson());
    final message = TeacherMessage.fromJson(teacherMessageSeedMessages.first.toJson());
    expect(thread.name, 'JSS 2A Guardians');
    expect(thread.type, TeacherMessageChannelType.parentGroup);
    expect(message.direction, TeacherMessageDirection.outgoing);
    expect(message.deliveryState, TeacherMessageDeliveryState.read);
    expect(message.serverMessageId, 'server-msg-1');
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

  testWidgets('thread switching does not leak JSS 2A history into other channels', (tester) async {
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
    expect(find.textContaining('linear-equations assignment closes'), findsOneWidget);

    await tester.tap(find.text('Academic Office'));
    await tester.pump();
    expect(find.textContaining('linear-equations assignment closes'), findsNothing);
    expect(find.text('No cached messages in this approved channel yet.'), findsOneWidget);
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
  List<TeacherMessageThread> threads = List<TeacherMessageThread>.from(teacherMessageThreads);
  List<TeacherMessage> messages = List<TeacherMessage>.from(teacherMessageSeedMessages);

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
