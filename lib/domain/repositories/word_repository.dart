import '../entities/word.dart';

abstract class WordRepository {
  List<Word> getWords();
}
