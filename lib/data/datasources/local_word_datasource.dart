import '../../domain/entities/word.dart';

class LocalWordDatasource {
  List<Word> getWords() {
    return [
      Word(
        id: 1,
        text: 'presence',
        meaning: '存在',
        sentence: 'Her presence made everyone happy.',
      ),
      Word(
        id: 2,
        text: 'achieve',
        meaning: '達成する',
        sentence: 'He achieved his goal.',
      ),
      Word(
        id: 3,
        text: 'consider',
        meaning: '考慮する',
        sentence: 'Please consider my proposal.',
      ),
      Word(
        id: 4,
        text: 'expand',
        meaning: '拡大する',
        sentence: 'The company plans to expand abroad.',
      ),
      Word(
        id: 5,
        text: 'require',
        meaning: '必要とする',
        sentence: 'This job requires experience.',
      ),
    ];
  }
}
