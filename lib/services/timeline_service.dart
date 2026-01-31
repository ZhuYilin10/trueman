import 'dart:async';
import 'dart:math';
import 'package:trueman/data/models.dart';
import 'package:trueman/services/database_service.dart';
import 'package:trueman/services/llm_service.dart';
import 'package:uuid/uuid.dart';

class TimelineService {
  final DatabaseService _dbService = DatabaseService();
  final LLMService _llmService;
  final Random _random = Random();

  Timer? _timelineTimer;

  TimelineService({LLMService? llmService}) : _llmService = llmService ?? VolcEngineService();

  // Singleton
  static final TimelineService _instance = TimelineService._internal();
  factory TimelineService() => _instance;
  TimelineService._internal();

  Future<void> init() async {
    await _dbService.init();
    _startTimelineLoop();
  }

  void _startTimelineLoop() {
    _timelineTimer?.cancel();
    // 每 30-90 秒随机触发一个 AI 发布动态
    _timelineTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _triggerAIPost();
    });
    print('[TimelineService] AI 时间线服务已启动');
  }

  Future<void> _triggerAIPost() async {
    // 获取所有活跃的 AI 作者角色
    final personas = await _dbService.isar.userPersonas
        .filter()
        .isActiveEqualTo(true)
        .isAIAuthorEqualTo(true)
        .findAll();

    if (personas.isEmpty) return;

    // 随机选择一个角色发布动态
    final persona = personas[_random.nextInt(personas.length)];
    
    // 70% 概率发布动态，30% 概率发布"想法"
    final isThought = _random.nextDouble() < 0.3;
    
    try {
      String? content;
      
      if (isThought) {
        content = await _generateThought(persona);
      } else {
        content = await _generatePost(persona);
      }
      
      if (content != null && content.isNotEmpty) {
        await _publishPost(persona, content, isThought);
        print('[TimelineService] ${persona.name} 发布新动态');
      }
    } catch (e) {
      print('[TimelineService] 生成动态失败: $e');
    }
  }

  Future<String?> _generateThought(Persona persona) async {
    final prompts = [
      '用一句话形容你现在的心情',
      '分享一个今天的小发现',
      '说说你最近在思考什么',
      '用一个词描述今天',
    ];
    final prompt = prompts[_random.nextInt(prompts.length)];
    
    return await _llmService.chatCompletion(
      systemPrompt: '${persona.systemPrompt} 你正在发一条简短的想法/心情。回答要简短，20字以内，用中文。',
      userMessage: prompt,
    );
  }

  Future<String?> _generatePost(Persona persona) async {
    final topics = [
      '今天遇到的一件有趣的事',
      '一个实用的生活小技巧',
      '最近看的一本书/电影',
      '一个让你感动的瞬间',
      '给年轻人的建议',
    ];
    final topic = topics[_random.nextInt(topics.length)];
    
    return await _llmService.chatCompletion(
      systemPrompt: '${persona.systemPrompt} 你正在发一条动态。回答要自然，像真人发朋友圈一样，50字以内，用中文。',
      userMessage: topic,
    );
  }

  Future<void> _publishPost(Persona persona, String content, bool isThought) async {
    final post = Post(
      author: Persona(
        id: persona.id,
        name: persona.name,
        avatar: persona.avatar,
        systemPrompt: persona.systemPrompt,
      ),
      content: isThought ? '💭 $content' : content,
      timestamp: DateTime.now(),
      comments: [],
      likes: [],
    );

    await _dbService.savePost(post);
  }

  // 关注/取消关注
  Future<bool> toggleFollow(String personaId) async {
    await _dbService.init();
    
    final existing = await _dbService.isar.follows
        .filter()
        .userIdEqualTo('user_me')
        .and()
        .personaIdEqualTo(personaId)
        .findFirst();

    if (existing != null) {
      // 已关注，取消
      await _dbService.isar.writeTxn(() async {
        await _dbService.isar.follows.delete(existing.id);
      });
      return false;
    } else {
      // 未关注，添加
      final follow = Follow(
        userId: 'user_me',
        personaId: personaId,
        followedAt: DateTime.now(),
      );
      await _dbService.isar.writeTxn(() async {
        await _dbService.isar.follows.put(follow);
      });
      return true;
    }
  }

  // 获取用户关注的角色列表
  Future<List<String>> getFollowedPersonaIds() async {
    await _dbService.init();
    final follows = await _dbService.isar.follows
        .filter()
        .userIdEqualTo('user_me')
        .findAll();
    return follows.map((f) => f.personaId ?? '').where((id) => id.isNotEmpty).toList();
  }

  // 获取时间线（关注的 AI 发布的动态）
  Future<List<Post>> getTimeline() async {
    await _dbService.init();
    final followedIds = await getFollowedPersonaIds();
    
    if (followedIds.isEmpty) return [];
    
    final allPosts = await _dbService.getAllPosts();
    
    // 只返回 AI 角色发布的动态
    return allPosts.where((post) {
      final authorId = post.author?.id;
      return authorId != null && 
             authorId != 'user_me' && 
             !authorId.startsWith('fake_') &&
             followedIds.contains(authorId);
    }).toList()
      ..sort((a, b) => (b.timestamp ?? DateTime(0)).compareTo(a.timestamp ?? DateTime(0)));
  }

  // 获取所有可关注的 AI 角色（排除已关注的）
  Future<List<UserPersona>> getAvailablePersonas() async {
    await _dbService.init();
    final followedIds = await getFollowedPersonaIds();
    
    final allPersonas = await _dbService.isar.userPersonas
        .filter()
        .isActiveEqualTo(true)
        .findAll();
    
    return allPersonas.where((p) => !followedIds.contains(p.id)).toList();
  }

  void dispose() {
    _timelineTimer?.cancel();
  }
}
