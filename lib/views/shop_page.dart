import 'package:flutter/material.dart';

import '../controller/pager_controller.dart';
import '../model/book.dart';
import 'book_detail_page.dart';

class ShopPage extends StatefulWidget {
  const ShopPage({super.key});

  @override
  State<ShopPage> createState() => _ShopPageState();
}

class _ShopPageState extends State<ShopPage> {
  final PagerController _controller = PagerController.instance;

  late Future<List<Book>> _loadFuture;
  List<Book> _allBooks = [];
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadFuture = _controller.getShopBooks();
  }

  List<Book> _filteredBooks() {
    var base = _allBooks;
    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      base = base.where((b) {
        return b.title.toLowerCase().contains(q) ||
            b.author.toLowerCase().contains(q) ||
            b.genre.toLowerCase().contains(q);
      }).toList();
    }
    return base;
  }

  Future<void> _addToLibrary(Book book) async {
    final ok = await _controller.addBookToLibrary(book);
    if (!mounted) return;

    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not add book to your library.')),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('"${book.title}" added to your library.')),
    );

    setState(() {
      // αφού "το αγοράσαμε", το βγάζουμε από το shop
      _allBooks.removeWhere((b) => b.id == book.id);
    });
  }

  @override
  Widget build(BuildContext context) {
    const background = Color(0xFFF5F0E8);
    const headerBrown = Color(0xFF6B3A19);

    return Scaffold(
      backgroundColor: headerBrown,
      body: SafeArea(
        bottom: false,
        child: Container(
          color: background,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // HEADER
              Container(
                width: double.infinity,
                color: headerBrown,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Shop',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // SEARCH
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Search books in shop',
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

              // LIST
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
                      _allBooks = snapshot.data!;
                    }

                    final books = _filteredBooks();

                    if (books.isEmpty) {
                      return const Center(
                        child: Text('No books available in shop.'),
                      );
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      itemCount: books.length,
                      itemBuilder: (context, index) {
                        final book = books[index];
                        return _ShopBookCard(
                          book: book,
                          onInfoPressed: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => BookDetailPage(book: book),
                              ),
                            );
                            if (!mounted) return;
                            setState(() {});
                          },
                          onAddPressed: () => _addToLibrary(book),
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

class _ShopBookCard extends StatelessWidget {
  const _ShopBookCard({
    required this.book,
    required this.onInfoPressed,
    required this.onAddPressed,
  });

  final Book book;
  final VoidCallback onInfoPressed;
  final VoidCallback onAddPressed;

  @override
  Widget build(BuildContext context) {
    const cardBrown = Color(0xFF6B3A19);

    return Container(
      margin: const EdgeInsets.only(bottom: 12.0),
      decoration: BoxDecoration(
        color: cardBrown,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    book.genre,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white60,
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: onInfoPressed,
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.zero,
                    ),
                    child: const Text('More info'),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton(
              onPressed: onAddPressed,
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
              child: const Text('Add to library'),
            ),
          ],
        ),
      ),
    );
  }
}
