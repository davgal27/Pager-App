// AUTHOR: DAVE GALEA XGALEAD00

import 'package:flutter/material.dart';
import '../controller/pager_controller.dart';
import '../model/book.dart';
import 'book_detail_page.dart';
import 'shop_page.dart';
import 'book_notes_page.dart';

/// LIBRARY PAGE WIDGET
class LibraryPage extends StatefulWidget {
  const LibraryPage({super.key});

  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage> {
  // CONTROLLER AND STATE
  final PagerController _controller = PagerController.instance;

  late Future<List<Book>> _loadFuture; // Future for initial book loading
  List<Book> _allBooks = []; // Local copy of books for UI updates
  String _searchQuery = ''; // Current search text

  final TextEditingController _searchController = TextEditingController(); // Text controller for search input

  // LIFECYCLE METHODS
  @override
  void initState() {
    super.initState();
    _loadFuture = _controller.getLibraryBooks();
    _controller.libraryUpdateNotifier.addListener(_onLibraryUpdated);
  }

  void _onLibraryUpdated() async {
    // Callback for when the library updates
    final updatedBooks = await _controller.getLibraryBooks();
    if (!mounted) return;
    setState(() {
      _allBooks = updatedBooks;
    });
  }

  @override
  void dispose() {
    _controller.libraryUpdateNotifier.removeListener(_onLibraryUpdated);
    super.dispose();
  }

  // FILTER GETTERS AND SETTERS
  List<BookFilter> get _savedFilters => _controller.savedFilters;
  BookFilter? get _activeFilter => _controller.activeFilter;

  set _activeFilter(BookFilter? f) {
    _controller.activeFilter = f;
    setState(() {}); // Refresh UI when active filter changes
  }

  // STATUS HELPERS
  Color _statusColor(Status status) {
    switch (status) {
      case Status.toread:
        return Colors.orange[100]!;
      case Status.reading:
        return Colors.green[100]!;
      case Status.finished:
        return Colors.blue[100]!;
    }
  }

  String _statusLabel(Status status) {
    switch (status) {
      case Status.toread:
        return 'To read';
      case Status.reading:
        return 'Reading';
      case Status.finished:
        return 'Finished';
    }
  }

  // FILTER DIALOG
  Future<void> _openFilterDialog({BookFilter? filter}) async {
    final nameController = TextEditingController(text: filter?.name ?? '');
    final queryController = TextEditingController(text: filter?.query ?? '');
    final minController = TextEditingController(text: filter?.minPages?.toString() ?? '');
    final maxController = TextEditingController(text: filter?.maxPages?.toString() ?? '');
    String? selectedGenre = filter?.genre;
    Status? selectedStatus = filter?.status;
    int? minRating = filter?.minRating;

    final result = await showDialog<BookFilter>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(filter == null ? 'New Filter' : 'Edit Filter'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // FILTER FIELDS
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              TextField(
                controller: queryController,
                decoration: const InputDecoration(labelText: 'Search query'),
              ),
              TextField(
                controller: minController,
                decoration: const InputDecoration(labelText: 'Min pages'),
                keyboardType: TextInputType.number,
              ),
              TextField(
                controller: maxController,
                decoration: const InputDecoration(labelText: 'Max pages'),
                keyboardType: TextInputType.number,
              ),
              TextField(
                decoration: const InputDecoration(labelText: 'Genre'),
                controller: TextEditingController(text: selectedGenre),
                onChanged: (v) => selectedGenre = v,
              ),
              DropdownButtonFormField<Status>(
                value: selectedStatus,
                decoration: const InputDecoration(labelText: 'Status'),
                items: Status.values
                    .map((s) => DropdownMenuItem(
                          value: s,
                          child: Text(s.toString().split('.').last),
                        ))
                    .toList(),
                onChanged: (v) => selectedStatus = v,
              ),
              DropdownButtonFormField<int>(
                value: minRating,
                decoration: const InputDecoration(labelText: 'Minimum rating'),
                items: List.generate(5, (i) => DropdownMenuItem(
                      value: i + 1,
                      child: Text('${i + 1}'),
                    )),
                onChanged: (v) => minRating = v,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              final newFilter = BookFilter(
                id: filter?.id ?? DateTime.now().toIso8601String(),
                name: nameController.text,
                query: queryController.text,
                minPages: minController.text.isEmpty ? null : int.tryParse(minController.text),
                maxPages: maxController.text.isEmpty ? null : int.tryParse(maxController.text),
                genre: selectedGenre,
                status: selectedStatus,
                minRating: minRating,
              );
              Navigator.pop(context, newFilter);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result != null) {
      setState(() {
        _savedFilters.removeWhere((f) => f.id == result.id);
        _savedFilters.add(result);
        _activeFilter = result; // Auto-apply the new filter
      });
    }
  }

  // BUILD METHOD
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
              // HEADER
              Container(
                width: double.infinity,
                color: headerBrown,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                child: Text(
                  'Library',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ),
              const SizedBox(height: 8),

              // FILTER CONTROLS ROW
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    // Filters dropdown
                    Expanded(
                      child: ValueListenableBuilder<List<BookFilter>>(
                        valueListenable: _controller.savedFiltersNotifier,
                        builder: (context, savedFilters, _) {
                          return DropdownButton<BookFilter?>(
                            value: _activeFilter, // currently selected filter 
                            isExpanded: true,
                            hint: const Text('My Filters'),
                            items: [
                              // "None" Option
                              DropdownMenuItem<BookFilter?>(
                                value: null,
                                child: const Text('None', style: TextStyle(fontWeight: FontWeight.bold)),
                              ),
                              //Saved Filters
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
                                                  _openFilterDialog(filter: f);
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
                              // only show filter name in closed dropdown
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
                    const SizedBox(width: 12),
                  ],
                ),
              ),

              const SizedBox(height: 8),

              // SEARCH + SHOP ROW
              LibrarySearchRow(
                controller: _searchController,
                onSearchChanged: (value) {
                  setState(() {
                    _searchQuery = value;
                    _activeFilter = null; // reset active filter if user types manually
                  });
                },
              ),

              const SizedBox(height: 8),

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

                    final books = _controller.filterLibraryBooks(
                      searchQuery: _searchQuery,
                      activeFilter: _activeFilter,
                    );

                    if (books.isEmpty) {
                      return const Center(child: Text('No books found.'));
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      itemCount: books.length,
                      itemBuilder: (context, index) {
                        final b = books[index];

                        return Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: const Color(0xFF6B3A19),
                            borderRadius: BorderRadius.circular(22),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // BOOK COVER
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: Image.asset(
                                    b.coverAsset,
                                    width: 90,
                                    height: 130,
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
                                        b.title,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                            ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        b.author,
                                        style: TextStyle(color: Colors.white.withOpacity(0.9)),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${b.pages} pages',
                                        style: const TextStyle(color: Colors.white70),
                                      ),
                                      const SizedBox(height: 8),

                                      // STATUS PILL
                                      InkWell(
                                        borderRadius: BorderRadius.circular(22),
                                        onTap: () async {
                                          final selected = await showModalBottomSheet<Status>(
                                            context: context,
                                            builder: (ctx) => SafeArea(
                                              child: Column(
                                                mainAxisSize: MainAxisSize.min,
                                                children: Status.values.map((status) {
                                                  return ListTile(
                                                    leading: CircleAvatar(radius: 8, backgroundColor: _statusColor(status)),
                                                    title: Text(_statusLabel(status)),
                                                    trailing: status == b.section ? const Icon(Icons.check) : null,
                                                    onTap: () => Navigator.of(ctx).pop(status),
                                                  );
                                                }).toList(),
                                              ),
                                            ),
                                          );
                                          if (selected == null || selected == b.section) return;
                                          final ok = await _controller.changeSection(b, selected);
                                          if (!mounted || !ok) return;
                                          setState(() {});
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                          decoration: BoxDecoration(
                                            color: _statusColor(b.section),
                                            borderRadius: BorderRadius.circular(22),
                                          ),
                                          child: Text(
                                            _statusLabel(b.section),
                                            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 8),

                                      // RATING STARS
                                      Row(
                                        children: List.generate(5, (i) {
                                          final filled = (i + 1) <= b.rating;
                                          return GestureDetector(
                                            onTap: () async {
                                              final ok = await _controller.updateRating(b, i + 1);
                                              if (!mounted || !ok) return;
                                              setState(() {});
                                            },
                                            child: Icon(filled ? Icons.star : Icons.star_border, color: Colors.yellow, size: 20),
                                          );
                                        }).expand((widget) => [widget, const SizedBox(width: 4)]).toList()..removeLast(),
                                      ),
                                    ],
                                  ),
                                ),

                                const SizedBox(width: 12),

                                // ACTION BUTTONS COLUMN
                                Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.info_outline, color: Colors.white, size: 20),
                                      padding: EdgeInsets.zero,
                                      visualDensity: VisualDensity.compact,
                                      onPressed: () {
                                        Navigator.push(context, MaterialPageRoute(builder: (_) => BookDetailPage(book: b)));
                                      },
                                    ),
                                    const SizedBox(height: 8),
                                    OutlinedButton.icon(
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: Colors.white,
                                        side: const BorderSide(color: Colors.white70),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                        visualDensity: VisualDensity.compact,
                                        textStyle: const TextStyle(fontSize: 12),
                                      ),
                                      onPressed: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(builder: (_) => BookNotesPage(book: b, initialPage: b.pageProgress)),
                                        );
                                      },
                                      icon: const Icon(Icons.sticky_note_2_outlined, size: 16),
                                      label: const Text('Notes'),
                                    ),
                                    OutlinedButton(
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: Colors.red,
                                        side: const BorderSide(color: Colors.red),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                        visualDensity: VisualDensity.compact,
                                        textStyle: const TextStyle(fontSize: 12),
                                      ),
                                      onPressed: () async {
                                        final ok = await _controller.removeBookFromLibrary(b);
                                        if (!mounted || !ok) return;

                                        setState(() {
                                          _allBooks.removeWhere((element) => element.id == b.id);
                                        });

                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text('"${b.title}" removed from library.'),
                                            backgroundColor: Colors.red,
                                          ),
                                        );
                                      },
                                      child: const Text('Remove'),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
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

