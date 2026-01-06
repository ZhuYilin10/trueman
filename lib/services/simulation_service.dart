import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:isar/isar.dart';
import 'package:trueman/data/models.dart';
import 'package:trueman/services/database_service.dart';

class SimulationService {
  final DatabaseService _dbService = DatabaseService();
  Timer? _eventLoopTimer;
  final StreamController<SimulationEvent> _eventStreamController =
      StreamController.broadcast();

  // Singleton pattern to ensure only one event loop exists
  static final SimulationService _instance = SimulationService._internal();
  factory SimulationService() => _instance;
  SimulationService._internal();

  Stream<SimulationEvent> get onEventProcessed => _eventStreamController.stream;

  Future<void> init() async {
    print('[SimulationService] Initializing...');
    // Connect to DB if not already (assuming DB service handles idempotency)
    await _dbService.init();

    // 1. Process events that should have happened while app was closed
    print('[SimulationService] Checking for missed events...');
    await _processMissedEvents();

    // 2. Start event loop
    print('[SimulationService] Starting event loop (tick: 1s).');
    _eventLoopTimer?.cancel();
    // Check every 1 second
    _eventLoopTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _checkAndProcessEvents();
    });
  }

  Future<void> scheduleComment(
      String postUuid, Comment comment, Duration delay) async {
    final scheduledTime = DateTime.now().add(delay);

    final event = SimulationEvent(
      type: 'comment_reply',
      targetId: postUuid,
      payloadComment: comment,
      scheduledTime: scheduledTime,
      isProcessed: false,
    );

    print(
        '[SimulationService] Scheduling event "${event.uuid}" for ${comment.author?.name} at $scheduledTime');

    await _dbService.isar.writeTxn(() async {
      await _dbService.isar.simulationEvents.put(event);
    });

    debugPrint(
        'Scheduled comment from ${comment.author?.name} in ${delay.inSeconds}s (at $scheduledTime)');
  }

  Future<void> _processMissedEvents() async {
    final now = DateTime.now();

    // Find all unprocessed events that should have happened by now
    final missedEvents = await _dbService.isar.simulationEvents
        .filter()
        .isProcessedEqualTo(false)
        .and()
        .scheduledTimeLessThan(now)
        .findAll();

    if (missedEvents.isNotEmpty) {
      print(
          '[SimulationService] Found ${missedEvents.length} missed events. Processing...');

      // Sort by time
      // Sort by time
      missedEvents.sort(
          (a, b) => (a.scheduledTime ?? now).compareTo(b.scheduledTime ?? now));

      List<SimulationEvent> processedEvents = [];

      await _dbService.isar.writeTxn(() async {
        for (var event in missedEvents) {
          print('[SimulationService] Catch-up processing event: ${event.uuid}');
          await _applyEventEffect(event);
          event.isProcessed = true;
          await _dbService.isar.simulationEvents.put(event);
          processedEvents.add(event);
        }
      });

      // Notify UI after commit
      for (var event in processedEvents) {
        _eventStreamController.add(event);
      }

      print('[SimulationService] Missed events processed.');
    } else {
      print('[SimulationService] No missed events found.');
    }
  }

  Future<void> _checkAndProcessEvents() async {
    final isar = _dbService.isar;
    final now = DateTime.now();

    // Find 1 batch of due events
    final dueEvents = await isar.simulationEvents
        .filter()
        .isProcessedEqualTo(false)
        .and()
        .scheduledTimeLessThan(now)
        .findAll();

    if (dueEvents.isEmpty) return;

    List<SimulationEvent> processedEvents = [];

    await isar.writeTxn(() async {
      for (var event in dueEvents) {
        event.isProcessed = true;
        await isar.simulationEvents.put(event);

        // Apply effect
        await _applyEventEffect(event);

        debugPrint(
            'Processed event: ${event.type} for ${event.targetId} from ${event.payloadComment?.author?.name}');

        processedEvents.add(event);
      }
    });

    // Notify UI AFTER transaction commits
    for (var event in processedEvents) {
      _eventStreamController.add(event);
    }
  }

  Future<void> _applyEventEffect(SimulationEvent event) async {
    final isar = _dbService.isar;
    if (event.type == 'comment_reply' && event.payloadComment != null) {
      final post =
          await isar.posts.filter().uuidEqualTo(event.targetId!).findFirst();

      if (post != null) {
        final newComment = event.payloadComment!;
        // Ensure timestamp reflects actual process time? Or scheduled time?
        // Let's use scheduled time to keep "history" correct even if late
        // Actually, if we are late, using scheduled time shows "10 mins ago", which is correct.

        if (post.comments == null) {
          post.comments = [newComment];
        } else {
          post.comments = List.from(post.comments!)..add(newComment);
        }
        await isar.posts.put(post);
      }
    }
  }

  void dispose() {
    _eventLoopTimer?.cancel();
    _eventStreamController.close();
  }
}
