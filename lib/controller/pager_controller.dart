import '../model/book.dart';
import '../model/books_repository.dart';
import 'package:flutter/material.dart';


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
  final String? genre;     // genre filter
  final Status? status;    // reading/toread/finished
  final int? minRating;    // minimum rating filter
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
  PagerController._();
  PagerController._privateConstructor();
  static final PagerController instance = PagerController._privateConstructor();
  final ValueNotifier<int> libraryUpdateNotifier = ValueNotifier(0);
  // Use ValueNotifier for dynamic updates
  final ValueNotifier<List<BookFilter>> savedFiltersNotifier = ValueNotifier([]);
  List<BookFilter> get savedFilters => savedFiltersNotifier.value;
  set savedFilters(List<BookFilter> filters) => savedFiltersNotifier.value = filters;

  BookFilter? activeFilter;

  List<Book>? _booksCache;
  int? _lastReadingBookId;

  // -----------------------------
  // New: Track library ownership separately
  final Set<int> _libraryBookIds = {};

  // -----------------------------
  // Load / Save
  Future<List<Book>> _loadAllBooks() async {
    if (_booksCache != null) return _booksCache!;
    final books = await BooksRepository.loadLibrary();

    // Initialize library set based on books.json inLibrary flags
    _libraryBookIds.clear();
    for (var book in books) {
      if (book.inLibrary) _libraryBookIds.add(book.id);
    }

    _booksCache = books;
    return _booksCache!;
  }

  Future<void> _saveAllBooks(List<Book> books) async {
    _booksCache = books;
    await BooksRepository.saveLibrary(books);
  }

  // -----------------------------
  // Shop / Library functions
  Future<List<Book>> getShopBooks() async {
    final books = await _loadAllBooks();

    // mark which books are already in library
    for (var book in books) {
      book.inLibrary = _libraryBookIds.contains(book.id);
    }

    books.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
    return books;
  }


  Future<List<Book>> getLibraryBooks() async {
    final books = await _loadAllBooks();
    final library = books.where((b) => _libraryBookIds.contains(b.id)).toList();
    library.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
    return library;
  }


  Future<bool> addBookToLibrary(Book book) async {
    final alreadyInLibrary = _libraryBookIds.contains(book.id);

    _libraryBookIds.add(book.id);
    book.inLibrary = true;

    if (!alreadyInLibrary) {
      book.section = Status.toread;
      book.pageProgress = 0;
    }

    await _saveAllBooks(_booksCache!);

    libraryUpdateNotifier.value++;  // notify listeners
    return true;
  }

  Future<bool> removeBookFromLibrary(Book book) async {
    final books = await _loadAllBooks();
    final index = books.indexWhere((b) => b.id == book.id);
    if (index == -1) return false;

    _libraryBookIds.remove(book.id);
    final target = books[index];
    target.inLibrary = false;
    target.section = Status.toread;
    target.pageProgress = 0;

    book.inLibrary = false;
    book.section = Status.toread;
    book.pageProgress = 0;

    await _saveAllBooks(books);

    libraryUpdateNotifier.value++;  // notify listeners
    return true;
  }






  Future<List<Book>> getReadingBooks() async {
    final books = await _loadAllBooks();
    final reading = books
        .where((b) => _libraryBookIds.contains(b.id) && b.section == Status.reading)
        .toList();

    reading.sort((a, b) {
      if (_lastReadingBookId != null) {
        if (a.id == _lastReadingBookId && b.id != _lastReadingBookId) return -1;
        if (b.id == _lastReadingBookId && a.id != _lastReadingBookId) return 1;
      }
      return a.title.toLowerCase().compareTo(b.title.toLowerCase());
    });

    return reading;
  }

  Future<HomeSummary> getHomeSummary() async {
    final books = await _loadAllBooks();
    final libraryBooks = books.where((b) => _libraryBookIds.contains(b.id)).toList();
    final reading = libraryBooks.where((b) => b.section == Status.reading).toList();
    final finished = libraryBooks.where((b) => b.section == Status.finished).toList();

    Book? last;
    if (_lastReadingBookId != null) {
      try {
        last = reading.firstWhere((b) => b.id == _lastReadingBookId);
      } catch (_) {}
    }
    if (last == null && reading.isNotEmpty) {
      reading.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
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
