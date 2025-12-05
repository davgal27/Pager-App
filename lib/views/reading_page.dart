import 'package:flutter/material.dart';

import '../controller/pager_controller.dart';
import '../model/book.dart';
import 'book_detail_page.dart';
import 'book_notes_page.dart';

/// Screen that lists all books currently in the "Reading" section.
class ReadingPage extends StatefulWidget {
  const ReadingPage({super.key});

  @override
  State<ReadingPage> createState() => _ReadingPageState();
}

class _ReadingPageState extends State<ReadingPage> {
  /// Shared controller (singleton) used to access and update book data.
  final PagerController _controller = PagerController.instance;

  /// Future used for the initial load of reading books.
  late Future<List<Book>> _loadFuture;

  /// Local cache of all books in the Reading section.
  /// Search is always applied on this list.
  List<Book> _allBooks = [];

  /// Current query string from the search field.
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    // Load all books that are currently in the Reading section.
    _loadFuture = _controller.getReadingBooks();
  }

  /// Returns the list of books filtered by [_searchQuery].
  /// If there is no query, returns a copy of the full list.
  List<Book> _filteredBooks() {
    if (_searchQuery.trim().isEmpty) {
      return List<Book>.from(_allBooks);
    }
    final q = _searchQuery.toLowerCase();
    return _allBooks.where((b) {
      return b.title.toLowerCase().contains(q) ||
          b.author.toLowerCase().contains(q);
    }).toList();
  }

  /// Handles a change of reading progress for [book].
  ///
  /// Delegates the real update to [PagerController.setBookProgress],
  /// then:
  ///  - asks the controller to build a feedback message if the section changed,
  ///  - removes the book from the list if it is no longer in "Reading".
  Future<void> _handleProgressChanged(Book book, int newPage) async {
    final previousSection = book.section;

    final ok = await _controller.setBookProgress(book, newPage);
    if (!mounted) return;

    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not update progress.')),
      );
      return;
    }

    // Ask the controller if this change of section should display a message.
    final message = _controller.buildSectionChangeMessage(
      book,
      previousSection,
      book.section,
    );

    if (message != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    }

    setState(() {
      // If the book left the Reading section, remove it from the local list
      // so that the UI stays consistent with the data model.
      if (book.section != Status.reading) {
        _allBooks.removeWhere((b) => b.id == book.id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    const background = Color(0xFFF5F0E8);
    const headerBrown = Color(0xFF6B3A19);

    return Container(
      color: headerBrown,
      child: SafeArea(
        bottom: false,
        child: Container(
          color: background,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top header bar with the screen title.
              Container(
                width: double.infinity,
                color: headerBrown,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
                child: Text(
                  'Reading',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // Search field to filter books by title or author.
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Search a book you are reading',
                    filled: true,
                    fillColor: Colors.white,
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(26),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                    });
                  },
                ),
              ),
              const SizedBox(height: 16),
              // Main content: FutureBuilder loads reading books once,
              // then we keep them in _allBooks and apply filters locally.
              Expanded(
                child: FutureBuilder<List<Book>>(
                  future: _loadFuture,
                  builder: (context, snapshot) {
                    // Initial loading state when no local data yet.
                    if (snapshot.connectionState == ConnectionState.waiting &&
                        _allBooks.isEmpty) {
                      return const Center(child: CircularProgressIndicator());
                    } else if (snapshot.hasError && _allBooks.isEmpty) {
                      // Initial load failed.
                      return Center(child: Text('Error: ${snapshot.error}'));
                    }

                    // First time we get data, populate the local cache.
                    if (snapshot.hasData && _allBooks.isEmpty) {
                      _allBooks = snapshot.data!;
                    }

                    final books = _filteredBooks();

                    // No books at all vs no books matching the current search.
                    if (books.isEmpty) {
                      if (_allBooks.isEmpty) {
                        return const Center(
                          child: Text('No books currently reading.'),
                        );
                      } else {
                        return const Center(
                          child: Text('No books match your search.'),
                        );
                      }
                    }

                    // List of reading books with cards for each one.
                    return ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      itemCount: books.length,
                      itemBuilder: (context, index) {
                        final book = books[index];

                        return ReadingBookCard(
                          book: book,
                          // When progress changes from the card, delegate to handler.
                          onProgressChanged: (newPage) =>
                              _handleProgressChanged(book, newPage),
                          // Open detailed info; when returning, remove the book
                          // if it no longer belongs to the Reading section.
                          onInfoPressed: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => BookDetailPage(book: book),
                              ),
                            );
                            if (!mounted) return;
                            setState(() {
                              if (book.section != Status.reading) {
                                _allBooks.removeWhere((b) => b.id == book.id);
                              }
                            });
                          },
                          // Open notes screen for this book.
                          onNotesPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => BookNotesPage(
                                  book: book,
                                  initialPage: book.pageProgress,
                                ),
                              ),
                            );
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Card displaying one book in the Reading list,
/// with progress controls, info access and notes shortcut.
class ReadingBookCard extends StatelessWidget {
  final Book book;
  final void Function(int newPage) onProgressChanged;
  final VoidCallback onInfoPressed;
  final VoidCallback onNotesPressed;

  const ReadingBookCard({
    super.key,
    required this.book,
    required this.onProgressChanged,
    required this.onInfoPressed,
    required this.onNotesPressed,
  });

  /// Opens a dialog to let the user enter an exact page number.
  /// This avoids having to press + / - many times.
  void _showPageEditDialog(BuildContext context) {
    final controller = TextEditingController(
      text: book.pageProgress.toString(),
    );

    showDialog<void>(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          title: const Text('Set current page'),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Page number',
              helperText: '1 – ${book.pages}',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                final raw = controller.text.trim();
                final parsed = int.tryParse(raw);

                // Basic validation: must be a number.
                if (parsed == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Page must be a number.')),
                  );
                  return;
                }

                // And must stay within book page bounds.
                if (parsed < 1 || parsed > book.pages) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Page must be between 1 and ${book.pages}.',
                      ),
                    ),
                  );
                  return;
                }

                onProgressChanged(parsed);
                Navigator.of(dialogCtx).pop();
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    const cardBrown = Color(0xFF6B3A19);
    const pillBrown = Color(0xFF8A4A22);

    /// Progress ratio used for the LinearProgressIndicator.
    final progress = book.pages > 0
        ? (book.pageProgress / book.pages).clamp(0.0, 1.0)
        : 0.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 16.0),
      decoration: BoxDecoration(
        color: cardBrown,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top row: cover, text info, info + notes buttons.
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.asset(
                    book.coverAsset,
                    width: 90,
                    height: 130,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        book.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        book.author,
                        style: TextStyle(color: Colors.white.withOpacity(0.9)),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${book.pages} pages',
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.info_outline, color: Colors.white),
                      onPressed: onInfoPressed,
                    ),
                    const SizedBox(height: 44),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(22),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        visualDensity: VisualDensity.compact,
                      ),
                      onPressed: onNotesPressed,
                      icon: const Icon(Icons.sticky_note_2_outlined, size: 18),
                      label: const Text('Notes'),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 18),
            // Middle row: - / current page / + and "Finish" button.
            Row(
              children: [
                Row(
                  children: [
                    IconButton(
                      onPressed: () => onProgressChanged(book.pageProgress - 1),
                      icon: const Icon(Icons.remove, color: Colors.white),
                    ),
                    GestureDetector(
                      onTap: () => _showPageEditDialog(context),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: pillBrown,
                          borderRadius: BorderRadius.circular(22),
                        ),
                        child: Text(
                          '${book.pageProgress}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => onProgressChanged(book.pageProgress + 1),
                      icon: const Icon(Icons.add, color: Colors.white),
                    ),
                  ],
                ),
                const Spacer(),
                OutlinedButton.icon(
                  onPressed: () => onProgressChanged(book.pages),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(22),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    visualDensity: VisualDensity.compact,
                  ),
                  icon: const Icon(Icons.check, size: 18),
                  label: const Text('Finish'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Bottom: progress label, bar and page fraction.
            Text(
              'Progress',
              style: TextStyle(
                color: Colors.white.withOpacity(0.9),
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 8,
                backgroundColor: Colors.white24,
                valueColor: const AlwaysStoppedAnimation<Color>(
                  Color(0xFF8BC34A),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                '${book.pageProgress} / ${book.pages} pages',
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
