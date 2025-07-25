import '../entities/word.dart';
import '../repositories/word_repository.dart';

class GetNextWordUseCase {
  final WordRepository repository;
  int _currentIndex = 0;
  List<Word> _words = [];

  GetNextWordUseCase(this.repository);

  Future<Word?> getNextWord() async {
    if (_words.isEmpty) {
      _words = await repository.fetchAllWords();
    }
    if (_currentIndex < _words.length) {
      return _words[_currentIndex++];
    }
    return null;
  }

  void reset() {
    _currentIndex = 0;
  }
}
