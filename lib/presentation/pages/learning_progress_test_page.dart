import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/providers.dart';
import '../../domain/entities/learning_progress.dart';

/// 学習進捗管理機能のテストページ
class LearningProgressTestPage extends ConsumerStatefulWidget {
  const LearningProgressTestPage({super.key});

  @override
  ConsumerState<LearningProgressTestPage> createState() =>
      _LearningProgressTestPageState();
}

class _LearningProgressTestPageState
    extends ConsumerState<LearningProgressTestPage> {
  List<LearningProgress> dueTodayCards = [];
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadDueTodayCards();
  }

  Future<void> _loadDueTodayCards() async {
    setState(() {
      isLoading = true;
    });

    try {
      final getDueTodayCards = ref.read(getDueTodayCardsProvider);
      final cards = await getDueTodayCards.execute();
      setState(() {
        dueTodayCards = cards;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('エラーが発生しました: $e')));
      }
    }
  }

  Future<void> _markCardAsCorrect(int wordId) async {
    try {
      final markCardResult = ref.read(markCardResultProvider);
      await markCardResult.markAsCorrect(wordId);
      await _loadDueTodayCards(); // リストを再読み込み
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('正解として記録しました')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('エラーが発生しました: $e')));
      }
    }
  }

  Future<void> _markCardAsIncorrect(int wordId) async {
    try {
      final markCardResult = ref.read(markCardResultProvider);
      await markCardResult.markAsIncorrect(wordId);
      await _loadDueTodayCards(); // リストを再読み込み
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('不正解として記録しました')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('エラーが発生しました: $e')));
      }
    }
  }

  Future<void> _addTestData() async {
    try {
      final markCardResult = ref.read(markCardResultProvider);

      // テストデータを追加（複数回正解を記録してレベルを上げる）
      await markCardResult.markAsCorrect(1); // レベル1 -> 2
      await markCardResult.markAsCorrect(1); // レベル2 -> 3
      await markCardResult.markAsCorrect(2); // レベル1 -> 2
      await markCardResult.markAsIncorrect(3); // レベル1にリセット

      await _loadDueTodayCards();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('テストデータを追加しました')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('エラーが発生しました: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('学習進捗テスト'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadDueTodayCards,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                ElevatedButton(
                  onPressed: _addTestData,
                  child: const Text('テストデータ追加'),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed: _loadDueTodayCards,
                  child: const Text('再読み込み'),
                ),
              ],
            ),
          ),
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : dueTodayCards.isEmpty
                ? const Center(child: Text('今日復習すべきカードはありません'))
                : ListView.builder(
                    itemCount: dueTodayCards.length,
                    itemBuilder: (context, index) {
                      final progress = dueTodayCards[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 4,
                        ),
                        child: ListTile(
                          title: Text('単語ID: ${progress.wordId}'),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('SRSレベル: ${progress.srsLevel}'),
                              Text(
                                '次回復習日: ${progress.nextReviewDate.toString()}',
                              ),
                              Text(
                                '今日復習対象: ${progress.isDueToday ? "はい" : "いいえ"}',
                              ),
                              Text(
                                'マスター済み: ${progress.isMastered ? "はい" : "いいえ"}',
                              ),
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(
                                  Icons.check,
                                  color: Colors.green,
                                ),
                                onPressed: () =>
                                    _markCardAsCorrect(progress.wordId),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.close,
                                  color: Colors.red,
                                ),
                                onPressed: () =>
                                    _markCardAsIncorrect(progress.wordId),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
