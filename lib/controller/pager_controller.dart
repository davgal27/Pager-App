// AUTHOR: ALL THE TEAM

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

  /// Returns the file object for the user's library JSON.
  Future<File> _getUserLibraryFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$_userLibraryFileName');
  }

  /// Loads all book data from the bundled assets JSON.
  Future<List<Book>> _loadBooksFromAssets() async {
    final jsonStr = await rootBundle.loadString(_assetLibraryPath);
    final List<dynamic> data = jsonDecode(jsonStr);
    return data.map((e) => Book.fromJson(e as Map<String, dynamic>)).toList();
  }
  /// Loads all books, either from cached memory, user file, or assets.
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

  /// Saves the full book list to the user's library file and updates cache.
  Future<void> _saveAllBooks(List<Book> books) async {
    _booksCache = books;
    final file = await _getUserLibraryFile();
    final list = books.map((b) => b.toJson()).toList();
    await file.writeAsString(jsonEncode(list));
  }

  /// Returns the full list of books available in the shop, marking which are already in the user's library.
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
 
  /// Returns all books currently in the user's library.
  Future<List<Book>> getLibraryBooks() async {
    final books = await _loadAllBooks();
    final library = books.where((b) => _libraryBookIds.contains(b.id)).toList();
    library.sort(
      (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
    );
    return library;
  }

  /// Adds a book to the user's library, initializing its reading progress if new.
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
      // New book in library starts in "To Read" with zero progress.
      target.section = Status.toread;
      target.pageProgress = 0;
    }

    book.inLibrary = target.inLibrary;
    book.section = target.section;
    book.pageProgress = target.pageProgress;
    book.completedReadings = target.completedReadings;
    book.rating = target.rating;
    book.ratingHistory = List<int>.from(target.ratingHistory);
    book.ratingHistoryDates = List<String>.from(target.ratingHistoryDates);

    final now = DateTime.now();
    target.lastProgressUpdated = now;
    book.lastProgressUpdated = now;

    await _saveAllBooks(books);
    libraryUpdateNotifier.value++;
    return true;
  }

  /// Removes a book from the user's library, resetting progress and section.
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
    book.completedReadings = target.completedReadings;
    book.rating = target.rating;
    book.ratingHistory = List<int>.from(target.ratingHistory);
    book.ratingHistoryDates = List<String>.from(target.ratingHistoryDates);


    await _saveAllBooks(books);
    libraryUpdateNotifier.value++;
    return true;
  }

  /// Returns a list of books currently being read.
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

  /// Filters library books by search query and/or active filter criteria.
  List<Book> filterLibraryBooks({
    String searchQuery = '',
    BookFilter? activeFilter,
  }) {
    var books = _booksCache?.where((b) => _libraryBookIds.contains(b.id)).toList() ?? [];

    if (activeFilter != null) {
      final f = activeFilter;

      // Text search
      if (f.query.isNotEmpty) {
        books = books.where((b) =>
          b.title.toLowerCase().contains(f.query.toLowerCase()) ||
          b.author.toLowerCase().contains(f.query.toLowerCase())
        ).toList();
      }

      if (f.minPages != null) books = books.where((b) => b.pages >= f.minPages!).toList();
      if (f.maxPages != null) books = books.where((b) => b.pages <= f.maxPages!).toList();
      if (f.genre != null && f.genre!.trim().isNotEmpty) books = books.where((b) => b.genre.toLowerCase() == f.genre!.toLowerCase()).toList();
      if (f.status != null) books = books.where((b) => b.section == f.status).toList();
      if (f.minRating != null) books = books.where((b) => b.rating >= f.minRating!).toList();
    } else if (searchQuery.trim().isNotEmpty) {
      books = books.where((b) =>
          b.title.toLowerCase().contains(searchQuery.toLowerCase()) ||
          b.author.toLowerCase().contains(searchQuery.toLowerCase())
      ).toList();
    }

    return books;
  }

  /// Returns a summary of the user's library and last reading book, including stats like total books, pages read, and average rating.
  Future<HomeSummary> getHomeSummary() async {
    final books = await _loadAllBooks();
    final libraryBooks =
        books.where((b) => _libraryBookIds.contains(b.id)).toList();
    final reading =
        libraryBooks.where((b) => b.section == Status.reading).toList();
    final finished =
        libraryBooks.where((b) => b.section == Status.finished).toList();

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

    // Total pages read across the whole library.
    // We count:
    //  - [completedReadings] * [pages] for fully finished rereads,
    //  - plus the current in-progress pages for books in [Status.reading].
    final totalPagesRead = libraryBooks.fold<int>(0, (sum, b) {
      final pages = b.pages;

      final completedPages = b.completedReadings * pages;
      final currentProgress =
          b.section == Status.reading ? b.pageProgress.clamp(0, pages) : 0;

      return sum + completedPages + currentProgress;
    });

    // Average rating is computed only from books that currently have a rating > 0.
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

  /// Updates a book's reading progress and section based on a new page number.
  Future<bool> setBookProgress(Book book, int newPage) async {
    final books = await _loadAllBooks();
    final index = books.indexWhere((b) => b.id == book.id);
    if (index == -1) return false;

    final target = books[index];
    final previousSection = target.section;

    // Clamp the new page within a valid range.
    final clamped = newPage.clamp(1, target.pages);
    target.pageProgress = clamped;
    book.pageProgress = clamped;

    if (clamped >= target.pages) {
      // User reached (or passed) the last page: mark as finished.
      target.pageProgress = target.pages;
      target.section = Status.finished;

      // Count a new completed reading only when transitioning
      // from a non-finished state into finished.
      if (previousSection != Status.finished) {
        target.completedReadings = target.completedReadings + 1;
      }

      // ✅ ΝΕΟ: πότε ολοκληρώθηκε αυτό το reading
      final now = DateTime.now();
      target.lastProgressUpdated = now;
      book.lastProgressUpdated = now;
    } else if (target.section == Status.toread && clamped > 0) {
      // First time advancing progress from 0: move into Reading.
      target.section = Status.reading;
    }

    if (target.section == Status.reading) {
      _lastReadingBookId = target.id;
    }

    book.section = target.section;
    book.completedReadings = target.completedReadings;

    await _saveAllBooks(books);
    return true;

  }

  /// Updates the rating of a book; toggles off if the same rating is selected.
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

  /// Changes the section (To Read, Reading, Finished) of a book and updates progress.
  Future<bool> changeSection(Book book, Status newStatus) async {
    final books = await _loadAllBooks();
    final index = books.indexWhere((b) => b.id == book.id);
    if (index == -1) return false;

    final target = books[index];
    final previousSection = target.section;

    target.section = newStatus;

    if (newStatus == Status.toread) {
      // Move back to "To Read": reset progress.
      target.pageProgress = 0;
    } else if (newStatus == Status.finished) {
      // Force progress to the last page.
      target.pageProgress = target.pages;

      // If we have just transitioned into Finished, count a completion.
      if (previousSection != Status.finished) {
        target.completedReadings = target.completedReadings + 1;
      }

      // ✅ ΝΕΟ: completion date και όταν αλλάζουμε με το χέρι σε Finished
      final now = DateTime.now();
      target.lastProgressUpdated = now;
      book.lastProgressUpdated = now;
    } else if (newStatus == Status.reading) {
      // Ensure we start from a valid page when moving into Reading.
      if (target.pageProgress <= 0 || target.pageProgress >= target.pages) {
        target.pageProgress = 1;
      }
      _lastReadingBookId = target.id;
    }

    final now = DateTime.now();
    target.lastProgressUpdated = now;
    book.lastProgressUpdated = now;

    book.section = target.section;
    book.pageProgress = target.pageProgress;
    book.completedReadings = target.completedReadings;

    await _saveAllBooks(books);
    return true;
  }

 /// Starts a new reading of a finished book, preserving previous rating in history.
   Future<bool> startReread(Book book) async {
    final books = await _loadAllBooks();
    final index = books.indexWhere((b) => b.id == book.id);
    if (index == -1) return false;

    final target = books[index];

    // If there is a current rating, append it to the history
    // before starting a fresh reading. We also store a timestamp
    // so we can later show when this reading was completed.
    final nowIso = (target.lastProgressUpdated ?? DateTime.now())
        .toIso8601String();

    target.ratingHistory = List<int>.from(target.ratingHistory)
      ..add(target.rating);
    target.ratingHistoryDates =
        List<String>.from(target.ratingHistoryDates)..add(nowIso);

    // Start a new reading from the beginning.
    target.section = Status.reading;
    target.pageProgress = target.pages > 0 ? 1 : 0;
    target.rating = 0;
    _lastReadingBookId = target.id;

    // Reflect the changes back to the UI instance.
    book.section = target.section;
    book.pageProgress = target.pageProgress;
    book.rating = target.rating;
    book.ratingHistory = List<int>.from(target.ratingHistory);
    book.ratingHistoryDates =
        List<String>.from(target.ratingHistoryDates);
    book.completedReadings = target.completedReadings;

    await _saveAllBooks(books);
    return true;
  }
  /// Saves the current state of a book to the library file.
  Future<bool> saveBook(Book book) async {
    final books = await _loadAllBooks();
    final index = books.indexWhere((b) => b.id == book.id);
    if (index == -1) return false;

    books[index] = book;
    await _saveAllBooks(books);
    return true;
  }

    // Βάλε το μέσα στην κλάση PagerController
  String? buildSectionChangeMessage(Book book, Status previous, Status current) {
    // To read -> Reading
    if (previous == Status.toread && current == Status.reading) {
      return '"${book.title}" moved to Reading shelf.';
    }

    // Reading -> Finished
    if (previous == Status.reading && current == Status.finished) {
      return '"${book.title}" moved to Finished shelf.';
    }

    if (previous == Status.finished && current == Status.reading) {
      return '"${book.title}" moved to Reading shelf.';
    }

    // Finished -> To read
    if (previous == Status.finished && current == Status.toread) {
      return '"${book.title}" moved to To read shelf.';
    }

    // Άλλες αλλαγές δεν μας ενδιαφέρουν προς το παρόν
    return null;
  }

  /// Filters a given list of books for shop display based on query and/or filter.
  List<Book> filterShopBooks({
    required List<Book> books,
    String? query,
    BookFilter? filter,
  }) {
    var result = books;

    if (query != null && query.trim().isNotEmpty) {
      final q = query.toLowerCase();
      result = result.where((b) =>
        b.title.toLowerCase().contains(q) ||
        b.author.toLowerCase().contains(q) ||
        b.genre.toLowerCase().contains(q)
      ).toList();
    }

    if (filter != null) {
      if (filter.query.isNotEmpty) {
        final q = filter.query.toLowerCase();
        result = result.where((b) =>
          b.title.toLowerCase().contains(q) ||
          b.author.toLowerCase().contains(q) ||
          b.genre.toLowerCase().contains(q)
        ).toList();
      }
      if (filter.minPages != null) {
        result = result.where((b) => b.pages >= filter.minPages!).toList();
      }
      if (filter.maxPages != null) {
        result = result.where((b) => b.pages <= filter.maxPages!).toList();
      }
      if (filter.genre != null && filter.genre!.trim().isNotEmpty) {
        result = result.where((b) =>
          b.genre.toLowerCase() == filter.genre!.toLowerCase()
        ).toList();
      }
      if (filter.minRating != null) {
        result = result.where((b) => b.rating >= filter.minRating!).toList();
      }
      if (filter.inLibrary != null) {
        result = result.where((b) => b.inLibrary == filter.inLibrary).toList();
      }
    }

    return result;
  }


}
