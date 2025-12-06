/// AUTHOR : DAVE GALEA (XGALEAD00)

import 'package:flutter/material.dart';
import '../controller/pager_controller.dart';
import '../model/book.dart';
import 'book_detail_page.dart';

/// SHOP PAGE WIDGET
class ShopPage extends StatefulWidget {
  const ShopPage({super.key});

  @override
  State<ShopPage> createState() => _ShopPageState();
}

class _ShopPageState extends State<ShopPage> {
  // CONTROLLER AND STATE
  final PagerController _controller = PagerController.instance;

  late Future<List<Book>> _loadFuture; // Future for initial shop book loading
  List<Book> _allBooks = []; // Local copy for UI updates
  String _searchQuery = ''; // Current search text

  // FILTERS BACKED BY CONTROLLER
  List<BookFilter> get _savedFilters => _controller.savedFilters;
  BookFilter? get _activeFilter => _controller.activeFilter;
  set _activeFilter(BookFilter? f) {
    _controller.activeFilter = f;
    setState(() {}); // Update UI when filter changes
  }

  // LIFECYCLE METHODS
  @override
  void initState() {
    super.initState();
    _loadFuture = _controller.getShopBooks(); // Load books from shop
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    setState(() {}); // Rebuild when returning to page
  }

  // ADD BOOK TO LIBRARY
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
      SnackBar(
        content: Text('"${book.title}" added to your library.'),
        backgroundColor: Colors.green,
      ),
    );

    setState(() {
      book.inLibrary = true; // Mark book as added
    });
  }

  // FILTER DIALOG
  void _openFilterDialog({BookFilter? editFilter}) {
    final nameController = TextEditingController(text: editFilter?.name ?? '');
    final queryController = TextEditingController(text: editFilter?.query ?? '');
    final minController = TextEditingController(text: editFilter?.minPages?.toString() ?? '');
    final maxController = TextEditingController(text: editFilter?.maxPages?.toString() ?? '');
    String? selectedGenre = editFilter?.genre ?? '';
    Status? selectedStatus = editFilter?.status;
    int? minRating = editFilter?.minRating;
    bool? inLibraryFilter = editFilter?.inLibrary;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx2, setStateDialog) => AlertDialog(
          title: Text(editFilter != null ? 'Edit Filter' : 'New Filter'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // TEXT FIELDS FOR FILTER
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Name'),
                ),
                TextField(
                  controller: queryController,
                  decoration: const InputDecoration(labelText: 'Query'),
                ),
                TextField(
                  controller: minController,
                  decoration: const InputDecoration(labelText: 'Min Pages'),
                  keyboardType: TextInputType.number,
                ),
                TextField(
                  controller: maxController,
                  decoration: const InputDecoration(labelText: 'Max Pages'),
                  keyboardType: TextInputType.number,
                ),
                TextField(
                  decoration: const InputDecoration(labelText: 'Genre'),
                  onChanged: (v) => selectedGenre = v,
                ),
                // STATUS DROPDOWN
                DropdownButtonFormField<Status>(
                  decoration: const InputDecoration(labelText: 'Status'),
                  value: selectedStatus,
                  items: Status.values
                      .map((s) => DropdownMenuItem(
                            value: s,
                            child: Text(s.toString().split('.').last.replaceAll('toread', 'to read')),
                          ))
                      .toList(),
                  onChanged: (v) => selectedStatus = v,
                ),
                // MIN RATING DROPDOWN
                DropdownButtonFormField<int>(
                  decoration: const InputDecoration(labelText: 'Min Rating'),
                  value: minRating,
                  items: List.generate(
                    5,
                    (i) => DropdownMenuItem(
                      value: i + 1,
                      child: Text('${i + 1}'),
                    ),
                  ),
                  onChanged: (v) => minRating = v,
                ),
                // LIBRARY STATUS RADIO BUTTONS
                Column(
                  children: [
                    const Text(
                      "Library Status",
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    RadioListTile<bool?>(
                      title: const Text("All books"),
                      value: null,
                      groupValue: inLibraryFilter,
                      onChanged: (v) => setStateDialog(() => inLibraryFilter = v),
                    ),
                    RadioListTile<bool?>(
                      title: const Text("In library"),
                      value: true,
                      groupValue: inLibraryFilter,
                      onChanged: (v) => setStateDialog(() => inLibraryFilter = v),
                    ),
                    RadioListTile<bool?>(
                      title: const Text("Not in library"),
                      value: false,
                      groupValue: inLibraryFilter,
                      onChanged: (v) => setStateDialog(() => inLibraryFilter = v),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            TextButton(
              onPressed: () {
                // CREATE OR UPDATE FILTER
                final filter = BookFilter(
                  id: editFilter?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
                  name: nameController.text,
                  query: queryController.text,
                  minPages: int.tryParse(minController.text),
                  maxPages: int.tryParse(maxController.text),
                  genre: (selectedGenre?.isEmpty ?? true) ? null : selectedGenre,
                  status: selectedStatus,
                  minRating: minRating,
                  inLibrary: inLibraryFilter,
                );

                final updatedList = List<BookFilter>.from(_controller.savedFilters);
                if (editFilter != null) {
                  final index = updatedList.indexWhere((f) => f.id == editFilter.id);
                  updatedList[index] = filter;
                } else {
                  updatedList.add(filter);
                }

                _controller.savedFiltersNotifier.value = updatedList;
                _activeFilter = filter;
                _searchQuery = filter.query;

                setState(() {});
                Navigator.pop(ctx);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  // BUILD METHOD
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
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () {
                        Navigator.pop(context);
                        setState(() {});
                      },
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

              // SEARCH FIELD
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Add to your collection...',
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

              const SizedBox(height: 8),

              // FILTERS ROW
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: ValueListenableBuilder<List<BookFilter>>(
                        valueListenable: _controller.savedFiltersNotifier,
                        builder: (context, savedFilters, _) {
                          return DropdownButton<BookFilter?>(
                            value: _activeFilter,
                            isExpanded: true,
                            hint: const Text('My Filters'),
                            items: [
                              // NONE OPTION
                              DropdownMenuItem<BookFilter?>(
                                value: null,
                                child: const Text('None', style: TextStyle(fontWeight: FontWeight.bold)),
                              ),
                              // SAVED FILTERS
                              ...savedFilters.map((f) => DropdownMenuItem<BookFilter?>(
                                    value: f,
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Flexible(child: Text(f.name, overflow: TextOverflow.ellipsis)),
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            IconButton(
                                              icon: const Icon(Icons.edit, size: 18, color: Colors.blue),
                                              onPressed: () {
                                                Navigator.pop(context);
                                                Future.delayed(Duration.zero, () => _openFilterDialog(editFilter: f));
                                              },
                                            ),
                                            IconButton(
                                              icon: const Icon(Icons.delete, size: 18, color: Colors.red),
                                              onPressed: () {
                                                final newList = List<BookFilter>.from(savedFilters)..remove(f);
                                                _controller.savedFiltersNotifier.value = newList;
                                                if (_activeFilter?.id == f.id) {
                                                  setState(() {
                                                    _activeFilter = null;
                                                    _searchQuery = '';
                                                  });
                                                }
                                                Navigator.pop(context);
                                              },
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  )),
                            ],
                            onChanged: (f) {
                              setState(() {
                                _activeFilter = f;
                                _searchQuery = f?.query ?? '';
                              });
                            },
                            selectedItemBuilder: (context) {
                              return [for (var f in [null, ...savedFilters]) Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: Text(f?.name ?? 'None', overflow: TextOverflow.ellipsis))];
                            },
                          );
                        },
                      ),
                    ),

                    const SizedBox(width: 12),

                    // NEW FILTER BUTTON
                    ElevatedButton.icon(
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('New Filter'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6B3A19),
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () => _openFilterDialog(),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // SHOP BOOK LIST
              Expanded(
                child: FutureBuilder<List<Book>>(
                  future: _loadFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting && _allBooks.isEmpty) {
                      return const Center(child: CircularProgressIndicator());
                    } else if (snapshot.hasError && _allBooks.isEmpty) {
                      return Center(child: Text('Error: ${snapshot.error}'));
                    }

                    if (snapshot.hasData && _allBooks.isEmpty) {
                      _allBooks = snapshot.data!;
                    }

                    final books = _controller.filterShopBooks(
                      books: _allBooks,
                      query: _searchQuery,
                      filter: _activeFilter,
                    );

                    if (books.isEmpty) {
                      return const Center(child: Text('No books available in shop.'));
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      itemCount: books.length,
                      itemBuilder: (context, index) {
                        final book = books[index];
                        return _ShopBookCard(
                          book: book,
                          onInfoPressed: () async {
                            await Navigator.push(context, MaterialPageRoute(builder: (_) => BookDetailPage(book: book)));
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

/// SHOP BOOK CARD WIDGET
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
            // COVER IMAGE
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

            // BOOK INFO COLUMN
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    book.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    book.author,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    book.genre,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white60, fontSize: 11),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: onInfoPressed,
                    style: TextButton.styleFrom(foregroundColor: Colors.white, padding: EdgeInsets.zero),
                    child: const Text('More info'),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),

            // ADD TO LIBRARY BUTTON
            OutlinedButton(
              onPressed: book.inLibrary ? null : onAddPressed,
              style: ButtonStyle(
                foregroundColor: MaterialStateProperty.resolveWith<Color>((states) => Colors.white),
                backgroundColor: MaterialStateProperty.resolveWith<Color>(
                  (states) => states.contains(MaterialState.disabled) ? Colors.grey[600]! : Colors.green,
                ),
                side: MaterialStateProperty.all(const BorderSide(color: Colors.white70)),
                shape: MaterialStateProperty.all(RoundedRectangleBorder(borderRadius: BorderRadius.circular(18))),
                padding: MaterialStateProperty.all(const EdgeInsets.symmetric(horizontal: 10, vertical: 6)),
                textStyle: MaterialStateProperty.all(const TextStyle(fontSize: 12)),
              ),
              child: Text(book.inLibrary ? 'Already in library' : 'Add to library'),
            ),
          ],
        ),
      ),
    );
  }
}
