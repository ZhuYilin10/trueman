import 'package:isar/isar.dart';
import 'package:uuid/uuid.dart';

part 'models.g.dart';

@embedded
class Persona {
  String? id;
  String? name;
  String? avatar; // Emoji or asset path
  String? systemPrompt; // Personality description
  // Embedding vector for vector search
  // Not persisted in Isar for now (or could be), just in memory is fine.
  // Actually, let's persist it so we don't re-fetch every restart.
  List<double>? embedding;

  Persona({
    this.id,
    this.name,
    this.avatar,
    this.systemPrompt,
    this.embedding,
  });
}

@embedded
class Comment {
  String? id;
  String? postId;
  Persona? author;
  String? content;
  DateTime? timestamp;
  String? replyToName;

  int depth;

  Comment({
    this.id,
    this.postId,
    this.author,
    this.content,
    this.timestamp,
    this.replyToName,
    this.depth = 0,
  });
}

@collection
class Post {
  Id id = Isar.autoIncrement; // Isar auto-increment ID

  @Index(unique: true, replace: true)
  String uuid; // Stable UUID

  Persona? author; // Can be the user (special persona) or an NPC
  String? content;
  DateTime? timestamp;
  List<Comment>? comments;

  Post({
    String? originalUuid,
    this.author,
    this.content,
    this.timestamp,
    this.comments,
  }) : uuid = originalUuid ?? const Uuid().v4();
}

@collection
class SimulationEvent {
  Id id = Isar.autoIncrement;

  @Index()
  String uuid;

  String? type; // 'comment_reply', etc.
  String? targetId; // Post UUID or Comment UUID

  Comment? payloadComment;

  @Index()
  DateTime? scheduledTime;

  bool isProcessed;

  SimulationEvent({
    String? originalUuid,
    this.type,
    this.targetId,
    this.payloadComment,
    this.scheduledTime,
    this.isProcessed = false,
  }) : uuid = originalUuid ?? const Uuid().v4();
}

/// 用户创建的角色
@collection
class UserPersona {
  Id id = Isar.autoIncrement;

  @Index(unique: true, replace: true)
  String uuid;

  String? name;
  String? avatar; // Emoji
  String? systemPrompt; // 性格描述
  List<double>? embedding;
  DateTime? createdAt;

  bool isActive; // 是否参与互动

  UserPersona({
    String? originalUuid,
    this.name,
    this.avatar,
    this.systemPrompt,
    this.embedding,
    this.createdAt,
    this.isActive = true,
  }) : uuid = originalUuid ?? const Uuid().v4();
}
