import 'package:flutter/material.dart';

import '../controller/pager_controller.dart';
import '../model/book.dart';
import 'book_detail_page.dart';
import 'book_notes_page.dart';

/// Home screen showing a quick summary of the user's reading:
/// last book being read + global statistics.
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  /// Shared controller (singleton) used to access books and stats.
  final PagerController _controller = PagerController.instance;

  /// Future that loads the current home summary
  /// (last reading book + library statistics).
  late Future<HomeSummary> _summaryFuture;

  @override
  void initState() {
    super.initState();
    // Initial load of the summary when the screen is created.
    _summaryFuture = _controller.getHomeSummary();
  }

  /// Reloads the summary from the controller and rebuilds the UI.
  Future<void> _refreshSummary() async {
    setState(() {
      _summaryFuture = _controller.getHomeSummary();
    });
  }

  /// Updates the reading progress of [book] via the controller
  /// then refreshes the summary so that the card and statistics stay in sync.
  Future<void> _changeProgress(Book book, int newPage) async {
    final ok = await _controller.setBookProgress(book, newPage);
    if (!mounted || !ok) return;
    await _refreshSummary();
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
              // Top header bar with the "Home" title.
              Container(
                width: double.infinity,
                color: headerBrown,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
                child: Text(
                  'Home',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              // Main content: scrollable column with last book and statistics.
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                  child: FutureBuilder<HomeSummary>(
                    future: _summaryFuture,
                    builder: (context, snapshot) {
                      // Initial loading state.
                      if (snapshot.connectionState == ConnectionState.waiting &&
                          !snapshot.hasData) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.only(top: 40),
                            child: CircularProgressIndicator(),
                          ),
                        );
                      } else if (snapshot.hasError) {
                        // Error while loading the summary.
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 40),
                            child: Text('Error: ${snapshot.error}'),
                          ),
                        );
                      }

                      // At this point we assume we have valid data.
                      final summary = snapshot.data!;
                      final book = summary.lastReadingBook;

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Welcome back',
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Here is a quick look at your reading.',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          const SizedBox(height: 24),
                          // Section: last book the user has been reading.
                          Text(
                            'Last book you read',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 12),
                          if (book == null)
                            // No book in progress: show an informational card.
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: const Color(0xFFDBC4AA),
                                borderRadius: BorderRadius.circular(18),
                              ),
                              child: const Text(
                                'You have no books in progress yet.',
                                style: TextStyle(color: Colors.white),
                              ),
                            )
                          else
                            // Card with progress controls and access
                            // to book info and notes.
                            HomeReadingCard(
                              book: book,
                              onProgressChanged: (newPage) =>
                                  _changeProgress(book, newPage),
                              onInfoPressed: () async {
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => BookDetailPage(book: book),
                                  ),
                                );
                                if (!mounted) return;
                                // After coming back from details,
                                // refresh summary in case status/progress changed.
                                await _refreshSummary();
                              },
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
                            ),
                          const SizedBox(height: 32),
                          // Section: global statistics on the user's library.
                          Text(
                            'Your statistics',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 12),
                          LibraryStatsBlock(stats: summary.stats),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Card summarising the last book the user has read,
/// with quick actions on progress, info and notes.
class HomeReadingCard extends StatelessWidget {
  final Book book;
  final void Function(int newPage) onProgressChanged;
  final VoidCallback onInfoPressed;
  final VoidCallback onNotesPressed;

  const HomeReadingCard({
    super.key,
    required this.book,
    required this.onProgressChanged,
    required this.onInfoPressed,
    required this.onNotesPressed,
  });

  /// Dialog to let the user set an exact page number for the book.
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

                // Validate numeric input.
                if (parsed == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Page must be a number.')),
                  );
                  return;
                }

                // Enforce valid page range for this book.
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

    // Ratio of pages read, used for the progress bar.
    final progress = book.pages > 0
        ? (book.pageProgress / book.pages).clamp(0.0, 1.0)
        : 0.0;

    return Container(
      decoration: BoxDecoration(
        color: cardBrown,
        borderRadius: BorderRadius.circular(22),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top row: cover, title/author, and buttons for info + notes.
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
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
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
          // Middle row: +/- buttons, direct page edit and finish button.
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
          // Bottom: progress label, bar and fraction.
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
    );
  }
}

/// Block showing global statistics about the user's library.
class LibraryStatsBlock extends StatelessWidget {
  final LibraryStats stats;

  const LibraryStatsBlock({super.key, required this.stats});

  @override
  Widget build(BuildContext context) {
    const cardColor = Color(0xFFF7EFE3);
    const labelStyle = TextStyle(fontSize: 13, color: Color(0xFF5F3416));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            children: [
              // First row: total books + finished books.
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Books owned', style: labelStyle),
                        const SizedBox(height: 4),
                        Text(
                          '${stats.totalBooks}',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Finished', style: labelStyle),
                        const SizedBox(height: 4),
                        Text(
                          '${stats.finishedCount}',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Second row: currently reading + total pages read.
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Currently reading', style: labelStyle),
                        const SizedBox(height: 4),
                        Text(
                          '${stats.readingCount}',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Pages read', style: labelStyle),
                        const SizedBox(height: 4),
                        Text(
                          '${stats.totalPagesRead}',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Third row: average rating over rated books.
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Average rating', style: labelStyle),
                        const SizedBox(height: 4),
                        Text(
                          stats.averageRating == 0
                              ? '—'
                              : stats.averageRating.toStringAsFixed(1),
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
