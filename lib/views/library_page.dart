import 'package:flutter/material.dart';

import '../controller/pager_controller.dart';
import '../model/book.dart';
import 'book_detail_page.dart';
import 'shop_page.dart';


class LibraryPage extends StatefulWidget {
  const LibraryPage({super.key});

  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage> {
  final PagerController _controller = PagerController.instance;

  late Future<List<Book>> _loadFuture;
  List<Book> _allBooks = [];
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
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
              Container(
                width: double.infinity,
                color: headerBrown,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
                child: Text(
                  'Library',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 12),
             Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                children: [
                  // Search bar
                  Expanded(
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: 'Search by title or author',
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
                  const SizedBox(width: 8),
                  // Shop button
                  IconButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ShopPage(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.storefront),
                    tooltip: 'Open shop',
                  ),
                ],
              ),
            ),

              const SizedBox(height: 8),
              Expanded(
                child: FutureBuilder<List<Book>>(
                  future: _loadFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting &&
                        _allBooks.isEmpty) {
                      return const Center(child: CircularProgressIndicator());
                    } else if (snapshot.hasError && _allBooks.isEmpty) {
                      return Center(child: Text('Error: ${snapshot.error}'));
                    }

                    if (snapshot.hasData && _allBooks.isEmpty) {
                      _allBooks = snapshot.data!;
                    }

                    final books = _filteredBooks();

                    if (books.isEmpty) {
                      return const Center(child: Text('No books found.'));
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      itemCount: books.length,
                      itemBuilder: (context, index) {
                        final b = books[index];
                        return ListTile(
                          title: Text(b.title),
                          subtitle: Text(b.author),
                          onTap: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => BookDetailPage(book: b),
                              ),
                            );
                            if (!mounted) return;
                            setState(() {
                              _allBooks = [];
                              _loadFuture = _controller.getLibraryBooks();
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
