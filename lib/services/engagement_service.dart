import 'dart:async';
import 'dart:math';
import 'package:trueman/data/models.dart';
import 'package:trueman/services/database_service.dart';

class EngagementService {
  final DatabaseService _dbService = DatabaseService();
  final Random _random = Random();

  Timer? _engagementTimer;

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
    // 每 10-30 秒随机触发一次互动
    _engagementTimer = Timer.periodic(const Duration(seconds: 15), (timer) {
      _triggerRandomEngagement();
    });
    print('[EngagementService] 真人互动服务已启动');
  }

  Future<void> _triggerRandomEngagement() async {
    // 70% 点赞，30% 评论
    final actionType = _random.nextDouble();
    final posts = await _dbService.getAllPosts();
    if (posts.isEmpty) return;

    final targetPost = posts[_random.nextInt(posts.length)];
    final fakeUser = fakeUsers[_random.nextInt(fakeUsers.length)];

    try {
      if (actionType < 0.7) {
        // 点赞
        await _addLike(targetPost, fakeUser);
      } else {
        // 评论
        await _addComment(targetPost, fakeUser);
      }
    } catch (e) {
      print('[EngagementService] 互动失败: $e');
    }
  }

  Future<bool> _addLike(Post post, FakeUser fakeUser) async {
    // 检查是否已经点赞
    final existingLikes = post.likes ?? [];
    if (existingLikes.any((l) => l.userId == fakeUser.id)) {
      return false;
    }

    final like = Like(
      id: const Uuid().v4(),
      userId: fakeUser.id,
      userName: fakeUser.name,
      userAvatar: fakeUser.avatar,
      timestamp: DateTime.now(),
    );

    await _dbService.updatePostWithLike(post, like);
    print('[EngagementService] ${fakeUser.name} 点赞了');
    return true;
  }

  Future<void> _addComment(Post post, FakeUser fakeUser) async {
    final commentTemplate = fakeUser.commentTemplates[_random.nextInt(fakeUser.commentTemplates.length)];

    final comment = Comment(
      id: const Uuid().v4(),
      postId: post.uuid,
      author: Persona(
        id: fakeUser.id,
        name: fakeUser.name,
        avatar: fakeUser.avatar,
      ),
      content: commentTemplate,
      timestamp: DateTime.now(),
    );

    await _dbService.updatePostWithComment(post, comment);
    print('[EngagementService] ${fakeUser.name} 评论了: $commentTemplate');
  }

  Future<bool> toggleLike(String postUuid, Persona user) async {
    final posts = await _dbService.isar.posts.filter().uuidEqualTo(postUuid).findAll();
    if (posts.isEmpty) return false;
    final post = posts.first;

    final existingLikes = post.likes ?? [];
    final existingIndex = existingLikes.indexWhere((l) => l.userId == user.id);

    if (existingIndex >= 0) {
      // 已点赞，取消
      existingLikes.removeAt(existingIndex);
      post.likes = existingLikes;
      await _dbService.isar.writeTxn(() async {
        await _dbService.isar.posts.put(post);
      });
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
      await _dbService.updatePostWithLike(post, like);
      return true;
    }
  }

  void dispose() {
    _engagementTimer?.cancel();
  }
}
