import 'package:flutter/material.dart';
import 'package:trueman/data/models.dart';
import 'package:trueman/services/ai_service.dart';
import 'package:trueman/services/database_service.dart';
import 'package:trueman/services/engagement_service.dart';
import 'package:trueman/services/simulation_service.dart';
import 'package:uuid/uuid.dart';

class FeedProvider extends ChangeNotifier {
  final SimulationService _simService = SimulationService();
  final AIService _aiService = AIService();
  final EngagementService _engagementService = EngagementService();
  final DatabaseService _dbService = DatabaseService();
  List<Post> _posts = [];

  FeedProvider() {
    _init();
  }

  List<Post> get posts => List.unmodifiable(_posts);
  bool get isGenerating => false;
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
    await _simService.init();
    await _engagementService.init();

    _simService.onEventProcessed.listen((event) {
      if (event.type == 'comment_reply') {
        _handleNewCommentEvent(event);
      }
    });

    _posts = await _dbService.getAllPosts();
    for (var post in _posts) {
      if (post.comments != null && post.comments!.isNotEmpty) {
        post.comments!.sort((a, b) =>
            (a.timestamp ?? DateTime(0)).compareTo(b.timestamp ?? DateTime(0)));
      }
    }
    notifyListeners();
  }

  void _handleNewCommentEvent(SimulationEvent event) async {
    print('[FeedProvider] Received new comment event: ${event.uuid}');
    _posts = await _dbService.getAllPosts();

    for (var post in _posts) {
      if (post.comments != null && post.comments!.isNotEmpty) {
        post.comments!.sort((a, b) =>
            (a.timestamp ?? DateTime(0)).compareTo(b.timestamp ?? DateTime(0)));
      }
    }
    notifyListeners();
  }

  void addPost(String content) async {
    if (content.trim().isEmpty) return;

    final newPost = Post(
      author: _currentUser,
      content: content,
      timestamp: DateTime.now(),
      comments: [],
      likes: [],
    );

    await _dbService.savePost(newPost);
    _posts.insert(0, newPost);
    notifyListeners();

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

    final postIndex = _posts.indexWhere((p) => p.uuid == targetComment.postId);
    if (postIndex == -1) return;

    final post = _posts[postIndex];

    if (post.comments == null) {
      post.comments = [userComment];
    } else {
      post.comments = List.from(post.comments!)..add(userComment);
    }

    _replyingToComment = null;
    notifyListeners();

    await _dbService.updatePost(post);

    _aiService.planReply(userComment, targetComment, post);
  }

  Future<bool> toggleLike(String postUuid) async {
    final result = await _engagementService.toggleLike(postUuid, _currentUser);
    if (result) {
      final post = _posts.firstWhere((p) => p.uuid == postUuid);
      final freshPost = await _dbService.isar.posts.filter().uuidEqualTo(postUuid).findFirst();
      if (freshPost != null) {
        final index = _posts.indexWhere((p) => p.uuid == postUuid);
        _posts[index] = freshPost;
        notifyListeners();
      }
    }
    return result;
  }

  bool isLiked(Post post) {
    return (post.likes ?? []).any((l) => l.userId == _currentUser.id);
  }
}
