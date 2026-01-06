import 'package:flutter/material.dart';
import 'package:trueman/data/models.dart';
import 'package:trueman/services/ai_service.dart';
import 'package:trueman/services/database_service.dart';
import 'package:trueman/services/simulation_service.dart';
import 'package:uuid/uuid.dart';

class FeedProvider extends ChangeNotifier {
  final SimulationService _simService = SimulationService();
  final AIService _aiService = AIService();
  final DatabaseService _dbService = DatabaseService();
  List<Post> _posts = [];
  // No longer blocking UI

  FeedProvider() {
    _init();
  }

  List<Post> get posts => List.unmodifiable(_posts);
  bool get isGenerating => false; // Always false in background mode
  Comment? get replyingToComment => _replyingToComment;

  Comment? _replyingToComment;

  final Persona _currentUser = Persona(
    id: 'user_me',
    name: 'Me',
    avatar: '😎',
    systemPrompt: '',
  );

  Future<void> _init() async {
    await _dbService.init();
    await _simService.init(); // Initialize simulation loop

    // Listen for new events from simulation
    _simService.onEventProcessed.listen((event) {
      if (event.type == 'comment_reply') {
        _handleNewCommentEvent(event);
      }
    });

    _posts = await _dbService.getAllPosts();
    notifyListeners();
  }

  void _handleNewCommentEvent(SimulationEvent event) async {
    print('[FeedProvider] Received new comment event: ${event.uuid}');
    // Refresh posts from DB to get the latest state including the new comment
    // Optimization: Could just find the post in memory and add it, but refreshing is safer for consistency
    _posts = await _dbService.getAllPosts();
    print('[FeedProvider] Refreshed posts. Count: ${_posts.length}');
    if (_posts.isNotEmpty) {
      final post = _posts.firstWhere((p) => p.uuid == event.targetId,
          orElse: () => _posts.first);
      print(
          '[FeedProvider] Target post comments count: ${post.comments?.length ?? 0}');
    }
    notifyListeners();
  }

  void addPost(String content) async {
    if (content.trim().isEmpty) return;

    final newPost = Post(
      author: _currentUser,
      content: content,
      timestamp: DateTime.now(),
      comments: [], // Initialize list
    );

    // Save to DB and Local List
    await _dbService.savePost(newPost);
    _posts.insert(0, newPost);
    notifyListeners();

    // Trigger AI Planning (Background)
    _aiService.planInteraction(newPost);
  }

  void setReplyTo(Comment? comment) {
    _replyingToComment = comment;
    notifyListeners();
  }

  void addComment(String content) async {
    if (content.trim().isEmpty || _replyingToComment == null) return;

    final targetComment = _replyingToComment!;
    final userComment = Comment(
      id: const Uuid().v4(),
      postId: targetComment.postId,
      author: _currentUser,
      content: content,
      timestamp: DateTime.now(),
      replyToName: targetComment.author?.name,
    );

    // Find post
    final postIndex = _posts.indexWhere((p) => p.uuid == targetComment.postId);
    if (postIndex == -1) return;

    final post = _posts[postIndex];

    // Optimistic Update
    if (post.comments == null) {
      post.comments = [userComment];
    } else {
      post.comments = List.from(post.comments!)..add(userComment);
    }

    // Clear reply state immediately
    _replyingToComment = null;
    notifyListeners();

    // Save user comment
    await _dbService.updatePost(post);

    // AI Reply logic
    // Fire and forget, don't await because planReply is async and we don't want to block UI or wait for it
    _aiService.planReply(userComment, targetComment, post);
  }
}
