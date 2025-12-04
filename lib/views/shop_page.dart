import 'package:flutter/material.dart';
import '../controller/pager_controller.dart';
import '../model/book.dart';
import 'book_detail_page.dart';
import 'package:dropdown_button2/dropdown_button2.dart';

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

  // Use controller-backed filters to persist across pages
  List<BookFilter> get _savedFilters => _controller.savedFilters;
  BookFilter? get _activeFilter => _controller.activeFilter;
  set _activeFilter(BookFilter? f) {
    _controller.activeFilter = f;
    setState(() {}); // trigger UI update
  }

  @override
  void initState() {
    super.initState();
    _loadFuture = _controller.getShopBooks();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    setState(() {}); // forces rebuild when returning to page
}


  List<Book> _filteredBooks() {
    var base = _allBooks;

    // Search
    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      base = base.where((b) =>
        b.title.toLowerCase().contains(q) ||
        b.author.toLowerCase().contains(q) ||
        b.genre.toLowerCase().contains(q)
      ).toList();
    }

    // Advanced filter
    if (_activeFilter != null) {
      final f = _activeFilter!;

      if (f.query.isNotEmpty) {
        final q = f.query.toLowerCase();
        base = base.where((b) =>
          b.title.toLowerCase().contains(q) ||
          b.author.toLowerCase().contains(q) ||
          b.genre.toLowerCase().contains(q)
        ).toList();
      }

      if (f.minPages != null) {
        base = base.where((b) => b.pages >= f.minPages!).toList();
      }

      if (f.maxPages != null) {
        base = base.where((b) => b.pages <= f.maxPages!).toList();
      }

      if (f.genre != null && f.genre!.trim().isNotEmpty) {
        base = base.where(
          (b) => b.genre.toLowerCase() == f.genre!.toLowerCase(),
        ).toList();
      }

      if (f.status != null) {
        base = base.where((b) => b.section == f.status).toList();
      }

      if (f.minRating != null) {
        base = base.where((b) => b.rating >= f.minRating!).toList();
      }
      if (f.inLibrary != null) {
        if (f.inLibrary == true) {
          base = base.where((b) => b.inLibrary).toList();
        } else {
          base = base.where((b) => !b.inLibrary).toList();
        }
      }

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
      SnackBar(
        content: Text('"${book.title}" added to your library.'),
        backgroundColor: Colors.green, // <-- makes it green
      ),
    );

    setState(() {
      book.inLibrary = true;  // mark it as in library
    });
  }

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
              Column(
                children: [
                  const Text(
                    "Library Status",
                    style: TextStyle(
                      fontSize: 18,        
                      fontWeight: FontWeight.bold, // bold
                    ),
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
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
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
                      onPressed: (){
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

              // SEARCH
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
              // FILTERS ROW
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    // Filters dropdown
                    Expanded(
                      child: 
                      ValueListenableBuilder<List<BookFilter>>(
                        valueListenable: _controller.savedFiltersNotifier,
                        builder: (context, savedFilters, _) {
                          return DropdownButton<BookFilter?>(
                            value: _activeFilter, // the selected filter
                            isExpanded: true,
                            hint: const Text('My Filters'), // shows when no filter selected
                            items: [
                              // "None" option
                              DropdownMenuItem<BookFilter?>(
                                value: null,
                                child: const Text('None', style: TextStyle(fontWeight: FontWeight.bold)),
                              ),
                              // Saved filters
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
                                            Navigator.pop(context); // close dropdown first
                                            Future.delayed(Duration.zero, () {
                                              _openFilterDialog(editFilter: f);
                                            });
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
                              // Only the filter name shows in the closed button, no icons
                              return [
                                for (var f in [null, ...savedFilters])
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 4),
                                    child: Text(f?.name ?? 'None', overflow: TextOverflow.ellipsis),
                                  ),
                              ];
                            },
                          );
                        },
                      )

                    ),

                    const SizedBox(width: 12),

                    // New Filter button
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

              // BOOK LIST
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

                    final books = _filteredBooks();

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
                            await Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => BookDetailPage(book: book)),
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
            OutlinedButton(
              onPressed: book.inLibrary ? null : onAddPressed,
              style: ButtonStyle(
                foregroundColor: MaterialStateProperty.resolveWith<Color>(
                  (states) => Colors.white, // text color for all states
                ),
                backgroundColor: MaterialStateProperty.resolveWith<Color>(
                  (states) {
                    if (states.contains(MaterialState.disabled)) return Colors.grey[600]!; // disabled bg
                    return Colors.green; // normal bg
                  },
                ),
                side: MaterialStateProperty.all(const BorderSide(color: Colors.white70)),
                shape: MaterialStateProperty.all(
                  RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                ),
                padding: MaterialStateProperty.all(
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                ),
                textStyle: MaterialStateProperty.all(
                  const TextStyle(fontSize: 12),
                ),
              ),
              child: Text(book.inLibrary ? 'Already in library' : 'Add to library'),
            ),


          ],
        ),
      ),
    );
  }
}
