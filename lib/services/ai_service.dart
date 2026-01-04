import 'package:dio/dio.dart';
import 'package:trueman/data/models.dart';
import 'package:uuid/uuid.dart';

class AIService {
  // TODO: Replace with your actual Doubao (Volcengine) API Key and Endpoint ID
  static const String _apiKey = '7380acbd-9067-4433-817a-5e70eb17992a';
  static const String _endpointId = 'doubao-seed-1-6-251015';

  static const String _baseUrl =
      'https://ark.cn-beijing.volces.com/api/v3/chat/completions';

  final Dio _dio = Dio();

  // Defined Cast of Characters
  final List<Persona> _cast = [
    Persona(
      id: 'npc_1',
      name: '老王 (Old Wang)',
      avatar: '😠',
      systemPrompt:
          '你是“老王”，一个愤世嫉俗、脾气暴躁的中年邻居。你喜欢批评一切，但内心深处其实是关心的。你的回复简短、讽刺且有力。你总是能找到角度抱怨社会或年轻人，口头禅是“现在的年轻人啊...”。请用中文回复。',
    ),
    Persona(
      id: 'npc_2',
      name: 'Alice',
      avatar: '✨',
      systemPrompt:
          '你是“Alice”，一个超级热情的 Z 世代女孩。你喜欢使用大量的 Emoji 表情。你非常支持、乐观，并且热爱社交媒体潮流。你表现得像用户最好的闺蜜。请用中文回复，多加 emoji。',
    ),
    Persona(
      id: 'npc_3',
      name: 'Professor X',
      avatar: '🧐',
      systemPrompt:
          '你是“X 教授”，一个知识分子，喜欢通过哲学或量子力学的角度分析一切。你会对简单的日常事件进行深度、有时令人费解的过度分析。请用中文回复，语气深沉。',
    ),
  ];

  List<Persona> get cast => _cast;

  Future<List<Comment>> generateComments(Post post) async {
    // If keys are not set, use mock data
    if (_apiKey == 'YOUR_API_KEY_HERE' ||
        _endpointId == 'YOUR_ENDPOINT_ID_HERE') {
      return _generateMockComments(post);
    }

    List<Comment> comments = [];

    // For MVP, we pick 2 random NPCs to reply or everyone replies. Let's make everyone reply for now to see the effect.
    for (var npc in _cast) {
      try {
        final content = await _fetchResponseProperties(npc, post.content ?? '');
        if (content != null && content.isNotEmpty) {
          comments.add(Comment(
            id: const Uuid().v4(),
            postId: post.uuid,
            author: npc,
            content: content,
            timestamp: DateTime.now(),
          ));
        }
      } catch (e) {
        print('Error generating comment for ${npc.name}: $e');
      }
    }

    return comments;
  }

  Future<Comment?> generateReply(
      Comment userReply, Comment originalComment, Post post) async {
    // If keys are not set, return null or mock response
    if (_apiKey == 'YOUR_API_KEY_HERE' ||
        _endpointId == 'YOUR_ENDPOINT_ID_HERE') {
      // Just mock a reply from the original author
      return _generateMockReply(userReply, originalComment, post);
    }

    final npc = originalComment.author;
    if (npc == null) return null;

    try {
      // Construct context for the AI
      final contextParts = [
        "Previous conversation:",
        "User posted: \"${post.content}\"",
        "${npc.name} commented: \"${originalComment.content}\"",
        "User replied to ${npc.name}: \"${userReply.content}\""
      ];

      final prompt = contextParts.join("\n");
      final content = await _fetchResponseProperties(npc, prompt);

      if (content != null && content.isNotEmpty) {
        return Comment(
          id: const Uuid().v4(),
          postId: post.uuid,
          author: npc,
          content: content,
          timestamp: DateTime.now(),
          replyToName: userReply.author?.name,
        );
      }
    } catch (e) {
      print('Error generating reply for ${npc.name}: $e');
    }

    return null;
  }

  Future<String?> _fetchResponseProperties(
      Persona persona, String userContent) async {
    try {
      final response = await _dio.post(
        _baseUrl,
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $_apiKey',
          },
          sendTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
        ),
        data: {
          'model': _endpointId,
          'messages': [
            {
              'role': 'system',
              'content':
                  '${persona.systemPrompt} 用户刚刚发布了："$userContent"。请以你的角色身份写一条简短的中文评论。保持在 50 字以内。'
            },
            {'role': 'user', 'content': userContent}
          ],
          'stream': false,
        },
      );

      if (response.statusCode == 200) {
        final data = response.data;
        if (data['choices'] != null && data['choices'].isNotEmpty) {
          return data['choices'][0]['message']['content']?.trim();
        }
      }
    } catch (e) {
      print('API Request Failed: $e');
    }
    return null;
  }

  Future<List<Comment>> _generateMockComments(Post post) async {
    await Future.delayed(const Duration(seconds: 2)); // Simulate network delay
    return [
      Comment(
        id: const Uuid().v4(),
        postId: post.uuid,
        author: _cast[0],
        content:
            "[MOCK] Hmph, posting again? Don't you have work to do? (Set API Key to see real AI)",
        timestamp: DateTime.now(),
      ),
      Comment(
        id: const Uuid().v4(),
        postId: post.uuid,
        author: _cast[1],
        content:
            "[MOCK] OMG slayyy! bestie this is amazing! ✨💖 (Set API Key to see real AI)",
        timestamp: DateTime.now().add(const Duration(seconds: 1)),
      ),
    ];
  }

  Future<Comment?> _generateMockReply(
      Comment userReply, Comment originalComment, Post post) async {
    await Future.delayed(const Duration(seconds: 2));
    final npc = originalComment.author;
    if (npc == null) return null;

    return Comment(
      id: const Uuid().v4(),
      postId: post.uuid,
      author: npc,
      content: "[MOCK Reply] Oh really? Interesting. (Set API Key)",
      timestamp: DateTime.now(),
      replyToName: userReply.author?.name,
    );
  }
}
