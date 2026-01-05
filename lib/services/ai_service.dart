import 'dart:convert';
import 'dart:math';
import 'package:dio/dio.dart';
import 'package:trueman/data/models.dart';
import 'package:trueman/data/default_npcs.dart';
import 'package:uuid/uuid.dart';

class AIService {
  // TODO: Replace with your actual Doubao (Volcengine) API Key and Endpoint ID
  static const String _apiKey = '7380acbd-9067-4433-817a-5e70eb17992a';
  static const String _endpointId = 'doubao-seed-1-6-251015';

  static const String _baseUrl =
      'https://ark.cn-beijing.volces.com/api/v3/chat/completions';

  final Dio _dio = Dio();

  // Defined Cast of Characters
  // Defined Cast of Characters
  final List<Persona> _cast = defaultNpcs;

  List<Persona> get cast => _cast;

  Future<List<Comment>> generateComments(Post post) async {
    // If keys are not set, use mock data
    if (_apiKey == 'YOUR_API_KEY_HERE' ||
        _endpointId == 'YOUR_ENDPOINT_ID_HERE') {
      return _generateMockComments(post);
    }

    List<Comment> comments = [];
    List<Persona> selectedNpcs = [];

    // Try to select relevant NPCs based on context
    try {
      selectedNpcs = await _selectRelevantNpcs(post.content ?? '');
    } catch (e) {
      print('Error selecting NPCs: $e');
    }

    // Fallback to random selection if AI selection fails or returns empty
    if (selectedNpcs.isEmpty) {
      print('Falling back to random NPC selection');
      final random = Random();
      final shuffledCast = List<Persona>.from(_cast)..shuffle(random);
      final count = random.nextInt(10) + 1; // 1 to 10
      selectedNpcs = shuffledCast.take(count).toList();
    }

    for (var npc in selectedNpcs) {
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

  Future<List<Persona>> _selectRelevantNpcs(String content) async {
    // 1. Prepare a simplified list of NPCs for the prompt to save tokens
    final npcListString = _cast.map((p) {
      final prompt = p.systemPrompt ?? '';
      return '- ID: ${p.id}, Name: ${p.name}, Role: ${prompt.substring(0, min(50, prompt.length))}...';
    }).join('\n');

    final prompt = '''
Analyze the following social media post and select 3 to 8 NPCs from the list below who would be most likely to react.
Consider relationships (family, friends), personality (hobbies, traits), and the tone of the post.
If the post implies a specific context (e.g. asking for help, sharing good news), choose NPCs that fit that context.

Post Content: "$content"

NPC List:
$npcListString

Return ONLY a JSON array of the selected NPC IDs. Example: ["npc_1", "npc_5", "npc_20"]
''';

    try {
      final response = await _dio.post(
        _baseUrl,
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $_apiKey',
          },
          sendTimeout: const Duration(seconds: 60),
          receiveTimeout: const Duration(seconds: 60),
        ),
        data: {
          'model': _endpointId,
          'messages': [
            {
              'role': 'system',
              'content':
                  'You are a casting director for a social simulation game. You select the most appropriate characters to interact with a user post.'
            },
            {'role': 'user', 'content': prompt}
          ],
          'stream': false,
        },
      );

      if (response.statusCode == 200) {
        final data = response.data;
        if (data['choices'] != null && data['choices'].isNotEmpty) {
          String content = data['choices'][0]['message']['content']?.trim();
          // Cleanup potential markdown code blocks
          if (content.startsWith('```json')) {
            content = content.replaceAll('```json', '').replaceAll('```', '');
          } else if (content.startsWith('```')) {
            content = content.replaceAll('```', '');
          }

          final List<dynamic> ids = jsonDecode(content);
          final selected = _cast.where((p) => ids.contains(p.id)).toList();

          // Ensure we don't have too many (cap at 10) or too few (min 1 fallback handled by caller if empty, but here let's return what we found)
          return selected;
        }
      }
    } catch (e) {
      print('API Request Failed during NPC selection: $e');
    }
    return [];
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
              'content': '''
${persona.systemPrompt}

User posted: "$userContent"

Instruction:
Reply to the user's post in character.
CRITICAL: Stop sounding like an AI. Be "real".
- If your character is sarcastic, be extremely sarcastic and mean.
- If your character is a flatterer, be over-the-top.
- If your character is caring, be genuinely worried.
- Use internet slang, emojis, and informal punctuation (like multiple ??? or !!!) if it fits.
- Keep it under 50 words.
- Reply in Chinese.
                  '''
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
