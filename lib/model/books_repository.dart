import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';

import 'book.dart';

enum FilterBy { title, author, genre }

class BooksRepository {
  static const String _assetLibraryPath = 'data/books.json';
  static const String _userLibraryFileName = 'user_library.json';

  static Future<File> _getUserLibraryFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$_userLibraryFileName');
  }

  static Future<bool> _userLibraryExists() async {
    final file = await _getUserLibraryFile();
    return file.exists();
  }

  static Future<List<Book>> loadLibrary() async {
    final exists = await _userLibraryExists();

    if (!exists) {
      final seedContent = await rootBundle.loadString(_assetLibraryPath);
      final jsonList = jsonDecode(seedContent) as List<dynamic>;
      final books = jsonList
          .whereType<Map<String, dynamic>>()
          .map((e) => Book.fromJson(e))
          .toList();
      await saveLibrary(books);
      return books;
    }

    final file = await _getUserLibraryFile();
    if (!await file.exists()) {
      final seedContent = await rootBundle.loadString(_assetLibraryPath);
      final jsonList = jsonDecode(seedContent) as List<dynamic>;
      final books = jsonList
          .whereType<Map<String, dynamic>>()
          .map((e) => Book.fromJson(e))
          .toList();
      await saveLibrary(books);
      return books;
    }

    final content = await file.readAsString();
    if (content.trim().isEmpty) {
      return <Book>[];
    }

    final jsonList = jsonDecode(content) as List<dynamic>;
    return jsonList
        .whereType<Map<String, dynamic>>()
        .map((e) => Book.fromJson(e))
        .toList();
  }

  static Future<void> saveLibrary(List<Book> books) async {
    final file = await _getUserLibraryFile();
    final jsonList = books.map((b) => b.toJson()).toList();
    final pretty = const JsonEncoder.withIndent('  ').convert(jsonList);
    await file.writeAsString(pretty);
  }

  static Book? _findBookInList(int id, List<Book> books) {
    try {
      return books.firstWhere((b) => b.id == id);
    } catch (_) {
      return null;
    }
  }

  static Future<bool> saveBook(Book updated) async {
    final books = await loadLibrary();
    final index = books.indexWhere((b) => b.id == updated.id);
    if (index == -1) return false;
    books[index] = updated;
    await saveLibrary(books);
    return true;
  }

  static Future<bool> addBook(Book b, Status section) async {
    final books = await loadLibrary();

    for (final book in books) {
      if (book.id == b.id) {
        if (!book.inLibrary) {
          book.inLibrary = true;
          book.section = section;
          await saveLibrary(books);
          return true;
        }
        return false;
      }
    }
    return false;
  }

  static Future<bool> removeBook(int id) async {
    final books = await loadLibrary();
    final book = _findBookInList(id, books);
    if (book == null || !book.inLibrary) return false;

    book.inLibrary = false;
    await saveLibrary(books);
    return true;
  }

  static Future<bool> changeSection(int id, Status newSection) async {
    final books = await loadLibrary();
    final book = _findBookInList(id, books);
    if (book == null) return false;

    book.section = newSection;

    switch (newSection) {

      case Status.toread:
        // list "To read" 
        book.pageProgress = 0;
        book.lastProgressUpdated = null;
        break;

      case Status.reading:
        if (book.pages <= 0) {
          book.pageProgress = 0;
        } else {
          if (book.pageProgress <= 0 || book.pageProgress >= book.pages) {
            book.pageProgress = 1;
          }
        }
        break;

      case Status.finished:
        book.pageProgress = book.pages;
        break;
    }

    await saveLibrary(books);
    return true;
  }

  static Future<bool> updateProgress(int id, int page) async {
    final books = await loadLibrary();
    final book = _findBookInList(id, books);
    if (book == null) return false;

    final clamped = page.clamp(0, book.pages).toInt();

    if (clamped <= 0) {
      book.pageProgress = 0;
      book.section = Status.toread;
      book.lastProgressUpdated = null;
    } else if (clamped >= book.pages && book.pages > 0) {
      book.pageProgress = book.pages;
      book.section = Status.finished;
      book.lastProgressUpdated = DateTime.now();
    } else {
      book.pageProgress = clamped;
      book.section = Status.reading;
      book.lastProgressUpdated = DateTime.now();
    }

    await saveLibrary(books);
    return true;
  }

  static Future<bool> updateRating(int id, int rating) async {
    final books = await loadLibrary();
    final book = _findBookInList(id, books);
    if (book == null) return false;

    final clamped = rating.clamp(0, 5);
    book.rating = clamped.toInt();

    await saveLibrary(books);
    return true;
  }

  static Future<List<Book>> getBooks([Status? section]) async {
    var books = await loadLibrary();
    books = books.where((b) => b.inLibrary).toList();

    if (section != null) {
      books = books.where((b) => b.section == section).toList();
    }
    return books;
  }

  static Future<List<Book>> getBooksFiltered({
    Status? section,
    FilterBy? filterBy,
    String? filterValue,
  }) async {
    var books = await getBooks(section);

    if (filterBy != null && filterValue != null && filterValue.isNotEmpty) {
      final lowerValue = filterValue.toLowerCase();
      books = books.where((b) {
        switch (filterBy) {
          case FilterBy.title:
            return b.title.toLowerCase().contains(lowerValue);
          case FilterBy.author:
            return b.author.toLowerCase().contains(lowerValue);
          case FilterBy.genre:
            return b.genre.toLowerCase().contains(lowerValue);
        }
      }).toList();
    }

    return books;
  }

  static Future<List<Book>> searchBooks(String term, [Status? section]) async {
    var books = await getBooks(section);
    final lowerTerm = term.toLowerCase();

    return books.where((b) {
      return b.title.toLowerCase().contains(lowerTerm) ||
          b.author.toLowerCase().contains(lowerTerm) ||
          b.genre.toLowerCase().contains(lowerTerm);
    }).toList();
  }
}
