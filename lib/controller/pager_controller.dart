import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';

import '../model/book.dart';

class LibraryStats {
  final int totalBooks;
  final int readingCount;
  final int finishedCount;
  final int totalPagesRead;
  final double averageRating;

  LibraryStats({
    required this.totalBooks,
    required this.readingCount,
    required this.finishedCount,
    required this.totalPagesRead,
    required this.averageRating,
  });
}

class HomeSummary {
  final Book? lastReadingBook;
  final LibraryStats stats;

  HomeSummary({required this.lastReadingBook, required this.stats});
}

class BookFilter {
  final String id;
  final String name;
  final String query;
  final int? minPages;
  final int? maxPages;
  final String? genre;
  final Status? status;
  final int? minRating;
  final bool? inLibrary;

  BookFilter({
    required this.id,
    required this.name,
    this.query = '',
    this.minPages,
    this.maxPages,
    this.genre,
    this.status,
    this.minRating,
    this.inLibrary,
  });
}

class PagerController {
  PagerController._privateConstructor();
  static final PagerController instance = PagerController._privateConstructor();

  final ValueNotifier<int> libraryUpdateNotifier = ValueNotifier<int>(0);
  final ValueNotifier<List<BookFilter>> savedFiltersNotifier =
      ValueNotifier<List<BookFilter>>([]);

  List<BookFilter> get savedFilters => savedFiltersNotifier.value;
  set savedFilters(List<BookFilter> filters) =>
      savedFiltersNotifier.value = filters;

  BookFilter? activeFilter;

  List<Book>? _booksCache;
  int? _lastReadingBookId;
  final Set<int> _libraryBookIds = {};

  static const String _assetLibraryPath = 'data/books.json';
  static const String _userLibraryFileName = 'user_library.json';

