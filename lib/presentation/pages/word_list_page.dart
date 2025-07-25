import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/word.dart';
import '../../data/repositories/word_repository_sqlite.dart';

final wordListProvider = FutureProvider<List<Word>>((ref) async {
  final repo = WordRepositorySQLite();
  return await repo.fetchAllWords();
});

class WordListPage extends ConsumerWidget {
  const WordListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wordListAsync = ref.watch(wordListProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('単語リスト')),
      body: wordListAsync.when(
        data: (words) => ListView.builder(
          itemCount: words.length,
          itemBuilder: (context, i) {
            final word = words[i];
            return Dismissible(
              key: ValueKey(word.id),
              background: Container(
                color: Colors.red,
                alignment: Alignment.centerRight,
                child: const Padding(
                  padding: EdgeInsets.only(right: 16),
                  child: Icon(Icons.delete, color: Colors.white),
                ),
              ),
              direction: DismissDirection.endToStart,
              onDismissed: (_) async {
                await WordRepositorySQLite().deleteWord(word.id!);
                ref.invalidate(wordListProvider);
              },
              child: ListTile(
                title: Text(word.text),
                subtitle: Text(word.meaning),
                trailing: IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: () => _showWordDialog(context, ref, word: word),
                ),
              ),
            );
          },
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('エラー: $err')),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showWordDialog(context, ref),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showWordDialog(BuildContext context, WidgetRef ref, {Word? word}) {
    final textController = TextEditingController(text: word?.text ?? '');
    final meaningController = TextEditingController(text: word?.meaning ?? '');
    final sentenceController = TextEditingController(
      text: word?.sentence ?? '',
    );
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(word == null ? '単語追加' : '単語編集'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: textController,
              decoration: const InputDecoration(labelText: '英単語'),
            ),
            TextField(
              controller: meaningController,
              decoration: const InputDecoration(labelText: '意味'),
            ),
            TextField(
              controller: sentenceController,
              decoration: const InputDecoration(labelText: '例文'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('キャンセル'),
          ),
          ElevatedButton(
            onPressed: () async {
              final repo = WordRepositorySQLite();
              if (word == null) {
                await repo.insertWord(
                  Word(
                    text: textController.text,
                    meaning: meaningController.text,
                    sentence: sentenceController.text,
                  ),
                );
              } else {
                await repo.updateWord(
                  word.copyWith(
                    text: textController.text,
                    meaning: meaningController.text,
                    sentence: sentenceController.text,
                  ),
                );
              }
              ref.invalidate(wordListProvider);
              Navigator.pop(ctx);
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }
}
