import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import 'package:trueman/data/models.dart';

class DatabaseService {
  late Isar _isar;

  // Singleton pattern
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  Isar get isar => _isar;

  Future<void> init() async {
    if (Isar.instanceNames.contains('default')) {
      _isar = Isar.getInstance('default')!;
      return;
    }

    final dir = await getApplicationDocumentsDirectory();
    _isar = await Isar.open(
      [PostSchema, SimulationEventSchema],
      directory: dir.path,
    );
  }

  Future<void> savePost(Post post) async {
    await _isar.writeTxn(() async {
      await _isar.posts.put(post);
    });
  }

  Future<List<Post>> getAllPosts() async {
    return await _isar.posts.where().sortByTimestampDesc().findAll();
  }

  // To update a post (e.g. adding comments), simply save it again with the same Isar ID
  Future<void> updatePost(Post post) async {
    await savePost(post);
  }
}
