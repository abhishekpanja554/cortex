import 'dart:async';
import 'dart:io';
import 'package:cortex/core/network/ai_event.dart';
import 'package:cortex/core/network/ai_failure.dart';
import 'package:cortex/core/network/sse_client.dart';
import 'package:cortex/core/providers/core_providers.dart';
import 'package:cortex/features/auth/domain/auth_state.dart';
import 'package:cortex/features/auth/presentation/auth_notifier.dart';
import 'package:cortex/features/chat/domain/agent_models.dart';
import 'package:cortex/features/chat/presentation/providers/agent_providers.dart';
import 'package:cortex/features/chat/presentation/state/agent_state.dart';
import 'package:cortex/features/chat/presentation/widgets/agent_turn_bubble.dart';
import 'package:cortex/features/notes/domain/entities/note_entity.dart';
import 'package:cortex/features/notes/domain/entities/note_list_item.dart';
import 'package:cortex/features/notes/presentation/notifiers/note_notifier.dart';
import 'package:cortex/features/notes/presentation/providers/providers.dart';
import 'package:cortex/features/notes/presentation/state/notes_state.dart';
import 'package:cortex/features/sync/data/sync_scheduler.dart';
import 'package:cortex/features/sync/presentation/sync_providers.dart';
import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeSseClient extends Fake implements SseClient {
  Stream<AiEvent> Function(String path, Map<String, dynamic> body, CancelToken? cancelToken)? onPostEvents;
  Future<Map<String, dynamic>> Function(String confirmationId, bool approve, CancelToken? cancelToken)? onConfirmAction;

  int confirmCallCount = 0;

  @override
  Stream<AiEvent> postEvents(
    String path,
    Map<String, dynamic> body, {
    CancelToken? cancelToken,
  }) {
    if (onPostEvents != null) {
      return onPostEvents!(path, body, cancelToken);
    }
    return const Stream.empty();
  }

  @override
  Future<Map<String, dynamic>> confirmAction({
    required String confirmationId,
    required bool approve,
    CancelToken? cancelToken,
  }) {
    confirmCallCount++;
    if (onConfirmAction != null) {
      return onConfirmAction!(confirmationId, approve, cancelToken);
    }
    return Future.value({'status': approve ? 'executed' : 'rejected'});
  }
}

class _FakeAuthNotifier extends AuthNotifier {
  @override
  AuthState build() => Authenticated('test-user');
}

class _FakeSyncScheduler extends Fake implements SyncScheduler {
  bool requestSyncCalled = false;
  int requestSyncCallCount = 0;

  @override
  void requestSync([SyncTrigger trigger = SyncTrigger.manual]) {
    requestSyncCalled = true;
    requestSyncCallCount++;
  }
}

class _FakeNoteNotifier extends NoteNotifier {
  final List<NoteEntity> _notes;
  int getNoteCallCount = 0;
  _FakeNoteNotifier(this._notes);

  @override
  NotesState build() {
    final previews = _notes.map((n) {
      return NotePreview(
        note: n,
        blocks: const [],
        previewText: n.body,
        topTodos: const [],
      );
    }).toList();
    return NotesState(notes: previews);
  }

  @override
  Future<NoteEntity?> getNote(String id) async {
    getNoteCallCount++;
    return _notes.where((n) => n.id == id).firstOrNull;
  }

  @override
  NoteListItem? getNoteById(String id) {
    return state.notes.where((n) => n.id == id).firstOrNull;
  }
}

