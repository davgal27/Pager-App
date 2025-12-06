// AUTHOR: ALL THE TEAM

// lib/model/book.dart
//
// Core data models used in the Pager app.

/// Represents which list / shelf the book belongs to.
enum Status { toread, reading, finished }

/// One note created by the user for a book.
///
/// Notes are attached to a [Book] and persisted in the user JSON file.
class BookNote {
  final int page;
  final String text;
  final DateTime createdAt;

  BookNote({required this.page, required this.text, required this.createdAt});

  factory BookNote.fromJson(Map<String, dynamic> json) {
    return BookNote(
      page: json['page'] as int,
      text: json['text'] as String,
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'page': page,
      'text': text,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}

/// Core book model used across the app.
class Book {
  int id;
  String title;
  String author;
  String publisher;
  String datePublished;
  String genre;
  int pages;

  /// Current page the user is at for this book.
  int pageProgress;

  /// Rating from 1–5 for the *current* completed reading.
  /// 0 means "not rated yet".
  int rating;

  /// Ratings of previous completed readings.
 
  List<int> ratingHistory;

   /// The i-th date corresponds to the i-th rating in [ratingHistory].
  /// Stored as strings to keep JSON encoding simple.
  List<String> ratingHistoryDates;

  /// How many times this book has been fully completed (finished).
  ///
  /// This is used to calculate overall "pages read" statistics
  /// on the Home screen. Each completed reading contributes
  /// [pages] to the total.
  int completedReadings;

  /// Short description shown on detail screens.
  String description;

  /// Whether the book is currently in the user's library.
  bool inLibrary;

  /// Which section (ToRead / Reading / Finished) this book is in.
  Status section;

  /// Asset path for the book cover image.
  String coverAsset;

  /// Notes written by the user while reading this book.
  List<BookNote> notes;

  /// When the reading progress of this book was last updated.
  /// Used by the Home screen to show "last book you read".
  DateTime? lastProgressUpdated;

  Book({
    required this.id,
    required this.title,
    required this.author,
    required this.publisher,
    required this.datePublished,
    required this.genre,
    required this.pages,
    this.pageProgress = 0,
    this.rating = 0,
    List<int>? ratingHistory,
    List<String>? ratingHistoryDates,  
    this.completedReadings = 0,
    this.description = "",
    this.inLibrary = true,
    this.section = Status.toread,
    this.coverAsset = '',
    List<BookNote>? notes,
    this.lastProgressUpdated,
  })  : ratingHistory = ratingHistory ?? <int>[],
        ratingHistoryDates = ratingHistoryDates ?? <String>[],
        notes = notes ?? <BookNote>[];

  /// Build a Book from a JSON map (as loaded from user_library.json).
  factory Book.fromJson(Map<String, dynamic> json) {
    final notesJson = json['notes'] as List<dynamic>?;
    final ratingHistoryJson = json['ratingHistory'] as List<dynamic>?;
    final ratingHistoryDatesJson =
        json['ratingHistoryDates'] as List<dynamic>?;

    final pages = json['pages'] as int? ?? 0;
    final pageProgress = (json['pageProgress'] ?? 0) as int;

    // Determine the section (for compatibility with older JSON).
    final sectionIndex = json['section'] as int? ?? Status.toread.index;
    final section = Status.values[sectionIndex];

    // Derive completedReadings if it does not exist yet in the JSON.
    int completedReadings;
    if (json.containsKey('completedReadings')) {
      completedReadings = json['completedReadings'] as int? ?? 0;
    } else {
      // For older data:
      // - If the book is already finished, or
      // - progress has reached the last page,
      // we assume it has been completed once.
      if (section == Status.finished || (pages > 0 && pageProgress >= pages)) {
        completedReadings = 1;
      } else {
        completedReadings = 0;
      }
    }

    return Book(
      id: json['id'] as int,
      title: json['title'] as String,
      author: json['author'] as String,
      publisher: json['publisher'] as String,
      datePublished: json['datePublished'] as String,
      genre: json['genre'] as String,
      pages: pages,
      pageProgress: pageProgress,
      rating: (json['rating'] ?? 0) as int,
      ratingHistory: ratingHistoryJson != null
          ? ratingHistoryJson.whereType<int>().toList()
          : <int>[],
      ratingHistoryDates: ratingHistoryDatesJson != null
          ? ratingHistoryDatesJson.whereType<String>().toList()
          : <String>[],
      completedReadings: completedReadings,
      description: json['description'] as String? ?? "",
      inLibrary: (json['inLibrary'] ?? true) as bool,
      section: section,
      coverAsset: json['coverAsset'] as String? ?? '',
      notes: notesJson != null
          ? notesJson
              .whereType<Map<String, dynamic>>()
              .map(BookNote.fromJson)
              .toList()
          : <BookNote>[],
      lastProgressUpdated: json['lastProgressUpdated'] != null
          ? DateTime.tryParse(json['lastProgressUpdated'] as String)
          : null,
    );
  }

  /// Convert a Book back to JSON (for saving).
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'author': author,
      'publisher': publisher,
      'datePublished': datePublished,
      'genre': genre,
      'pages': pages,
      'pageProgress': pageProgress,
      'rating': rating,
      'ratingHistory': ratingHistory,
      'ratingHistoryDates': ratingHistoryDates,
      'completedReadings': completedReadings,
      'description': description,
      'inLibrary': inLibrary,
      'section': section.index,
      'coverAsset': coverAsset,
      'notes': notes.map((n) => n.toJson()).toList(),
      'lastProgressUpdated': lastProgressUpdated?.toIso8601String(),
    };
  }
}