  Future<File> _getUserLibraryFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$_userLibraryFileName');
  }

  Future<List<Book>> _loadBooksFromAssets() async {
    final jsonStr = await rootBundle.loadString(_assetLibraryPath);
    final List<dynamic> data = jsonDecode(jsonStr);
    return data.map((e) => Book.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<Book>> _loadAllBooks() async {
    if (_booksCache != null) return _booksCache!;

    final file = await _getUserLibraryFile();
    List<Book> books;

    if (await file.exists()) {
      try {
        final content = await file.readAsString();
        if (content.trim().isNotEmpty) {
          final List<dynamic> jsonList = jsonDecode(content);
          books = jsonList
              .map((e) => Book.fromJson(e as Map<String, dynamic>))
              .toList();
        } else {
          books = await _loadBooksFromAssets();
        }
      } catch (_) {
        books = await _loadBooksFromAssets();
      }
    } else {
      books = await _loadBooksFromAssets();
    }

    _libraryBookIds.clear();
    for (final b in books) {
      if (b.inLibrary) _libraryBookIds.add(b.id);
    }

    _booksCache = books;
    return books;
  }

  Future<void> _saveAllBooks(List<Book> books) async {
    _booksCache = books;
    final file = await _getUserLibraryFile();
    final list = books.map((b) => b.toJson()).toList();
    await file.writeAsString(jsonEncode(list));
  }

  Future<List<Book>> getShopBooks() async {
    final books = await _loadAllBooks();

    for (final book in books) {
      book.inLibrary = _libraryBookIds.contains(book.id);
    }

    books.sort(
      (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
    );
    return books;
  }

  Future<List<Book>> getLibraryBooks() async {
    final books = await _loadAllBooks();
    final library = books.where((b) => _libraryBookIds.contains(b.id)).toList();
    library.sort(
      (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
    );
    return library;
  }

  Future<bool> addBookToLibrary(Book book) async {
    final books = await _loadAllBooks();
    final index = books.indexWhere((b) => b.id == book.id);
    Book target;

    if (index == -1) {
      books.add(book);
      target = book;
    } else {
      target = books[index];
    }

    final alreadyInLibrary = _libraryBookIds.contains(target.id);

    _libraryBookIds.add(target.id);
    target.inLibrary = true;

    if (!alreadyInLibrary) {
      target.section = Status.toread;
      target.pageProgress = 0;
    }

    book.inLibrary = target.inLibrary;
    book.section = target.section;
    book.pageProgress = target.pageProgress;

    await _saveAllBooks(books);
    libraryUpdateNotifier.value++;
    return true;
  }

  Future<bool> removeBookFromLibrary(Book book) async {
    final books = await _loadAllBooks();
    final index = books.indexWhere((b) => b.id == book.id);
    if (index == -1) return false;

    final target = books[index];

    _libraryBookIds.remove(target.id);
    target.inLibrary = false;
    target.section = Status.toread;
    target.pageProgress = 0;

    book.inLibrary = target.inLibrary;
    book.section = target.section;
    book.pageProgress = target.pageProgress;

    await _saveAllBooks(books);
    libraryUpdateNotifier.value++;
    return true;
  }

  Future<List<Book>> getReadingBooks() async {
    final books = await _loadAllBooks();
    final reading = books
        .where(
          (b) => _libraryBookIds.contains(b.id) && b.section == Status.reading,
        )
        .toList();

    reading.sort((a, b) {
      if (_lastReadingBookId != null) {
        if (a.id == _lastReadingBookId && b.id != _lastReadingBookId) {
          return -1;
        }
        if (b.id == _lastReadingBookId && a.id != _lastReadingBookId) {
          return 1;
        }
      }
      return a.title.toLowerCase().compareTo(b.title.toLowerCase());
    });

    return reading;
  }

  Future<HomeSummary> getHomeSummary() async {
    final books = await _loadAllBooks();
    final libraryBooks = books
        .where((b) => _libraryBookIds.contains(b.id))
        .toList();
    final reading = libraryBooks
        .where((b) => b.section == Status.reading)
        .toList();
    final finished = libraryBooks
        .where((b) => b.section == Status.finished)
        .toList();

    Book? last;
    if (_lastReadingBookId != null) {
      try {
        last = reading.firstWhere((b) => b.id == _lastReadingBookId);
      } catch (_) {}
    }
    if (last == null && reading.isNotEmpty) {
      reading.sort(
        (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
      );
      last = reading.first;
    }

    final totalBooks = libraryBooks.length;
    final readingCount = reading.length;
    final finishedCount = finished.length;

    final totalPagesRead = libraryBooks.fold<int>(0, (sum, b) {
      final maxPages = b.pages;
      final progress = b.pageProgress.clamp(0, maxPages);
      return sum + progress;
    });

    final rated = libraryBooks.where((b) => b.rating > 0).toList();
    double averageRating = 0;
    if (rated.isNotEmpty) {
      final totalRating = rated.fold<int>(0, (sum, b) => sum + b.rating);
      averageRating = totalRating / rated.length;
    }

    final stats = LibraryStats(
      totalBooks: totalBooks,
      readingCount: readingCount,
      finishedCount: finishedCount,
      totalPagesRead: totalPagesRead,
      averageRating: averageRating,
    );

    return HomeSummary(lastReadingBook: last, stats: stats);
  }

  Future<bool> setBookProgress(Book book, int newPage) async {
    final books = await _loadAllBooks();
    final index = books.indexWhere((b) => b.id == book.id);
    if (index == -1) return false;

    final target = books[index];
    final clamped = newPage.clamp(1, target.pages);
    target.pageProgress = clamped;
    book.pageProgress = clamped;

    if (clamped >= target.pages) {
      target.pageProgress = target.pages;
      target.section = Status.finished;
    } else if (target.section == Status.toread && clamped > 0) {
      target.section = Status.reading;
    }

    if (target.section == Status.reading) {
      _lastReadingBookId = target.id;
    }

    book.section = target.section;

    await _saveAllBooks(books);
    return true;
  }

  Future<bool> updateRating(Book book, int starIndex) async {
    if (starIndex < 1 || starIndex > 5) return false;

    final books = await _loadAllBooks();
    final index = books.indexWhere((b) => b.id == book.id);
    if (index == -1) return false;

    final target = books[index];
    final newRating = target.rating == starIndex ? 0 : starIndex;

    target.rating = newRating;
    book.rating = newRating;

    await _saveAllBooks(books);
    return true;
  }

  Future<bool> changeSection(Book book, Status newStatus) async {
    final books = await _loadAllBooks();
    final index = books.indexWhere((b) => b.id == book.id);
    if (index == -1) return false;

    final target = books[index];

    target.section = newStatus;

    if (newStatus == Status.toread) {
      target.pageProgress = 0;
    } else if (newStatus == Status.finished) {
      target.pageProgress = target.pages;
    } else if (newStatus == Status.reading) {
      if (target.pageProgress <= 0 || target.pageProgress >= target.pages) {
        target.pageProgress = 1;
      }
      _lastReadingBookId = target.id;
    }

    book.section = target.section;
    book.pageProgress = target.pageProgress;

    await _saveAllBooks(books);
    return true;
  }

  Future<bool> saveBook(Book book) async {
    final books = await _loadAllBooks();
    final index = books.indexWhere((b) => b.id == book.id);
    if (index == -1) return false;

    books[index] = book;
    await _saveAllBooks(books);
    return true;
  }
}