/// LIBRARY SEARCH + SHOP ROW
class LibrarySearchRow extends StatefulWidget {
  const LibrarySearchRow({super.key, required this.controller, required this.onSearchChanged});
  final TextEditingController controller;
  final ValueChanged<String> onSearchChanged;

  @override
  State<LibrarySearchRow> createState() => _LibrarySearchRowState();
}

class _LibrarySearchRowState extends State<LibrarySearchRow> {
  bool _isExpanded = false; // Search field expanded state

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Row(
      children: [
        // SEARCH FIELD
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: _isExpanded ? screenWidth - 32 : screenWidth * 0.6,
          child: TextField(
            controller: widget.controller,
            autofocus: _isExpanded,
            decoration: InputDecoration(
              hintText: 'Search collection!',
              filled: true,
              fillColor: Colors.white,
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _isExpanded
                  ? IconButton(
                      icon: const Icon(Icons.arrow_back),
                      onPressed: () {
                        setState(() {
                          _isExpanded = false;
                          widget.controller.clear();
                          widget.onSearchChanged('');
                        });
                      },
                    )
                  : null,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(26), borderSide: BorderSide.none),
            ),
            onTap: () => setState(() => _isExpanded = true),
            onChanged: widget.onSearchChanged,
            onSubmitted: (_) => setState(() => _isExpanded = false),
          ),
        ),
        const SizedBox(width: 8),

        // SHOP BUTTON
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: _isExpanded ? 0 : screenWidth * 0.38,
          height: 56,
          child: _isExpanded
              ? null
              : ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6B3A19),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                  icon: const Icon(Icons.storefront, color: Colors.white, size: 28),
                  label: const Text('Shop', style: TextStyle(color: Colors.white, fontSize: 20)),
                  onPressed: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const ShopPage()));
                    setState(() {});
                  },
                ),
        ),
      ],
    );
  }
}
