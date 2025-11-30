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

  /// Rating from 1–5 (0 = not rated yet).
  int rating;

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
    this.description = "",
    this.inLibrary = true,
    this.section = Status.toread,
    this.coverAsset = '',
    List<BookNote>? notes,
    this.lastProgressUpdated,
  }) : notes = notes ?? <BookNote>[];

  /// Build a Book from a JSON map (as loaded from user_library.json).
  factory Book.fromJson(Map<String, dynamic> json) {
    final notesJson = json['notes'] as List<dynamic>?;

    return Book(
      id: json['id'] as int,
      title: json['title'] as String,
      author: json['author'] as String,
      publisher: json['publisher'] as String,
      datePublished: json['datePublished'] as String,
      genre: json['genre'] as String,
      pages: json['pages'] as int,
      pageProgress: (json['pageProgress'] ?? 0) as int,
      rating: (json['rating'] ?? 0) as int,
      description: json['description'] as String? ?? "",
      inLibrary: (json['inLibrary'] ?? true) as bool,
      section: json.containsKey('section')
          ? Status.values[json['section'] as int]
          : Status.toread,
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
      'description': description,
      'inLibrary': inLibrary,
      'section': section.index,
      'coverAsset': coverAsset,
      'notes': notes.map((n) => n.toJson()).toList(),
      'lastProgressUpdated': lastProgressUpdated?.toIso8601String(),
    };
  }
}
