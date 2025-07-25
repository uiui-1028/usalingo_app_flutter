import '../entities/word.dart';
import '../repositories/word_repository.dart';

class GetNextWordUseCase {
  final WordRepository repository;
  int _currentIndex = 0;

  GetNextWordUseCase(this.repository);

  Word? getNextWord() {
    final words = repository.getWords();
    if (_currentIndex < words.length) {
      return words[_currentIndex++];
    }
    return null;
  }

  void reset() {
    _currentIndex = 0;
  }
}
