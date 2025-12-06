/// AUTHORS : NIKOLAS PAPADAKIS (XPAPADN00)

import 'package:flutter/material.dart';

import '../controller/pager_controller.dart';
import '../model/book.dart';
import 'book_detail_page.dart';

// Screen that shows all books in the "To read" section.
class ToReadPage extends StatefulWidget {
  const ToReadPage({super.key});

  @override
  State<ToReadPage> createState() => _ToReadPageState();
}

class _ToReadPageState extends State<ToReadPage> {

  // Shared controller used to access and update book data.
  final PagerController _controller = PagerController.instance;

  // Future that loads all books from the library.
  late Future<List<Book>> _loadFuture;
  List<Book> _allBooks = [];
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    // Load all library books once.
    _loadFuture = _controller.getLibraryBooks();
  }

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

  // Move a book from "To read" to "Reading".
  Future<void> _moveToReading(Book book) async {
    // Keep track of the section the book started from
    final previousSection = book.section;

    //  Try to move it to Reading
    final ok = await _controller.changeSection(book, Status.reading);
    if (!mounted) return;

    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not move book to Reading.')),
      );
      return;
    }

    //  Ask the controller if we should show a message
    final message = _controller.buildSectionChangeMessage(
      book,
      previousSection,
      Status.reading,
    );

    //  If there is a message, show a green SnackBar
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

    //  Remove the book from the "To read" list
    setState(() {
      _allBooks.removeWhere((b) => b.id == book.id);
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
              // Header
              Container(
                width: double.infinity,
                color: headerBrown,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
                child: Text(
                  'To read',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ),
              const SizedBox(height: 12),

              // Search bar to filter books
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Search a book to read',
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

              // List of books
              Expanded(
                child: FutureBuilder<List<Book>>(
                  future: _loadFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting &&
                        _allBooks.isEmpty) {
                      return const Center(child: CircularProgressIndicator());
                    } else if (snapshot.hasError && _allBooks.isEmpty) {
                      return Center(
                        child: Text('Error: ${snapshot.error}'),
                      );
                    }

                    if (snapshot.hasData && _allBooks.isEmpty) {
                      // the book that is in the list  "To read"
                      _allBooks = snapshot.data!
                          .where((b) => b.inLibrary && b.section == Status.toread)
                          .toList();
                    }

                    final books = _filteredBooks();

                    if (books.isEmpty) {
                      if (_allBooks.isEmpty) {
                        return const Center(
                          child: Text('No books in your To read list.'),
                        );
                      } else {
                        return const Center(
                          child: Text('No books match your search.'),
                        );
                      }
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      itemCount: books.length,
                      itemBuilder: (context, index) {
                        final book = books[index];
                        return ToReadBookCard(
                          book: book,
                          onInfoPressed: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => BookDetailPage(book: book),
                              ),
                            );
                            if (!mounted) return;
                            setState(() {}); // refresh if somethi change to  detail
                          },
                          onStartReading: () => _moveToReading(book),
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

class ToReadBookCard extends StatelessWidget {
  const ToReadBookCard({
    super.key,
    required this.book,
    required this.onInfoPressed,
    required this.onStartReading,
  });

  final Book book;
  final VoidCallback onInfoPressed;
  final VoidCallback onStartReading;

  @override
  Widget build(BuildContext context) {
    const cardBrown = Color(0xFF6B3A19);

    return Container(
      margin: const EdgeInsets.only(bottom: 16.0),
      decoration: BoxDecoration(
        color: cardBrown,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // book Cover
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

            // Text and buttons
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title and  Info button top-right
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          book.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.info_outline, color: Colors.white),
                        onPressed: onInfoPressed,
                      ),
                    ],
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
                  const SizedBox(height: 12),

                  // Start reading button aligned bottom-right
                  Align(
                    alignment: Alignment.centerRight,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 130),
                      child: OutlinedButton(
                        onPressed: onStartReading,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Colors.white),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(22),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 8,
                          ),
                          visualDensity: VisualDensity.compact,
                        ),
                        
                        child: const Text(
                          'Start reading',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
