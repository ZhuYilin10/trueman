import 'package:flutter/material.dart';
import 'package:trueman/data/models.dart';
import 'package:trueman/services/timeline_service.dart';

class CharactersPage extends StatefulWidget {
  const CharactersPage({super.key});

  @override
  State<CharactersPage> createState() => _CharactersPageState();
}

class _CharactersPageState extends State<CharactersPage> {
  final TimelineService _timelineService = TimelineService();
  List<UserPersona> _personas = [];
  List<String> _followedIds = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    _personas = await _timelineService.getAvailablePersonas();
    _followedIds = await _timelineService.getFollowedPersonaIds();
    setState(() => _isLoading = false);
  }

  Future<void> _toggleFollow(String personaId) async {
    await _timelineService.toggleFollow(personaId);
    _followedIds = await _timelineService.getFollowedPersonaIds();
    setState(() {});
    
    // 提示
    final isFollowed = _followedIds.contains(personaId);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isFollowed ? '已关注' : '已取消关注'),
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('角色'),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _personas.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32.0),
                    child: Text(
                      '还没有创建角色呢~\n去首页点击 + 创建角色吧！',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey, fontSize: 16),
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _personas.length,
                  itemBuilder: (context, index) {
                    final persona = _personas[index];
                    final isFollowed = _followedIds.contains(persona.id);
                    return _buildPersonaCard(persona, isFollowed);
                  },
                ),
    );
  }

  Widget _buildPersonaCard(UserPersona persona, bool isFollowed) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // 头像
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Colors.orange, Colors.deepOrange],
                ),
                borderRadius: BorderRadius.circular(28),
              ),
              child: Center(
                child: Text(
                  persona.avatar ?? '👤',
                  style: const TextStyle(fontSize: 28),
                ),
              ),
            ),
            const SizedBox(width: 16),
            // 信息
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    persona.name ?? '未知角色',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    persona.systemPrompt?.substring(0, min(60, persona.systemPrompt?.length ?? 0)) ?? '',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            // 关注按钮
            ElevatedButton(
              onPressed: () => _toggleFollow(persona.id ?? ''),
              style: ElevatedButton.styleFrom(
                backgroundColor: isFollowed ? Colors.grey[200] : Colors.blue,
                foregroundColor: isFollowed ? Colors.grey[600] : Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: Text(isFollowed ? '已关注' : '关注'),
            ),
          ],
        ),
      ),
    );
  }

  int min(int a, int? b) {
    if (b == null) return a;
    return a < b ? a : b;
  }
}
