import 'package:isar/isar.dart';
import 'package:uuid/uuid.dart';

part 'models.g.dart';

@embedded
class Persona {
  String? id;
  String? name;
  String? avatar; // Emoji or asset path
  String? systemPrompt; // Personality description

  Persona({
    this.id,
    this.name,
    this.avatar,
    this.systemPrompt,
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

  Comment({
    this.id,
    this.postId,
    this.author,
    this.content,
    this.timestamp,
    this.replyToName,
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
