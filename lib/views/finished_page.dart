/// AUTHORS : NIKOLAS PAPADAKIS (XPAPADN00)

import 'package:flutter/material.dart';

import '../controller/pager_controller.dart';
import '../model/book.dart';
import 'book_detail_page.dart';
import 'book_notes_page.dart';

// Screen that shows all finished books from the library.
class FinishedPage extends StatefulWidget {
  const FinishedPage({super.key});

  @override
  State<FinishedPage> createState() => _FinishedPageState();
}

class _FinishedPageState extends State<FinishedPage> {

  // Shared controller used to access and update book data.
  final PagerController _controller = PagerController.instance;

  // Future used for the initial load of library books.
  late Future<List<Book>> _loadFuture;
  List<Book> _allBooks = [];
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    // Load all library books once and keep only finished books in memory.
    _loadFuture = _controller.getLibraryBooks();
  }

  // Returns finished books filtered by the current search query.
  List<Book> _filteredBooks() {
    final base = _allBooks;
    if (_searchQuery.trim().isEmpty) return List<Book>.from(base);

    final q = _searchQuery.toLowerCase();
    return base.where((b) {
      return b.title.toLowerCase().contains(q) ||
          b.author.toLowerCase().contains(q);
    }).toList();
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
              // Header bar
              Container(
                width: double.infinity,
                color: headerBrown,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
                child: Text(
                  'Finished',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ),

              // Search bar το filter finished books
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Search your finished books',
                    filled: true,
                    fillColor: Colors.white,
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(26),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onChanged: (value) {
                    setState(() => _searchQuery = value);
                  },
                ),
              ),
              const SizedBox(height: 16),

              // List of finished books
              Expanded(
                child: FutureBuilder<List<Book>>(
                  future: _loadFuture,
                  builder: (context, snapshot) {
                    // Initial loading: no cached books yet.
                    if (snapshot.connectionState == ConnectionState.waiting &&
                        _allBooks.isEmpty) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    // Initial error state.
                    if (snapshot.hasError && _allBooks.isEmpty) {
                      return Center(
                        child: Text('Error: ${snapshot.error}'),
                      );
                    }

                    // First successful load: cache only finished books.
                    if (snapshot.hasData && _allBooks.isEmpty) {
                      _allBooks = snapshot.data!
                          .where(
                            (b) =>
                                b.inLibrary &&
                                b.section == Status.finished,
                          )
                          .toList();
                    }

                    final books = _filteredBooks();

                    // Empty states depending on library / search.
                    if (books.isEmpty) {
                      if (_allBooks.isEmpty) {
                        return const Center(
                          child: Text('No finished books yet.'),
                        );
                      } else {
                        return const Center(
                          child: Text('No books match your search.'),
                        );
                      }
                    }

                    // Normal list view.
                    return ListView.builder(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      itemCount: books.length,
                      itemBuilder: (context, index) {
                        final book = books[index];

                        return FinishedBookCard(
                          book: book,
                          // Update rating when a star is pressed.
                          onRatePressed: (starIndex) async {
                            final ok =
                                await _controller.updateRating(book, starIndex);
                            if (!mounted) return;
                            if (!ok) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Could not update rating.'),
                                ),
                              );
                              return;
                            }
                            // Rebuild to reflect the new rating.
                            setState(() {});
                          },
                          // Open book details screen.
                          onInfoPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => BookDetailPage(book: book),
                              ),
                            );
                          },
                          // Open notes screen for this book.
                          onNotesPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => BookNotesPage(
                                  book: book,
                                  initialPage: book.pages,
                                ),
                              ),
                            );
                          },

                          // Start rereading the book.
                          onRereadPressed: () async {
                          // Remember from which section the book started (should be Finished)
                          final previousSection = book.section;

                          final ok = await _controller.startReread(book);
                          if (!mounted) return;

                          if (!ok) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Could not start rereading.'),
                              ),
                            );
                            return;
                          }

                          // Ask controller if this section change should show a message
                          final message = _controller.buildSectionChangeMessage(
                            book,
                            previousSection,
                            book.section, // after startReread this should be Status.reading
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

                          // The book is now in the Reading section
                          setState(() {
                            // Remove from finished books list
                            _allBooks.removeWhere((b) => b.id == book.id);
                          });
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


// Card widget for a finished book in the Finished list.
class FinishedBookCard extends StatelessWidget {
  const FinishedBookCard({
    super.key,
    required this.book,
    required this.onRatePressed,
    required this.onInfoPressed,
    required this.onNotesPressed,
    required this.onRereadPressed,
  });

  final Book book;
  final void Function(int starIndex) onRatePressed;
  final VoidCallback onInfoPressed;
  final VoidCallback onNotesPressed;
  final VoidCallback onRereadPressed;

  @override
  Widget build(BuildContext context) {
    const cardBrown = Color(0xFF6B3A19);

    // Number of times this book has been fully completed.
    
    final totalReads = book.completedReadings > 0 ? book.completedReadings : 1;

    return Container(
      margin: const EdgeInsets.only(bottom: 12.0),
      decoration: BoxDecoration(
        color: cardBrown,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top section: cover + title/author/pages + actions.
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Book cover (small thumbnail).
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.asset(
                    book.coverAsset,
                    width: 72,
                    height: 104,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(width: 12),

                // Title / author / pages / total reads / past ratings.
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        book.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context)
                            .textTheme
                            .titleSmall
                            ?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        book.author,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontStyle: FontStyle.italic,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${book.pages} pages',
                        style: const TextStyle(
                          color: Colors.white60,
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Read $totalReads time${totalReads == 1 ? '' : 's'}',
                        style: const TextStyle(
                          color: Colors.white60,
                          fontSize: 11,
                        ),
                      ),
                      
                        
                      
                    ],
                  ),
                ),

                const SizedBox(width: 8),

                // Right column: Info + Notes + Reread buttons.
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.info_outline,
                        color: Colors.white,
                        size: 20,
                      ),
                      padding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact,
                      onPressed: onInfoPressed,
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white70),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        visualDensity: VisualDensity.compact,
                        textStyle: const TextStyle(fontSize: 12),
                      ),
                      onPressed: onNotesPressed,
                      icon: const Icon(
                        Icons.sticky_note_2_outlined,
                        size: 16,
                      ),
                      label: const Text('Notes'),
                    ),
                    const SizedBox(height: 8),
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.amberAccent,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        visualDensity: VisualDensity.compact,
                        textStyle: const TextStyle(fontSize: 12),
                      ),
                      onPressed: onRereadPressed,
                      icon: const Icon(
                        Icons.refresh,
                        size: 16,
                      ),
                      label: const Text('Reread'),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 8),

            // Rating row (interactive stars for the current reading).
            Row(
              children: List.generate(5, (i) {
                final filled = (i + 1) <= book.rating;
                return IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                  icon: Icon(
                    filled ? Icons.star : Icons.star_border,
                    color: Colors.yellow,
                    size: 18,
                  ),
                  onPressed: () => onRatePressed(i + 1),
                  tooltip: 'Rate ${i + 1}',
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}
