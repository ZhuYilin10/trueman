import 'package:trueman/data/models.dart';
import 'package:trueman/services/database_service.dart';
import 'package:trueman/services/llm_service.dart';
import 'package:uuid/uuid.dart';

class UserPersonaService {
  final DatabaseService _dbService = DatabaseService();
  final LLMService _llmService;
  bool _initialized = false;

  UserPersonaService({LLMService? llmService}) : _llmService = llmService ?? VolcEngineService();

  Future<void> _ensureInitialized() async {
    if (!_initialized) {
      await _dbService.init();
      _initialized = true;
    }
  }

  Future<List<UserPersona>> getAllPersonas() async {
    await _ensureInitialized();
    final personas = await _dbService.isar.userPersonas.where().findAll();
    return personas.where((p) => p.isActive).toList();
  }

  Future<UserPersona?> getPersona(String uuid) async {
    await _ensureInitialized();
    return _dbService.isar.userPersonas.filter().uuidEqualTo(uuid).findFirst();
  }

  Future<UserPersona> createPersona({
    required String name,
    required String avatar,
    required String systemPrompt,
  }) async {
    await _ensureInitialized();

    // 生成 embedding
    List<double>? embedding;
    try {
      embedding = await _llmService.getEmbedding(systemPrompt);
    } catch (e) {
      print('[UserPersonaService] Failed to generate embedding: $e');
    }

    final persona = UserPersona(
      name: name,
      avatar: avatar,
      systemPrompt: systemPrompt,
      embedding: embedding,
      createdAt: DateTime.now(),
      isActive: true,
    );

    await _dbService.isar.writeTxn(() async {
      await _dbService.isar.userPersonas.put(persona);
    });

    return persona;
  }

  Future<void> updatePersona(UserPersona persona) async {
    await _ensureInitialized();
    await _dbService.isar.writeTxn(() async {
      await _dbService.isar.userPersonas.put(persona);
    });
  }

  Future<void> deletePersona(String uuid) async {
    await _ensureInitialized();
    final persona = await _dbService.isar.userPersonas.filter().uuidEqualTo(uuid).findFirst();
    if (persona != null) {
      await _dbService.isar.writeTxn(() async {
        await _dbService.isar.userPersonas.delete(persona.id);
      });
    }
  }

  Future<void> toggleActive(String uuid) async {
    await _ensureInitialized();
    final persona = await _dbService.isar.userPersonas.filter().uuidEqualTo(uuid).findFirst();
    if (persona != null) {
      persona.isActive = !persona.isActive;
      await _dbService.isar.writeTxn(() async {
        await _dbService.isar.userPersonas.put(persona);
      });
    }
  }
}
