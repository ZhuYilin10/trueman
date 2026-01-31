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

@embedded
class Like {
  String? id;
  String? userId;
  String? userName;
  String? userAvatar;
  DateTime? timestamp;

  Like({
    this.id,
    this.userId,
    this.userName,
    this.userAvatar,
    this.timestamp,
  });
}

@collection
class Post {
  Id id = Isar.autoIncrement;

  @Index(unique: true, replace: true)
  String uuid;

  Persona? author;
  String? content;
  DateTime? timestamp;
  List<Comment>? comments;
  List<Like>? likes;

  Post({
    String? originalUuid,
    this.author,
    this.content,
    this.timestamp,
    this.comments,
    this.likes,
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
  String? avatar;
  String? systemPrompt;
  List<double>? embedding;
  DateTime? createdAt;

  bool isActive;
  bool isAIAuthor; // 是否会发布自己的动态

  UserPersona({
    String? originalUuid,
    this.name,
    this.avatar,
    this.systemPrompt,
    this.embedding,
    this.createdAt,
    this.isActive = true,
    this.isAIAuthor = false,
  }) : uuid = originalUuid ?? const Uuid().v4();
}

/// 用户关注的 AI 角色
@collection
class Follow {
  Id id = Isar.autoIncrement;

  @Index(unique: true, replace: true)
  String uuid;

  String? userId; // 固定为 'user_me'
  String? personaId; // 被关注的角色 ID
  DateTime? followedAt;

  Follow({
    String? originalUuid,
    this.userId,
    this.personaId,
    this.followedAt,
  }) : uuid = originalUuid ?? const Uuid().v4();
}

/// 真人用户列表（用于模拟真实互动）
class FakeUser {
  final String id;
  final String name;
  final String avatar;
  final List<String> commentTemplates;

  FakeUser(this.id, this.name, this.avatar, this.commentTemplates);
}

final List<FakeUser> fakeUsers = [
  FakeUser('fake_1', '小明', '👨', ['哈哈', '+1', '顶', '👍', '确实']),
  FakeUser('fake_2', '小红', '👩', ['太真实了', '哈哈笑死', 'dddd', '绝绝子']),
  FakeUser('fake_3', '阿伟', '🧑', ['啊这', '我悟了', '学到了', '感谢分享']),
  FakeUser('fake_4', '莉莉', '👧', ['呜呜呜', '好感人', '泪目', '破防了']),
  FakeUser('fake_5', '老张', '👨‍🦰', ['老哥稳', '牛皮', '666', '可以的']),
  FakeUser('fake_6', '小美', '👩‍🦰', ['冲冲冲', '加油', '支持', '爱你呦']),
  FakeUser('fake_7', '阿杰', '🧔', ['就离谱', '太卷了', '躺平', '摆烂']),
  FakeUser('fake_8', '悠悠', '👱‍♀️', ['微笑', 'OK', '收到', '嗯嗯']),
];
