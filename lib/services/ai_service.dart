import 'dart:convert';
import 'dart:math';
import 'package:trueman/data/models.dart';
import 'package:trueman/data/default_npcs.dart';
import 'package:uuid/uuid.dart';
import 'package:trueman/services/simulation_service.dart';
import 'package:trueman/services/llm_service.dart';

class AIService {
  final LLMService _llmService;
  final SimulationService _simService;

  AIService({LLMService? llmService, SimulationService? simService})
      : _llmService = llmService ?? VolcEngineService(),
        _simService = simService ?? SimulationService();

  // Defined Cast of Characters
  final List<Persona> _cast = defaultNpcs;

  List<Persona> get cast => _cast;

  Future<void> planInteraction(Post post) async {
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

    // final simService = SimulationService(); // using _simService
    final random = Random();

    // Generate and schedule for each NPC
    for (var npc in selectedNpcs) {
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

          final delaySeconds = 5 + random.nextInt(25);
          final targetTime =
              DateTime.now().add(Duration(seconds: delaySeconds));
          print(
              '[AIService] Scheduling comment for ${npc.name} in $delaySeconds seconds (at $targetTime).');

          await _simService.scheduleComment(
              post.uuid, comment, Duration(seconds: delaySeconds));

          // Trigger chain reaction!
          // Let other NPCs see this initial comment and potentially react
          _triggerChainReaction(comment, post, parentDelay: delaySeconds);
        } else {
          print(
              '[AIService] Failed to generate content for ${npc.name} (API returned null/empty).');
        }
      } catch (e) {
        print('[AIService] Error planning comment for ${npc.name}: $e');
      }
    }
    print('[AIService] Interaction planning complete.');
  }

  /// Cache for embeddings to avoid re-fetching
  final Map<String, List<double>> _embeddingCache = {};

  Future<List<double>?> _getEmbedding(String text) async {
    if (_embeddingCache.containsKey(text)) {
      return _embeddingCache[text];
    }
    final embedding = await _llmService.getEmbedding(text);
    if (embedding != null) {
      _embeddingCache[text] = embedding;
    }
    return embedding;
  }

  double _cosineSimilarity(List<double> a, List<double> b) {
    if (a.length != b.length) return 0.0;
    double dotProduct = 0.0;
    double normA = 0.0;
    double normB = 0.0;
    for (int i = 0; i < a.length; i++) {
      dotProduct += a[i] * b[i];
      normA += a[i] * a[i];
      normB += b[i] * b[i];
    }
    if (normA == 0 || normB == 0) return 0.0;
    return dotProduct / (sqrt(normA) * sqrt(normB));
  }

  Future<List<Persona>> _selectRelevantNpcs(String content) async {
    // 1. Initialize NPC embeddings
    int initializedCount = 0;
    for (var p in _cast) {
      if (p.embedding == null) {
        final embed = await _getEmbedding(p.systemPrompt ?? p.name ?? '');
        p.embedding = embed;
        if (embed != null) initializedCount++;
      }
    }

    if (initializedCount > 0) {
      print(
          '[AIService] Initialized/Fetched $initializedCount NPC embeddings.');
    }

    // 2. Get embedding for the post content
    final postEmbedding = await _getEmbedding(content);

    if (postEmbedding == null) {
      return [];
    }

    // 3. Calculate Cosine Similarity
    List<MapEntry<Persona, double>> scoredNpcs = [];

    for (var p in _cast) {
      if (p.embedding != null) {
        final score = _cosineSimilarity(postEmbedding, p.embedding!);
        scoredNpcs.add(MapEntry(p, score));
      }
    }

    scoredNpcs.sort((a, b) => b.value.compareTo(a.value));

    // 4. Select Top N Candidates
    final topCandidates = scoredNpcs.take(10).map((e) => e.key).toList();

    if (topCandidates.isEmpty) return [];

    // 5. Ask LLM to refine selection
    final npcListString = topCandidates.map((p) {
      final prompt = p.systemPrompt ?? '';
      return '- ID: ${p.id}, Name: ${p.name}, Role: ${prompt.substring(0, min(50, prompt.length))}...';
    }).join('\n');

    final prompt = '''
Analyze the following social media post and select 3 to 5 NPCs from the SHORTLIST below who would be most likely to react.
Consider relationships, personality, and tone.

Post Content: "$content"

Candidate Shortlist:
$npcListString

Return ONLY a JSON array of the selected NPC IDs. Example: ["npc_1", "npc_5"]
''';

    try {
      print('[AIService] Sending shortlist to LLM...');
      String? result = await _llmService.chatCompletion(
        systemPrompt:
            'You are a casting director. Pick the best actors from the shortlist.',
        userMessage: prompt,
      );

      if (result != null) {
        print('[AIService] LLM Raw Response: $result');

        if (result.startsWith('```json')) {
          result = result.replaceAll('```json', '').replaceAll('```', '');
        } else if (result.startsWith('```')) {
          result = result.replaceAll('```', '');
        }

        final List<dynamic> ids = jsonDecode(result);
        final selected =
            topCandidates.where((p) => ids.contains(p.id)).toList();

        print(
            '[AIService] Final Selection (${selected.length}): ${selected.map((p) => p.name).join(', ')}');
        return selected;
      }
    } catch (e) {
      print('API Request Failed during NPC selection (Refinement): $e');
      return topCandidates.take(3).toList();
    }
    return [];
  }

  Future<void> planReply(
      Comment userReply, Comment originalComment, Post post) async {
    final npc = originalComment.author;
    if (npc == null) return;

    // Check depth limit
    if (userReply.depth >= 5) {
      print(
          '[AIService] Max conversation depth reached (${userReply.depth}). Stopping recursion.');
      return;
    }

    // final simService = SimulationService(); // using _simService
    final random = Random();

    try {
      // Construct context for the AI
      // Decide if we are replying to a user or another NPC
      final replyTargetName = userReply.author?.name ?? "User";

      final contextParts = [
        "Conversation Context:",
        "Original Post by User: \"${post.content}\"",
        "HISTORY:",
        "...(omitted previous turns)...",
        "${replyTargetName} said: \"${userReply.content}\"",
        "Instruction: You are ${npc.name}. Reply to ${replyTargetName}.",
      ];

      final prompt = contextParts.join("\n");

      print(
          '[AIService] Generating reply for ${npc.name} at depth ${userReply.depth + 1}...');
      final content = await _fetchResponseProperties(
          npc, prompt); // Simplified prompt usage

      if (content != null && content.isNotEmpty) {
        final comment = Comment(
          id: const Uuid().v4(),
          postId: post.uuid,
          author: npc,
          content: content,
          timestamp: DateTime.now(),
          replyToName: userReply.author?.name,
          depth: userReply.depth + 1,
        );

        final delaySeconds = 2 + random.nextInt(10);
        await _simService.scheduleComment(
            post.uuid, comment, Duration(seconds: delaySeconds));

        // Trigger chain reaction from OTHER NPCs
        // This comment might annoy someone else!
        await _triggerChainReaction(comment, post, parentDelay: delaySeconds);
      }
    } catch (e) {
      print('[AIService] Error planning reply for ${npc.name}: $e');
    }
  }

  Future<void> _triggerChainReaction(Comment triggerComment, Post post,
      {int parentDelay = 0}) async {
    // 1. Check max depth
    if (triggerComment.depth >= 5) return;

    final random = Random();

    // Reduce fan-out: Only check 1 to 2 candidates max (was 3-5)
    // This dramatically reduces exponential growth.
    int candidateCount = 1 + random.nextInt(2);

    List<Persona> candidates = [];

    // 2. Vector-based Selection
    try {
      final triggerEmbedding =
          await _getEmbedding(triggerComment.content ?? "");

      if (triggerEmbedding != null) {
        // Calculate scores for all NPCs
        List<MapEntry<Persona, double>> scoredNpcs = [];
        for (var p in _cast) {
          // Skip self
          if (p.id == triggerComment.author?.id) continue;

          // Lazy load embedding if needed
          if (p.embedding == null) {
            p.embedding = await _getEmbedding(p.systemPrompt ?? p.name ?? '');
          }

          if (p.embedding != null) {
            double score = _cosineSimilarity(triggerEmbedding, p.embedding!);
            scoredNpcs.add(MapEntry(p, score));
          }
        }

        // Sort by similarity descending
        scoredNpcs.sort((a, b) => b.value.compareTo(a.value));

        // Weighted Selection / Top-K + Random
        // Strategy: Take top 10 most relevant, then randomly pick 2 from them.
        final topPool = scoredNpcs.take(10).map((e) => e.key).toList();
        topPool.shuffle(random);
        candidates = topPool.take(candidateCount).toList();

        print(
            '[AIService] Vector selection found ${candidates.length} relevant candidates from top 10.');
      }
    } catch (e) {
      print('[AIService] Vector selection failed, falling back to random: $e');
    }

    // Fallback to pure random if vector search failed or returned nothing
    if (candidates.isEmpty) {
      final potentialCandidates = List<Persona>.from(_cast)..shuffle(random);
      candidates = potentialCandidates.take(candidateCount).toList();
    }

    print(
        '[AIService] Checking if any of ${candidates.length} NPCs want to reply to ${triggerComment.author?.name}...');

    for (var candidate in candidates) {
      // Double check self-reply
      if (candidate.id == triggerComment.author?.id) continue;

      // 3. Probability check (Decreases with depth)
      // Base chance 30% (was 60%) to prevent explosion
      // Formula: 0.3 / (depth + 1) -> 30%, 15%, 10%, 7%...
      double chance = 0.3 / (triggerComment.depth + 1);

      if (random.nextDouble() < chance) {
        print(
            '[AIService] ${candidate.name} decided to jump in! (Chance: ${(chance * 100).toStringAsFixed(0)}%)');

        // Schedule their reply logic
        _planNpcToNpcReply(candidate, triggerComment, post,
            parentDelay: parentDelay);
      }
    }
  }

  Future<void> _planNpcToNpcReply(Persona me, Comment targetComment, Post post,
      {int parentDelay = 0}) async {
    try {
      final prompt = '''
Conversation Context:
User's Original Post: "${post.content}"
...
${targetComment.author?.name} just said: "${targetComment.content}"

Your Task:
You are ${me.name}.
You heard what ${targetComment.author?.name} said.
Reply to THEM directly.
${me.systemPrompt}
Keep it short, conversational, and in character.
''';

      final content = await _llmService.chatCompletion(
          systemPrompt: "You are ${me.name}. Reply to the comment.",
          userMessage: prompt);

      if (content != null && content.isNotEmpty) {
        final random = Random();
        final comment = Comment(
          id: const Uuid().v4(),
          postId: post.uuid,
          author: me,
          content: content,
          timestamp: DateTime.now(),
          replyToName: targetComment.author?.name,
          depth: targetComment.depth + 1,
        );

        // Give it a bit of delay so they don't appear instantly
        // Ensure child appears AFTER parent (parentDelay + small buffer + random)
        final myDelay = parentDelay + 3 + random.nextInt(10);

        await _simService.scheduleComment(
            post.uuid, comment, Duration(seconds: myDelay));

        // Recursion: This new comment might trigger SOMEONE ELSE
        await _triggerChainReaction(comment, post, parentDelay: myDelay);
      }
    } catch (e) {
      print('Error in NPC-to-NPC reply: $e');
    }
  }

  Future<String?> _fetchResponseProperties(
      Persona persona, String userContent) async {
    final systemPrompt = '''
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
''';

    return _llmService.chatCompletion(
      systemPrompt: systemPrompt,
      userMessage: userContent,
    );
  }
}
