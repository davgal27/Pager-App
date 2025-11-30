import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'home_page.dart';
import 'reading_page.dart';
import 'to_read_page.dart';
import 'finished_page.dart';
import 'library_page.dart';

class PagerApp extends StatelessWidget {
  const PagerApp({super.key});

  static const Color _primaryBrown = Color(0xFF5F3416);
  static const Color _background = Color(0xFFF5F0E8);

  ThemeData _buildTheme() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: _primaryBrown,
      brightness: Brightness.light,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: _background,
      appBarTheme: AppBarTheme(
        backgroundColor: _primaryBrown,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: _primaryBrown,
          statusBarIconBrightness: Brightness.light,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: _primaryBrown),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: _primaryBrown,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
        ),
      ),
      inputDecorationTheme: const InputDecorationTheme(
        labelStyle: TextStyle(color: _primaryBrown),
        focusedBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: _primaryBrown),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pager',
      debugShowCheckedModeBanner: false,
      theme: _buildTheme(),
      home: const PagerShell(),
    );
  }
}

class PagerShell extends StatefulWidget {
  const PagerShell({super.key});

  @override
  State<PagerShell> createState() => _PagerShellState();
}

class _PagerShellState extends State<PagerShell> {
  int _currentIndex = 0;

  Widget _buildBody() {
    switch (_currentIndex) {
      case 0:
        return const HomePage();
      case 1:
        return const ReadingPage();
      case 2:
        return const ToReadPage();
      case 3:
        return const FinishedPage();
      case 4:
        return const LibraryPage();
      default:
        return const HomePage();
    }
  }

  @override
  Widget build(BuildContext context) {
    const bottomBackground = Color(0xFFFDF5ED);
    const activeColor = Color(0xFF5F3416);
    const inactiveColor = Colors.grey;

    return Scaffold(
      body: _buildBody(),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: bottomBackground,
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        selectedItemColor: activeColor,
        unselectedItemColor: inactiveColor,
        showUnselectedLabels: true,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.menu_book_outlined),
            activeIcon: Icon(Icons.menu_book),
            label: 'Reading',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.bookmark_border),
            activeIcon: Icon(Icons.bookmark),
            label: 'To read',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.check_circle_outline),
            activeIcon: Icon(Icons.check_circle),
            label: 'Finished',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.library_books_outlined),
            activeIcon: Icon(Icons.library_books),
            label: 'Library',
          ),
        ],
      ),
    );
  }
}