void main() {
  late _FakeSseClient fakeSseClient;
  late _FakeSyncScheduler fakeSyncScheduler;

  setUp(() {
    fakeSseClient = _FakeSseClient();
    fakeSyncScheduler = _FakeSyncScheduler();
  });

  Widget buildAgentWidget({
    required ProviderContainer container,
    required String turnId,
  }) {
    return UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: AgentTurnBubble(turnId: turnId),
          ),
        ),
      ),
    );
  }

  group('Agent Chat & Approval Flow Tests', () {
    // ------------------------------------------------------------------------
    // Test 1: ToolCall then ToolResult → a step that goes from running to done; Answer → the final text
    // ------------------------------------------------------------------------
    testWidgets(
      '1. ToolCall then ToolResult -> a step that goes from running to done; Answer -> the final text',
      (tester) async {
        final streamController = StreamController<AiEvent>();
        fakeSseClient.onPostEvents = (path, body, cancelToken) {
          expect(path, equals('/agent-chat'));
          expect(body['query'], equals('Find project architecture'));
          return streamController.stream;
        };

        final container = ProviderContainer(
          overrides: [
            authProvider.overrideWith(() => _FakeAuthNotifier()),
            sseClientProvider.overrideWithValue(fakeSseClient),
            syncSchedulerProvider.overrideWithValue(fakeSyncScheduler),
          ],
        );

        final notifier = container.read(agentNotifierProvider.notifier);
        final sendFuture = notifier.send('Find project architecture');

        // Initial pump: user query is rendered, turn is in streaming state
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: Consumer(
              builder: (context, ref, _) {
                final turnId = ref.watch(agentNotifierProvider).turns.first.id;
                return MaterialApp(
                  home: Scaffold(
                    body: AgentTurnBubble(turnId: turnId),
                  ),
                );
              },
            ),
          ),
        );
        await tester.pump();

        expect(find.text('Find project architecture'), findsOneWidget);
        expect(find.text('Thinking…'), findsOneWidget);

        // Emit ToolCall: should show running tool step
        streamController.add(const ToolCall(
          tool: 'search_notes',
          args: {'query': 'architecture'},
        ));
        await tester.pump();

        expect(find.text('Searching notes for "architecture"…'), findsOneWidget);
        // Verify running indicator (activity indicator)
        expect(find.byType(CupertinoActivityIndicator), findsWidgets);

        // Emit ToolResult: tool step transitions from running to done
        streamController.add(const ToolResult(
          tool: 'search_notes',
          result: {
            'results': [
              {
                'note_id': '01e43fa2-d591-4c91-b962-d4b321a50a11',
                'snippet': 'Architecture uses Drift local\n\n…'
              }
            ]
          },
        ));
        await tester.pump();

        expect(find.text('Searched notes for "architecture"'), findsOneWidget);
        expect(find.byIcon(CupertinoIcons.checkmark_circle_fill), findsOneWidget);

        // Emit Answer: final text
        streamController.add(const Answer('Architecture uses Drift and periodic sync.'));
        streamController.add(const Done());
        await streamController.close();
        await sendFuture;
        await tester.pumpAndSettle();

        expect(find.text('Architecture uses Drift and periodic sync.'), findsOneWidget);
        final turn = container.read(agentNotifierProvider).turns.first;
        expect(turn.status, AgentTurnStatus.done);
      },
    );

    // ------------------------------------------------------------------------
    // Test 2: ConfirmationRequired for bulk_delete_notes → the card lists local note titles, and shows "not on this device" for an unknown ID
    // ------------------------------------------------------------------------
    testWidgets(
      '2. ConfirmationRequired for bulk_delete_notes -> the card lists local note titles, and shows "not on this device" for an unknown ID',
      (tester) async {
        final existingNote1 = NoteEntity(
          id: 'note-local-1',
          title: 'Project Architecture',
          body: 'Local Drift note body',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        final existingNote2 = NoteEntity(
          id: 'note-local-2',
          title: 'Groceries List',
          body: 'Milk, Eggs',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        final container = ProviderContainer(
          overrides: [
            authProvider.overrideWith(() => _FakeAuthNotifier()),
            sseClientProvider.overrideWithValue(fakeSseClient),
            syncSchedulerProvider.overrideWithValue(fakeSyncScheduler),
            noteNotifierProvider.overrideWith(
              () => _FakeNoteNotifier([existingNote1, existingNote2]),
            ),
          ],
        );

        final notifier = container.read(agentNotifierProvider.notifier);
        const confirmation = AgentConfirmation(
          confirmationId: 'conf-bulk-1',
          tool: 'bulk_delete_notes',
          args: {
            'note_ids': [
              'note-local-1',
              'note-unknown-999',
              'note-local-2',
            ]
          },
          resolution: ConfirmationResolution.pending,
        );

        final turn = const AgentTurn(
          id: 'turn-bulk',
          query: 'Delete these notes',
          confirmation: confirmation,
          status: AgentTurnStatus.awaitingConfirmation,
        );

        notifier.state = AgentState(turns: [turn]);

        await tester.pumpWidget(
          buildAgentWidget(container: container, turnId: 'turn-bulk'),
        );
        await tester.pump();

        // Approval card header
        expect(find.byKey(const ValueKey('agent_approval_card')), findsOneWidget);
        expect(find.text('Delete Notes'), findsOneWidget);

        // Verify local note titles are listed
        expect(find.text('Project Architecture'), findsOneWidget);
        expect(find.text('Groceries List'), findsOneWidget);

        // Verify unknown note shows "not on this device"
        expect(find.text('not on this device'), findsOneWidget);

        // Both Approve and Discard buttons are present
        expect(find.byKey(const ValueKey('agent_approve_button')), findsOneWidget);
        expect(find.byKey(const ValueKey('agent_reject_button')), findsOneWidget);
      },
    );

    // ------------------------------------------------------------------------
    // Test 3: Approve → executed → card shows done, and requestSync() is called
    // ------------------------------------------------------------------------
    testWidgets(
      '3. Approve -> executed -> card shows done, and requestSync() is called',
      (tester) async {
        fakeSseClient.onConfirmAction = (confirmationId, approve, cancelToken) async {
          expect(confirmationId, equals('conf-123'));
          expect(approve, isTrue);
          return {'status': 'executed', 'result': {'deleted': 1}};
        };

        final container = ProviderContainer(
          overrides: [
            authProvider.overrideWith(() => _FakeAuthNotifier()),
            sseClientProvider.overrideWithValue(fakeSseClient),
            syncSchedulerProvider.overrideWithValue(fakeSyncScheduler),
            noteNotifierProvider.overrideWith(() => _FakeNoteNotifier([])),
          ],
        );

        final notifier = container.read(agentNotifierProvider.notifier);
        notifier.state = const AgentState(
          turns: [
            AgentTurn(
              id: 'turn-1',
              query: 'Delete note',
              confirmation: AgentConfirmation(
                confirmationId: 'conf-123',
                tool: 'delete_note',
                args: {'note_id': 'note-1'},
                resolution: ConfirmationResolution.pending,
              ),
              status: AgentTurnStatus.awaitingConfirmation,
            ),
          ],
        );

        await tester.pumpWidget(
          buildAgentWidget(container: container, turnId: 'turn-1'),
        );
        await tester.pump();

        // Tap Approve
        await tester.tap(find.byKey(const ValueKey('agent_approve_button')));
        await tester.pumpAndSettle();

        // Card shows done
        expect(find.text('Done'), findsOneWidget);
        expect(find.byIcon(CupertinoIcons.checkmark_alt), findsOneWidget);

        // requestSync was called
        expect(fakeSyncScheduler.requestSyncCalled, isTrue);
        expect(fakeSyncScheduler.requestSyncCallCount, equals(1));
      },
    );

    // ------------------------------------------------------------------------
    // Test 4: Reject → rejected → card shows "Discarded", and no sync
    // ------------------------------------------------------------------------
    testWidgets(
      '4. Reject -> rejected -> card shows "Discarded", and no sync',
      (tester) async {
        fakeSseClient.onConfirmAction = (confirmationId, approve, cancelToken) async {
          expect(confirmationId, equals('conf-reject-1'));
          expect(approve, isFalse);
          return {'status': 'rejected', 'message': 'Action discarded.'};
        };

        final container = ProviderContainer(
          overrides: [
            authProvider.overrideWith(() => _FakeAuthNotifier()),
            sseClientProvider.overrideWithValue(fakeSseClient),
            syncSchedulerProvider.overrideWithValue(fakeSyncScheduler),
            noteNotifierProvider.overrideWith(() => _FakeNoteNotifier([])),
          ],
        );

        final notifier = container.read(agentNotifierProvider.notifier);
        notifier.state = const AgentState(
          turns: [
            AgentTurn(
              id: 'turn-reject',
              query: 'Delete note',
              confirmation: AgentConfirmation(
                confirmationId: 'conf-reject-1',
                tool: 'delete_note',
                args: {'note_id': 'note-1'},
                resolution: ConfirmationResolution.pending,
              ),
              status: AgentTurnStatus.awaitingConfirmation,
            ),
          ],
        );

        await tester.pumpWidget(
          buildAgentWidget(container: container, turnId: 'turn-reject'),
        );
        await tester.pump();

        // Tap Discard
        await tester.tap(find.byKey(const ValueKey('agent_reject_button')));
        await tester.pumpAndSettle();

        // Card shows Discarded
        expect(find.text('Discarded'), findsOneWidget);

        // NO sync called!
        expect(fakeSyncScheduler.requestSyncCalled, isFalse);
        expect(fakeSyncScheduler.requestSyncCallCount, equals(0));
      },
    );

    // ------------------------------------------------------------------------
    // Test 5: Tapping Approve twice quickly → exactly one confirm request
    // ------------------------------------------------------------------------
    testWidgets(
      '5. Tapping Approve twice quickly -> exactly one confirm request',
      (tester) async {
        final completer = Completer<Map<String, dynamic>>();
        fakeSseClient.onConfirmAction = (confirmationId, approve, cancelToken) {
          return completer.future;
        };

        final container = ProviderContainer(
          overrides: [
            authProvider.overrideWith(() => _FakeAuthNotifier()),
            sseClientProvider.overrideWithValue(fakeSseClient),
            syncSchedulerProvider.overrideWithValue(fakeSyncScheduler),
            noteNotifierProvider.overrideWith(() => _FakeNoteNotifier([])),
          ],
        );

        final notifier = container.read(agentNotifierProvider.notifier);
        notifier.state = const AgentState(
          turns: [
            AgentTurn(
              id: 'turn-double',
              query: 'Delete note',
              confirmation: AgentConfirmation(
                confirmationId: 'conf-double-1',
                tool: 'delete_note',
                args: {'note_id': 'note-1'},
                resolution: ConfirmationResolution.pending,
              ),
              status: AgentTurnStatus.awaitingConfirmation,
            ),
          ],
        );

        await tester.pumpWidget(
          buildAgentWidget(container: container, turnId: 'turn-double'),
        );
        await tester.pump();

        // First tap initiates confirm request
        await tester.tap(find.byKey(const ValueKey('agent_approve_button')));
        // Immediately second tap before future resolves
        await tester.tap(find.byKey(const ValueKey('agent_approve_button')));
        await tester.pump();

        expect(fakeSseClient.confirmCallCount, equals(1));

        // Complete the first call
        completer.complete({'status': 'executed'});
        await tester.pumpAndSettle();

        expect(fakeSseClient.confirmCallCount, equals(1));
        expect(fakeSyncScheduler.requestSyncCalled, isTrue);
      },
    );

    // ------------------------------------------------------------------------
    // Test 6: The confirm request throws AiUnavailable → the card can be tapped again.
    // A retry that gets already_executed → card shows done, and requestSync()
    // ------------------------------------------------------------------------
    testWidgets(
      '6. The confirm request throws AiUnavailable -> the card can be tapped again. A retry that gets already_executed -> card shows done, and requestSync()',
      (tester) async {
        var callCount = 0;
        fakeSseClient.onConfirmAction = (confirmationId, approve, cancelToken) async {
          callCount++;
          if (callCount == 1) {
            // First call drops network connection
            throw const AiUnavailable('Network connection dropped');
          } else {
            // Retry finds the pending action was already executed on the server before the network drop (409 conflict)
            return {
              'status': 'already_executed',
              'message': 'Action already carried out.',
            };
          }
        };

        final container = ProviderContainer(
          overrides: [
            authProvider.overrideWith(() => _FakeAuthNotifier()),
            sseClientProvider.overrideWithValue(fakeSseClient),
            syncSchedulerProvider.overrideWithValue(fakeSyncScheduler),
            noteNotifierProvider.overrideWith(() => _FakeNoteNotifier([])),
          ],
        );

        final notifier = container.read(agentNotifierProvider.notifier);
        notifier.state = const AgentState(
          turns: [
            AgentTurn(
              id: 'turn-lost-response',
              query: 'Delete note',
              confirmation: AgentConfirmation(
                confirmationId: 'conf-lost-1',
                tool: 'delete_note',
                args: {'note_id': '01e43fa2-d591-4c91-b962-d4b321a50a11'},
                resolution: ConfirmationResolution.pending,
              ),
              status: AgentTurnStatus.awaitingConfirmation,
            ),
          ],
        );

        await tester.pumpWidget(
          buildAgentWidget(container: container, turnId: 'turn-lost-response'),
        );
        await tester.pump();

        // 1st Tap: Fails with AiUnavailable
        await tester.tap(find.byKey(const ValueKey('agent_approve_button')));
        await tester.pumpAndSettle();

        expect(callCount, equals(1));
        // Error banner is shown, and button is enabled to be tapped again
        expect(find.text('Network connection dropped'), findsOneWidget);
        expect(find.byKey(const ValueKey('agent_approve_button')), findsOneWidget);
        expect(fakeSyncScheduler.requestSyncCalled, isFalse);

        // 2nd Tap (Retry): Server returns already_executed because it was carried out
        await tester.tap(find.byKey(const ValueKey('agent_approve_button')));
        await tester.pumpAndSettle();

        expect(callCount, equals(2));
        // Shows Done badge
        expect(find.text('Done'), findsOneWidget);
        // And requestSync() was called to pull the result
        expect(fakeSyncScheduler.requestSyncCalled, isTrue);
      },
    );

    testWidgets(
      '6b. Status in_progress sets error allowing retry; not_found marks unavailable without sync; already_rejected marks rejected without sync',
      (tester) async {
        final container = ProviderContainer(
          overrides: [
            authProvider.overrideWith(() => _FakeAuthNotifier()),
            sseClientProvider.overrideWithValue(fakeSseClient),
            syncSchedulerProvider.overrideWithValue(fakeSyncScheduler),
            noteNotifierProvider.overrideWith(() => _FakeNoteNotifier([])),
          ],
        );

        final notifier = container.read(agentNotifierProvider.notifier);

        // Sub-case 1: in_progress
        fakeSseClient.onConfirmAction = (confirmationId, approve, cancelToken) async {
          return {
            'status': 'in_progress',
            'message': 'Action is being processed.',
          };
        };

        notifier.state = const AgentState(
          turns: [
            AgentTurn(
              id: 'turn-inprogress',
              query: 'Delete note',
              confirmation: AgentConfirmation(
                confirmationId: 'conf-prog-1',
                tool: 'delete_note',
                args: {'note_id': '01e43fa2-d591-4c91-b962-d4b321a50a11'},
                resolution: ConfirmationResolution.pending,
              ),
              status: AgentTurnStatus.awaitingConfirmation,
            ),
          ],
        );

        await tester.pumpWidget(
          buildAgentWidget(container: container, turnId: 'turn-inprogress'),
        );
        await tester.pump();

        await tester.tap(find.byKey(const ValueKey('agent_approve_button')));
        await tester.pumpAndSettle();

        expect(find.text('Still being carried out — try again in a moment.'), findsOneWidget);
        // Buttons remain enabled for retry
        expect(find.byKey(const ValueKey('agent_approve_button')), findsOneWidget);
        expect(fakeSyncScheduler.requestSyncCalled, isFalse);

        // Sub-case 2: not_found (truly missing)
        fakeSseClient.onConfirmAction = (confirmationId, approve, cancelToken) async {
          return {
            'status': 'not_found',
            'message': 'Pending action not found or not yours.',
          };
        };

        notifier.state = const AgentState(
          turns: [
            AgentTurn(
              id: 'turn-notfound',
              query: 'Delete note',
              confirmation: AgentConfirmation(
                confirmationId: 'conf-missing-1',
                tool: 'delete_note',
                args: {'note_id': '01e43fa2-d591-4c91-b962-d4b321a50a11'},
                resolution: ConfirmationResolution.pending,
              ),
              status: AgentTurnStatus.awaitingConfirmation,
            ),
          ],
        );

        await tester.pumpWidget(
          buildAgentWidget(container: container, turnId: 'turn-notfound'),
        );
        await tester.pump();

        await tester.tap(find.byKey(const ValueKey('agent_approve_button')));
        await tester.pumpAndSettle();

        expect(find.text('Unavailable'), findsOneWidget);
        expect(find.text('This action is no longer available.'), findsOneWidget);
        expect(fakeSyncScheduler.requestSyncCalled, isFalse);

        // Sub-case 3: already_rejected
        fakeSseClient.onConfirmAction = (confirmationId, approve, cancelToken) async {
          return {
            'status': 'already_rejected',
            'message': 'Action discarded.',
          };
        };

        notifier.state = const AgentState(
          turns: [
            AgentTurn(
              id: 'turn-alreadyrej',
              query: 'Delete note',
              confirmation: AgentConfirmation(
                confirmationId: 'conf-rej-1',
                tool: 'delete_note',
                args: {'note_id': '01e43fa2-d591-4c91-b962-d4b321a50a11'},
                resolution: ConfirmationResolution.pending,
              ),
              status: AgentTurnStatus.awaitingConfirmation,
            ),
          ],
        );

        await tester.pumpWidget(
          buildAgentWidget(container: container, turnId: 'turn-alreadyrej'),
        );
        await tester.pump();

        await tester.tap(find.byKey(const ValueKey('agent_approve_button')));
        await tester.pumpAndSettle();

        expect(find.text('Discarded'), findsOneWidget);
        expect(fakeSyncScheduler.requestSyncCalled, isFalse);
      },
    );

    // ------------------------------------------------------------------------
    // Test 7: The real sequence […, error, done] and a dropped stream behave the same as in chat.
    // Capture a real /agent-chat stream ending in confirmation_required as a fixture
    // ------------------------------------------------------------------------
    testWidgets(
      '7. The real sequence [..., error, done] and a dropped stream behave the same as in chat. Capture a real /agent-chat stream ending in confirmation_required as a fixture',
      (tester) async {
        // Part A: Sequence [ToolCall, AiError, Done] does not overwrite error with done
        final streamControllerA = StreamController<AiEvent>();
        fakeSseClient.onPostEvents = (path, body, cancelToken) {
          return streamControllerA.stream;
        };

        final container = ProviderContainer(
          overrides: [
            authProvider.overrideWith(() => _FakeAuthNotifier()),
            sseClientProvider.overrideWithValue(fakeSseClient),
            syncSchedulerProvider.overrideWithValue(fakeSyncScheduler),
            noteNotifierProvider.overrideWith(() => _FakeNoteNotifier([])),
          ],
        );

        final notifier = container.read(agentNotifierProvider.notifier);
        final sendFutureA = notifier.send('Broken agent query');

        streamControllerA.add(const ToolCall(tool: 'search_notes', args: {'query': 'fail'}));
        streamControllerA.add(const AiError('Agent exceeded max tool call steps.'));
        streamControllerA.add(const Done());
        await streamControllerA.close();
        await sendFutureA;

        final turnA = container.read(agentNotifierProvider).turns.first;
        expect(turnA.status, equals(AgentTurnStatus.error));
        expect(turnA.errorText, equals('Agent exceeded max tool call steps.'));

        // Part B: Cleanly dropped stream before done -> marks turn as error with "Connection lost" and step as interrupted
        final streamControllerB = StreamController<AiEvent>();
        fakeSseClient.onPostEvents = (path, body, cancelToken) {
          return streamControllerB.stream;
        };

        notifier.clear();
        final sendFutureB = notifier.send('Dropped stream query');

        streamControllerB.add(const ToolCall(tool: 'search_notes', args: {'query': 'drop'}));
        await tester.pump();
        expect(container.read(agentNotifierProvider).turns.first.steps.first.status, equals(AgentStepStatus.running));

        // Clean drop: stream closes without a Done event
        await streamControllerB.close();
        await sendFutureB;
        await tester.pumpAndSettle();

        final turnB = container.read(agentNotifierProvider).turns.first;
        expect(container.read(agentNotifierProvider).isStreaming, isFalse);
        expect(turnB.status, equals(AgentTurnStatus.error));
        expect(turnB.errorText, equals('Connection lost'));
        expect(turnB.steps.first.status, equals(AgentStepStatus.interrupted));

        // Part C: Verify real captured fixture test/fixtures/agent_stream_confirmation.txt
        final fixtureFile = File('test/fixtures/agent_stream_confirmation.txt');
        expect(fixtureFile.existsSync(), isTrue);

        final bytes = fixtureFile.readAsBytesSync();
        final events = await SseClient.parseEvents(Stream.value(bytes)).toList();
        expect(events.length, equals(4));
        expect(events[0], isA<ToolCall>());
        expect((events[0] as ToolCall).tool, equals('search_notes'));
        expect((events[0] as ToolCall).args['query'], equals('Goa'));
        expect(events[1], isA<ToolResult>());
        expect((events[1] as ToolResult).tool, equals('search_notes'));
        expect((events[1] as ToolResult).result, isA<Map>());
        expect(events[2], isA<ConfirmationRequired>());
        final confEvent = events[2] as ConfirmationRequired;
        expect(confEvent.tool, equals('delete_note'));
        expect(confEvent.args['note_id'], equals('01e43fa2-d591-4c91-b962-d4b321a50a11'));
        expect(events[3], isA<Done>());

        // Feed fixture into notifier
        fakeSseClient.onPostEvents = (path, body, cancelToken) {
          return Stream.fromIterable(events);
        };

        notifier.clear();
        await notifier.send('Delete my note about Goa');

        final turnC = container.read(agentNotifierProvider).turns.first;
        expect(turnC.status, equals(AgentTurnStatus.awaitingConfirmation));
        expect(turnC.steps.length, equals(1));
        expect(turnC.steps.first.status, equals(AgentStepStatus.done));
        expect(turnC.confirmation, isNotNull);
        expect(turnC.confirmation!.tool, equals('delete_note'));
        expect(turnC.confirmation!.confirmationId, equals('c7a8b9c0-1234-5678-9abc-def012345678'));
      },
    );

    // ------------------------------------------------------------------------
    // Test 8: Confirm request with unexpected/non-map response throws AiServerError and shows error banner without syncing
    // ------------------------------------------------------------------------
    testWidgets(
      '8. Confirm request with unexpected/non-map response throws AiServerError and shows error banner without syncing',
      (tester) async {
        fakeSseClient.onConfirmAction = (confirmationId, approve, cancelToken) async {
          // Simulating proxy error or unexpected non-map response that throws AiServerError
          throw const AiServerError('Unexpected response from approval server');
        };

        final container = ProviderContainer(
          overrides: [
            authProvider.overrideWith(() => _FakeAuthNotifier()),
            sseClientProvider.overrideWithValue(fakeSseClient),
            syncSchedulerProvider.overrideWithValue(fakeSyncScheduler),
            noteNotifierProvider.overrideWith(() => _FakeNoteNotifier([])),
          ],
        );

        final notifier = container.read(agentNotifierProvider.notifier);
        notifier.state = const AgentState(
          turns: [
            AgentTurn(
              id: 'turn-unexpected',
              query: 'Delete note',
              confirmation: AgentConfirmation(
                confirmationId: 'conf-unexp-1',
                tool: 'delete_note',
                args: {'note_id': '01e43fa2-d591-4c91-b962-d4b321a50a11'},
                resolution: ConfirmationResolution.pending,
              ),
              status: AgentTurnStatus.awaitingConfirmation,
            ),
          ],
        );

        await tester.pumpWidget(
          buildAgentWidget(container: container, turnId: 'turn-unexpected'),
        );
        await tester.pump();

        await tester.tap(find.byKey(const ValueKey('agent_approve_button')));
        await tester.pumpAndSettle();

        // Error banner is shown, sync was NOT called, and buttons are re-enabled
        expect(find.text('Unexpected response from approval server'), findsOneWidget);
        expect(fakeSyncScheduler.requestSyncCalled, isFalse);
        expect(find.byKey(const ValueKey('agent_approve_button')), findsOneWidget);
      },
    );

    // ------------------------------------------------------------------------
    // Test 9: ToolResult for create_note triggers requestSync() immediately
    // ------------------------------------------------------------------------
    testWidgets(
      '9. ToolResult for create_note triggers requestSync() so new notes appear without manual refresh',
      (tester) async {
        final streamController = StreamController<AiEvent>();

        fakeSseClient.onPostEvents = (path, body, cancelToken) {
          return streamController.stream;
        };

        final container = ProviderContainer(
          overrides: [
            authProvider.overrideWith(() => _FakeAuthNotifier()),
            sseClientProvider.overrideWithValue(fakeSseClient),
            syncSchedulerProvider.overrideWithValue(fakeSyncScheduler),
          ],
        );

        final notifier = container.read(agentNotifierProvider.notifier);
        final sendFuture = notifier.send('Create a note titled Grocery List');

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: Consumer(
              builder: (context, ref, _) {
                final turnId = ref.watch(agentNotifierProvider).turns.first.id;
                return MaterialApp(
                  home: Scaffold(
                    body: AgentTurnBubble(turnId: turnId),
                  ),
                );
              },
            ),
          ),
        );
        await tester.pump();

        // 1. ToolCall create_note
        streamController.add(const ToolCall(
          tool: 'create_note',
          args: {'title': 'Grocery List', 'body': 'Milk, Eggs, Bread'},
        ));
        await tester.pump();

        expect(find.text('Creating note "Grocery List"…'), findsOneWidget);
        expect(fakeSyncScheduler.requestSyncCalled, isFalse);

        // 2. ToolResult create_note: should immediately trigger requestSync()
        streamController.add(const ToolResult(
          tool: 'create_note',
          result: {
            'note_id': 'new-note-uuid-1234',
            'status': 'created',
          },
        ));
        await tester.pump();

        expect(fakeSyncScheduler.requestSyncCalled, isTrue);
        expect(find.text('Created note "Grocery List"'), findsOneWidget);

        // 3. Emit Answer and Done
        streamController.add(const Answer('I created the note "Grocery List" for you.'));
        streamController.add(const Done());
        await streamController.close();
        await sendFuture;
        await tester.pumpAndSettle();

        expect(find.text('I created the note "Grocery List" for you.'), findsOneWidget);
        expect(fakeSyncScheduler.requestSyncCalled, isTrue);
      },
    );

    testWidgets(
      'Rebuilding AgentApprovalCard caches getNote query and does not re-query on every rebuild',
      (tester) async {
        final existingNote = NoteEntity(
          id: 'note-cached-1',
          title: 'Cached Title',
          body: 'Cached Body',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        final fakeNotifier = _FakeNoteNotifier([existingNote]);
        final container = ProviderContainer(
          overrides: [
            authProvider.overrideWith(() => _FakeAuthNotifier()),
            sseClientProvider.overrideWithValue(fakeSseClient),
            syncSchedulerProvider.overrideWithValue(fakeSyncScheduler),
            noteNotifierProvider.overrideWith(() => fakeNotifier),
          ],
        );

        final agentNotifier = container.read(agentNotifierProvider.notifier);
        const confirmation = AgentConfirmation(
          confirmationId: 'conf-cache-1',
          tool: 'delete_note',
          args: {'note_id': 'note-cached-1'},
          resolution: ConfirmationResolution.pending,
        );

        final turn = const AgentTurn(
          id: 'turn-cache',
          query: 'Delete cached note',
          confirmation: confirmation,
          status: AgentTurnStatus.awaitingConfirmation,
        );

        agentNotifier.state = AgentState(turns: [turn]);

        await tester.pumpWidget(
          buildAgentWidget(container: container, turnId: 'turn-cache'),
        );
        await tester.pump();

        expect(find.text('Cached Title'), findsOneWidget);
        final initialQueries = fakeNotifier.getNoteCallCount;
        expect(initialQueries, greaterThanOrEqualTo(1));

        // Trigger multiple rebuilds
        for (int i = 0; i < 5; i++) {
          await tester.pumpWidget(
            buildAgentWidget(container: container, turnId: 'turn-cache'),
          );
          await tester.pump();
        }

        // Must still have the exact same number of getNote calls, not 1 per rebuild!
        expect(fakeNotifier.getNoteCallCount, equals(initialQueries));
      },
    );
  });
}
