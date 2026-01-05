import 'dart:convert';
import 'dart:math';
import 'package:dio/dio.dart';
import 'package:trueman/data/models.dart';
import 'package:trueman/data/default_npcs.dart';
import 'package:uuid/uuid.dart';
import 'package:trueman/services/simulation_service.dart';

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

  Future<void> planInteraction(Post post) async {
    // If keys are not set, use mock data
    if (_apiKey == 'YOUR_API_KEY_HERE' ||
        _endpointId == 'YOUR_ENDPOINT_ID_HERE') {
      await _scheduleMockComments(post);
      return;
    }

    print('[AIService] Planning interaction for post: ${post.uuid}');

    List<Persona> selectedNpcs = [];

    // Try to select relevant NPCs based on context
    try {
      print('[AIService] Requesting cloud AI to select NPCs...');
      selectedNpcs = await _selectRelevantNpcs(post.content ?? '');
      print(
          '[AIService] Cloud AI selected ${selectedNpcs.length} NPCs: ${selectedNpcs.map((p) => p.name).join(', ')}');
    } catch (e) {
      print('[AIService] Error selecting NPCs: $e');
    }

    // Fallback to random NPC selection
    if (selectedNpcs.isEmpty) {
      print(
          '[AIService] No NPCs selected by AI (or API failed), falling back to random selection.');
      final random = Random();
      final shuffledCast = List<Persona>.from(_cast)..shuffle(random);
      final count = random.nextInt(10) + 1; // 1 to 10
      selectedNpcs = shuffledCast.take(count).toList();
      print(
          '[AIService] Randomly selected ${selectedNpcs.length} NPCs: ${selectedNpcs.map((p) => p.name).join(', ')}');
    }

    final simService = SimulationService();
    final random = Random();

    // Generate and schedule for each NPC
    for (var npc in selectedNpcs) {
      // Don't await generation sequentially, fire and forget (or parallelize) to not block UI
      // But here we are in an async method called by provider, so it's fine.
      // Better to stagger generation so we don't hit rate limits?
      // Let's generate content now, but schedule for later.

      try {
        print('[AIService] Generating comment content for ${npc.name}...');
        final content = await _fetchResponseProperties(npc, post.content ?? '');

        if (content != null && content.isNotEmpty) {
          print('[AIService] Content generated for ${npc.name}: "$content"');
          final comment = Comment(
            id: const Uuid().v4(),
            postId: post.uuid,
            author: npc,
            content: content,
            timestamp:
                DateTime.now(), // Will be updated/used by SimulationService
          );

          // Calculate delay: Random between 10 seconds and 2 hours (or shorter for demo)
          // Demo mode: 5 seconds to 30 seconds
          final delaySeconds = 5 + random.nextInt(25);
          final targetTime =
              DateTime.now().add(Duration(seconds: delaySeconds));
          print(
              '[AIService] Scheduling comment for ${npc.name} in $delaySeconds seconds (at $targetTime).');

          await simService.scheduleComment(
              post.uuid, comment, Duration(seconds: delaySeconds));
        } else {
          // Fallback if content generation returns null (e.g. API error inside fetch)
          // Only do this for the first few to avoid spamming fails
          // Actually, better to catch at the top level if ALL fail.
          // For now, let's just log.
          print(
              '[AIService] Failed to generate content for ${npc.name} (API returned null/empty).');
        }
      } catch (e) {
        print('[AIService] Error planning comment for ${npc.name}: $e');
      }
    }
    print('[AIService] Interaction planning complete.');
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

  Future<void> planReply(
      Comment userReply, Comment originalComment, Post post) async {
    // If keys are not set, use mock data
    if (_apiKey == 'YOUR_API_KEY_HERE' ||
        _endpointId == 'YOUR_ENDPOINT_ID_HERE') {
      await _scheduleMockReply(userReply, originalComment, post);
      return;
    }

    final npc = originalComment.author;
    if (npc == null) return;

    print(
        '[AIService] Planning reply from ${npc.name} to user comment: "${userReply.content}"');

    final simService = SimulationService();
    final random = Random();

    try {
      // Construct context for the AI
      final contextParts = [
        "Previous conversation:",
        "User posted: \"${post.content}\"",
        "${npc.name} commented: \"${originalComment.content}\"",
        "User replied to ${npc.name}: \"${userReply.content}\""
      ];

      final prompt = contextParts.join("\n");

      print('[AIService] Generating reply content for ${npc.name}...');
      final content = await _fetchResponseProperties(npc, prompt);

      if (content != null && content.isNotEmpty) {
        print('[AIService] Reply content generated: "$content"');

        final comment = Comment(
          id: const Uuid().v4(),
          postId: post.uuid,
          author: npc,
          content: content,
          timestamp: DateTime.now(),
          replyToName: userReply.author?.name,
        );

        // Replies should be faster than initial comments to feel like a "chat"
        // Demo mode: 2 seconds to 15 seconds
        final delaySeconds = 2 + random.nextInt(13);
        final targetTime = DateTime.now().add(Duration(seconds: delaySeconds));
        print(
            '[AIService] Scheduling reply for ${npc.name} in $delaySeconds seconds (at $targetTime).');

        await simService.scheduleComment(
            post.uuid, comment, Duration(seconds: delaySeconds));
      } else {
        print(
            '[AIService] Failed to generate reply for ${npc.name} (API returned null/empty).');
      }
    } catch (e) {
      print('[AIService] Error planning reply for ${npc.name}: $e');
    }
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

  Future<void> _scheduleMockComments(Post post) async {
    final simService = SimulationService();
    final random = Random();

    // Mock 1: Cynical Neighbor in 5 seconds
    await simService.scheduleComment(
      post.uuid,
      Comment(
        id: const Uuid().v4(),
        postId: post.uuid,
        author: _cast[0],
        content: "[MOCK] Hmph, posting again? (Set API Key)",
        timestamp: DateTime.now(),
      ),
      Duration(seconds: 5 + random.nextInt(5)),
    );

    // Mock 2: Gen Z Bestie in 15 seconds
    await simService.scheduleComment(
      post.uuid,
      Comment(
        id: const Uuid().v4(),
        postId: post.uuid,
        author: _cast[1],
        content: "[MOCK] OMG slayyy! ✨ (Set API Key)",
        timestamp: DateTime.now(),
      ),
      Duration(seconds: 15 + random.nextInt(10)),
    );
  }

  Future<void> _scheduleMockReply(
      Comment userReply, Comment originalComment, Post post) async {
    final simService = SimulationService();
    final npc = originalComment.author;
    if (npc == null) return;

    print('[AIService] Scheduling MOCK reply from ${npc.name}');

    final comment = Comment(
      id: const Uuid().v4(),
      postId: post.uuid,
      author: npc,
      content: "[MOCK Reply] Oh really? Interesting. (Set API Key)",
      timestamp: DateTime.now(),
      replyToName: userReply.author?.name,
    );

    await simService.scheduleComment(
        post.uuid, comment, const Duration(seconds: 3));
  }
}
