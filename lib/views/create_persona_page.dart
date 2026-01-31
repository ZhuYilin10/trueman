import 'package:flutter/material.dart';
import 'package:trueman/data/models.dart';
import 'package:trueman/services/user_persona_service.dart';

class CreatePersonaPage extends StatefulWidget {
  const CreatePersonaPage({super.key});

  @override
  State<CreatePersonaPage> createState() => _CreatePersonaPageState();
}

class _CreatePersonaPageState extends State<CreatePersonaPage> {
  final _nameController = TextEditingController();
  final _systemPromptController = TextEditingController();
  String _selectedAvatar = '😀';
  bool _isSaving = false;

  final List<String> _avatarOptions = [
    '😀', '😎', '🤔', '😊', '🥳', '😎', '🤓', '😏',
    '👨‍💻', '👩‍🎨', '👨‍🔬', '👩‍⚕️', '👨‍🍳', '👷', '🧙', '🦸',
    '🧚', '🧛', '🧜', '🧝', '🧞', '🧟', '👼', '🤖',
    '🐱', '🐶', '🐼', '🦊', '🐻', '🐨', '🐯', '🦁',
    '🍎', '🍕', '🍔', '🌮', '🍣', '🍰', '☕', '🍺',
  ];

  final UserPersonaService _personaService = UserPersonaService();

  void _save() async {
    final name = _nameController.text.trim();
    final systemPrompt = _systemPromptController.text.trim();

    if (name.isEmpty) {
      _showError('请输入角色名');
      return;
    }
    if (systemPrompt.isEmpty) {
      _showError('请输入角色性格描述');
      return;
    }
    if (systemPrompt.length < 10) {
      _showError('性格描述至少需要 10 个字');
      return;
    }

    setState(() => _isSaving = true);

    try {
      await _personaService.createPersona(
        name: name,
        avatar: _selectedAvatar,
        systemPrompt: systemPrompt,
      );

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      _showError('创建失败: $e');
    } finally {
      setState(() => _isSaving = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('创建角色'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 头像选择
            const Text('选择头像', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _avatarOptions.map((avatar) {
                  final isSelected = avatar == _selectedAvatar;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedAvatar = avatar),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: isSelected ? Colors.blue[100] : Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                        border: isSelected
                            ? Border.all(color: Colors.blue, width: 2)
                            : null,
                      ),
                      child: Center(
                        child: Text(
                          avatar,
                          style: const TextStyle(fontSize: 24),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // 角色名
            const Text('角色名', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                hintText: '给你的角色起个名字',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // 性格描述
            const Text('性格描述', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text(
              '描述这个角色的性格、说话风格、习惯等，越详细 AI 越能准确扮演',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _systemPromptController,
              maxLines: 5,
              decoration: InputDecoration(
                hintText: '例如：你是小明，一个乐观开朗的大学生，喜欢开玩笑，说话幽默风趣...',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
            
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                '${_systemPromptController.text.length} 字',
                style: TextStyle(
                  fontSize: 12,
                  color: _systemPromptController.text.length < 10 ? Colors.red : Colors.grey,
                ),
              ),
            ),
            
            const SizedBox(height: 32),
            
            // 创建按钮
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('创建角色', style: TextStyle(fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _systemPromptController.dispose();
    super.dispose();
  }
}
