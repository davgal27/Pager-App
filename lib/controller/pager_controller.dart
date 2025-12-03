import '../model/book.dart';
import '../model/books_repository.dart';

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

class PagerController {
  PagerController._();

  static final PagerController instance = PagerController._();

  List<Book>? _booksCache;
  int? _lastReadingBookId;

  Future<List<Book>> _loadAllBooks() async {
    if (_booksCache != null) return _booksCache!;
    final books = await BooksRepository.loadLibrary();
    _booksCache = books;
    return books;
  }

  Future<void> _saveAllBooks(List<Book> books) async {
    _booksCache = books;
    await BooksRepository.saveLibrary(books);
  }

  Future<List<Book>> getLibraryBooks() async {
    final books = await _loadAllBooks();
    
    final visible = books.where((b) => b.inLibrary).toList();
    visible.sort(
      (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
    );
    return visible;
  }

   Future<List<Book>> getShopBooks() async {
    final books = await _loadAllBooks();
    final shop = books.where((b) => !b.inLibrary).toList();

    shop.sort(
      (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
    );
    return shop;
  }

  Future<List<Book>> getReadingBooks() async {
    final books = await _loadAllBooks();
    final reading = books
        .where((b) => b.inLibrary && b.section == Status.reading)
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
    final libraryBooks = books.where((b) => b.inLibrary).toList();
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

  Future<bool> addBookToLibrary(Book book) async {
    final books = await _loadAllBooks();
    final index = books.indexWhere((b) => b.id == book.id);
    if (index == -1) return false;

    final target = books[index];

    // Ο χρήστης "αγοράζει" το βιβλίο -> μπαίνει στη βιβλιοθήκη του
    target.inLibrary = true;

    // ΝΕΟ βιβλίο: το βάζουμε αυτόματα στη λίστα "To read"
    target.section = Status.toread;
    target.pageProgress = 0;

    // ενημερώνουμε και το Book που κρατάει η UI
    book.inLibrary = target.inLibrary;
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
