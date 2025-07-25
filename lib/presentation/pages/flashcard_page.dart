import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../widgets/flashcard_widget.dart';
import '../theme/app_theme_provider.dart';

class FlashcardPage extends ConsumerWidget {
  const FlashcardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(appThemeProvider);
    return Scaffold(
      backgroundColor: theme.background,
      body: SafeArea(child: Center(child: FlashcardWidget())),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _themeTypeToIndex(ref.watch(appThemeTypeProvider)),
        onTap: (index) {
          ref.read(appThemeTypeProvider.notifier).state = _indexToThemeType(
            index,
          );
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.crop_square), label: 'Flat'),
          BottomNavigationBarItem(icon: Icon(Icons.layers), label: 'Material'),
          BottomNavigationBarItem(icon: Icon(Icons.blur_on), label: 'Neumorph'),
        ],
      ),
    );
  }

  int _themeTypeToIndex(AppThemeType type) {
    switch (type) {
      case AppThemeType.flat:
        return 0;
      case AppThemeType.material:
        return 1;
      case AppThemeType.neumorphism:
        return 2;
      case AppThemeType.mockup:
      default:
        return 1; // デフォルトはMaterial
    }
  }

  AppThemeType _indexToThemeType(int index) {
    switch (index) {
      case 0:
        return AppThemeType.flat;
      case 1:
        return AppThemeType.material;
      case 2:
        return AppThemeType.neumorphism;
      default:
        return AppThemeType.material;
    }
  }
}
