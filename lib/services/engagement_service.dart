import 'dart:async';
import 'dart:math';
import 'package:trueman/data/models.dart';
import 'package:trueman/services/database_service.dart';
import 'package:uuid/uuid.dart';

class EngagementService {
  final DatabaseService _dbService = DatabaseService();
  Timer? _engagementTimer;
  final Random _random = Random();

  // Singleton
  static final EngagementService _instance = EngagementService._internal();
  factory EngagementService() => _instance;
  EngagementService._internal();

  Future<void> init() async {
    await _dbService.init();
    _startEngagementLoop();
  }

  void _startEngagementLoop() {
    _engagementTimer?.cancel();
    // 每 5-15 秒随机触发一次互动
    _engagementTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      _triggerRandomEngagement();
    });
  }

  Future<void> _triggerRandomEngagement() async {
    final posts = await _dbService.getAllPosts();
    if (posts.isEmpty) return;

    // 30% 概率点赞，70% 概率评论
    final shouldLike = _random.nextDouble() < 0.3;
    final targetPost = posts[_random.nextInt(posts.length)];
    
    if (shouldLike) {
      await _addRandomLike(targetPost);
    } else {
      await _addRandomComment(targetPost);
    }
  }

  Future<void> _addRandomLike(Post post) async {
    final fakeUser = fakeUsers[_random.nextInt(fakeUsers.length)];
    
    // 检查是否已经点过赞
    final existingLikes = post.likes ?? [];
    if (existingLikes.any((l) => l.userId == fakeUser.id)) return;

    final like = Like(
      id: const Uuid().v4(),
      userId: fakeUser.id,
      userName: fakeUser.name,
      userAvatar: fakeUser.avatar,
      timestamp: DateTime.now(),
    );

    if (post.likes == null) {
      post.likes = [like];
    } else {
      post.likes = List.from(post.likes!)..add(like);
    }

    await _dbService.updatePost(post);
    print('[Engagement] ${fakeUser.name} 赞了你的帖子');
  }

  Future<void> _addRandomComment(Post post) async {
    final fakeUser = fakeUsers[_random.nextInt(fakeUsers.length)];
    final templates = fakeUser.commentTemplates;
    final content = templates[_random.nextInt(templates.length)];

    // 随机延迟 1-5 秒
    await Future.delayed(Duration(seconds: _random.nextInt(5) + 1));

    final comment = Comment(
      id: const Uuid().v4(),
      postId: post.uuid,
      author: Persona(
        id: fakeUser.id,
        name: fakeUser.name,
        avatar: fakeUser.avatar,
        systemPrompt: '',
      ),
      content: content,
      timestamp: DateTime.now(),
    );

    if (post.comments == null) {
      post.comments = [comment];
    } else {
      post.comments = List.from(post.comments!)..add(comment);
    }

    await _dbService.updatePost(post);
    print('[Engagement] ${fakeUser.name}: $content');
  }

  Future<bool> toggleLike(String postUuid, Persona user) async {
    final post = await _getPost(postUuid);
    if (post == null) return false;

    final existingIndex = (post.likes ?? []).indexWhere((l) => l.userId == user.id);
    
    if (existingIndex >= 0) {
      // 已点赞，取消
      post.likes = List.from(post.likes!)..removeAt(existingIndex);
      await _dbService.updatePost(post);
      return false;
    } else {
      // 未点赞，添加
      final like = Like(
        id: const Uuid().v4(),
        userId: user.id,
        userName: user.name,
        userAvatar: user.avatar,
        timestamp: DateTime.now(),
      );
      if (post.likes == null) {
        post.likes = [like];
      } else {
        post.likes = List.from(post.likes!)..add(like);
      }
      await _dbService.updatePost(post);
      return true;
    }
  }

  Future<Post?> _getPost(String uuid) async {
    final isar = _dbService.isar;
    return isar.posts.filter().uuidEqualTo(uuid).findFirst();
  }

  void dispose() {
    _engagementTimer?.cancel();
  }
}
