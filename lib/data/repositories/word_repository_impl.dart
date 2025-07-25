import '../../domain/entities/word.dart';
import '../../domain/repositories/word_repository.dart';
import '../datasources/local_word_datasource.dart';

class WordRepositoryImpl implements WordRepository {
  final LocalWordDatasource datasource;

  WordRepositoryImpl(this.datasource);

  @override
  List<Word> getWords() => datasource.getWords();
}
