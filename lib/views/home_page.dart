import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:trueman/data/models.dart';
import 'package:trueman/views/characters_page.dart';
import 'package:trueman/views/create_persona_page.dart';

// --- State Management ---
import 'package:trueman/providers/feed_provider.dart';

// --- UI Components ---

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentIndex = 0;
  final List<Widget> _pages = [
    const HomeView(),
    const CharactersPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) => setState(() => _currentIndex = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: '首页',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outline),
            selectedIcon: Icon(Icons.people),
            label: '角色',
          ),
        ],
      ),
    );
  }
}

class HomeView extends StatelessWidget {
  const HomeView({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => FeedProvider(),
      child: const HomeViewContent(),
    );
  }
}

class HomeViewContent extends StatelessWidget {
  const HomeViewContent({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text("Truman's Moment"),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.add),
            onSelected: (value) {
              if (value == 'create_persona') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const CreatePersonaPage(),
                  ),
                );
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'create_persona',
                child: Row(
                  children: [
                    Icon(Icons.person_add, size: 20),
                    SizedBox(width: 8),
                    Text('创建角色'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Consumer<FeedProvider>(
              builder: (context, feed, child) {
                if (feed.posts.isEmpty) {
                  return const Center(
                    child: Text(
                      "World is quiet...\nSay something to wake them up.",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: feed.posts.length,
                  itemBuilder: (context, index) {
                    final post = feed.posts[index];
                    return PostItem(
                        key: ValueKey(
                            '${post.uuid}_${post.comments?.length ?? 0}'),
                        post: post);
                  },
                );
              },
            ),
          ),
          if (context.watch<FeedProvider>().isGenerating)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8.0),
              child: Text("The world is reacting...",
                  style: TextStyle(fontSize: 12, color: Colors.blue)),
            ),
          const InputArea(),
        ],
      ),
    );
  }
}

class PostItem extends StatelessWidget {
  final Post post;

  const PostItem({super.key, required this.post});

  @override
  Widget build(BuildContext context) {
    final authorName = post.author?.name ?? 'Unknown';
    final authorAvatar = post.author?.avatar ?? '?';
    final comments = post.comments ?? [];
    final likes = post.likes ?? [];
    final provider = context.read<FeedProvider>();
    final isLiked = provider.isLiked(post);
    final likeCount = likes.length;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.blueAccent.withOpacity(0.1),
                  child: Text(authorAvatar),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(authorName,
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    if (post.timestamp != null)
                      Text(
                        DateFormat.jm().format(post.timestamp!),
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(post.content ?? '', style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 12),
            // 点赞和评论按钮
            Row(
              children: [
                // 点赞按钮
                GestureDetector(
                  onTap: () => provider.toggleLike(post.uuid),
                  child: Row(
                    children: [
                      Icon(
                        isLiked ? Icons.favorite : Icons.favorite_border,
                        size: 20,
                        color: isLiked ? Colors.red : Colors.grey[600],
                      ),
                      if (likeCount > 0) ...[
                        const SizedBox(width: 4),
                        Text(
                          '$likeCount',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 24),
                // 评论按钮
                Row(
                  children: [
                    Icon(Icons.chat_bubble_outline,
                        size: 20, color: Colors.grey[600]),
                    if (comments.isNotEmpty) ...[
                      const SizedBox(width: 4),
                      Text(
                        '${comments.length}',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(),
            if (comments.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8.0),
                child: Text("No comments yet.",
                    style: TextStyle(color: Colors.grey, fontSize: 12)),
              )
            else
              ...comments.map((comment) => CommentItem(comment: comment)),
          ],
        ),
      ),
    );
  }
}

class CommentItem extends StatelessWidget {
  final Comment comment;

  const CommentItem({super.key, required this.comment});

  @override
  Widget build(BuildContext context) {
    final authorName = comment.author?.name ?? 'Unknown';
    final authorAvatar = comment.author?.avatar ?? '?';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(authorAvatar, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 8),
          Expanded(
            child: GestureDetector(
              onTap: () {
                context.read<FeedProvider>().setReplyTo(comment);
              },
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: RichText(
                            text: TextSpan(
                              children: [
                                TextSpan(
                                  text: authorName,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                    color: Colors.grey[800],
                                  ),
                                ),
                                if (comment.replyToName != null) ...[
                                  WidgetSpan(
                                    alignment: PlaceholderAlignment.middle,
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 4.0),
                                      child: Icon(Icons.arrow_right_alt,
                                          size: 14, color: Colors.grey[500]),
                                    ),
                                  ),
                                  TextSpan(
                                    text: comment.replyToName!,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                      color: Colors.blue[600],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Icon(Icons.reply, size: 14, color: Colors.grey[400]),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(comment.content ?? '',
                        style: const TextStyle(fontSize: 14)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class InputArea extends StatefulWidget {
  const InputArea({super.key});

  @override
  State<InputArea> createState() => _InputAreaState();
}

class _InputAreaState extends State<InputArea> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  void _submit() {
    final text = _controller.text;
    final provider = context.read<FeedProvider>();

    if (text.isNotEmpty) {
      if (provider.replyingToComment != null) {
        provider.addComment(text);
      } else {
        provider.addPost(text);
      }
      _controller.clear();
      FocusScope.of(context).unfocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    final replyingTo = context.watch<FeedProvider>().replyingToComment;

    if (replyingTo != null && !_focusNode.hasFocus) {
      FocusScope.of(context).requestFocus(_focusNode);
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.black12)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (replyingTo != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Row(
                children: [
                  Icon(Icons.reply, size: 16, color: Colors.blue),
                  const SizedBox(width: 8),
                  Text("Replying to ${replyingTo.author?.name ?? 'Unknown'}",
                      style: TextStyle(
                          color: Colors.blue, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, size: 16),
                    onPressed: () =>
                        context.read<FeedProvider>().setReplyTo(null),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  )
                ],
              ),
            ),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  decoration: InputDecoration(
                    hintText: replyingTo != null
                        ? "Write a reply..."
                        : "What's on your mind?",
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: Colors.grey[200],
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 10),
                  ),
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _submit(),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: _submit,
                icon: const Icon(Icons.send),
                color: Colors.blue,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
