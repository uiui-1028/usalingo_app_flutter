import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/word.dart';
import '../../data/repositories/word_repository_supabase.dart';

final supabaseWordListProvider = FutureProvider<List<Word>>((ref) async {
  final repo = WordRepositorySupabase();
  return await repo.fetchAllWords();
});

class SupabaseTestPage extends ConsumerWidget {
  const SupabaseTestPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wordListAsync = ref.watch(supabaseWordListProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Supabaseテスト')),
      body: wordListAsync.when(
        data: (words) => ListView.builder(
          itemCount: words.length,
          itemBuilder: (context, i) {
            final word = words[i];
            return ListTile(
              leading: word.imageUrl != null && word.imageUrl!.isNotEmpty
                  ? Image.network(
                      word.imageUrl!,
                      width: 40,
                      height: 40,
                      fit: BoxFit.cover,
                    )
                  : const Icon(Icons.image_not_supported),
              title: Text(word.text),
              subtitle: Text(word.meaning),
              isThreeLine: true,
              trailing: Text(word.tags ?? ''),
            );
          },
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('エラー: $err')),
      ),
    );
  }
}
