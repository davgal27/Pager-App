import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../controller/pager_controller.dart';
import '../model/book.dart';
import 'book_notes_page.dart';

class BookDetailPage extends StatefulWidget {
  final Book book;

  const BookDetailPage({super.key, required this.book});

  @override
  State<BookDetailPage> createState() => _BookDetailPageState();
}

class _BookDetailPageState extends State<BookDetailPage> {
  final PagerController _controller = PagerController.instance;
  late Book _book;

  bool _showHistory = false;

  @override
  void initState() {
    super.initState();
    _book = widget.book;
  }

  String _formatDate(String iso) {
    try {
      final d = DateTime.parse(iso);
      return DateFormat('d MMM yyyy').format(d);
    } catch (_) {
      return iso;
    }
  }

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

  Future<void> _onStarTapped(int starIndex) async {
    final ok = await _controller.updateRating(_book, starIndex);
    if (!mounted || !ok) return;
    setState(() {});
  }

  Future<void> _changeStatus() async {
    final selected = await showModalBottomSheet<Status>(
      context: context,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: Status.values.map((status) {
              return ListTile(
                leading: CircleAvatar(
                  radius: 8,
                  backgroundColor: _statusColor(status),
                ),
                title: Text(_statusLabel(status)),
                trailing: status == _book.section
                    ? const Icon(Icons.check)
                    : null,
                onTap: () {
                  Navigator.of(ctx).pop(status);
                },
              );
            }).toList(),
          ),
        );
      },
    );

    if (selected == null || selected == _book.section) return;

    // we keep the previous section for the message
    final previousSection = _book.section;

    final ok = await _controller.changeSection(_book, selected);
    if (!mounted || !ok) return;

    // we ask the controller what message to show
    final message = _controller.buildSectionChangeMessage(
      _book,
      previousSection,
      selected,
    );
    // show snackbar if message is not null
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

    setState(() {});
  }

  void _openNotes() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            BookNotesPage(book: _book, initialPage: _book.pageProgress),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const primary = Color(0xFF5F3416);
    const background = Color(0xFFF5F0E8);
    const cardBackground = Color(0xFFF7EFE3);

    final progress = _book.pages > 0
        ? (_book.pageProgress / _book.pages).clamp(0.0, 1.0)
        : 0.0;

    return Scaffold(
      appBar: AppBar(title: const Text('Book info')),
      body: Container(
        color: background,
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.asset(
                        _book.coverAsset,
                        width: 120,
                        height: 180,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          width: 120,
                          height: 180,
                          color: Colors.grey[300],
                          child: const Icon(Icons.book),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _book.title,
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: primary,
                                ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _book.author,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 16),
                          _infoRow('Genre', _book.genre),
                          _infoRow('Publisher :', _book.publisher),
                          _infoRow('Pages :', '${_book.pages}'),
                          _infoRow(
                            'Published :',
                            _formatDate(_book.datePublished),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: cardBackground,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Reading summary :',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: primary,
                            ),
                      ),

                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Text(
                            'Status :',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: primary,
                                ),
                          ),
                          const SizedBox(width: 12),
                          InkWell(
                            borderRadius: BorderRadius.circular(22),
                            onTap: _changeStatus,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: _statusColor(_book.section),
                                borderRadius: BorderRadius.circular(22),
                              ),
                              child: Text(
                                _statusLabel(_book.section),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Tap to change',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: primary.withOpacity(0.7)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Text(
                            'Rating :',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: primary,
                                ),
                          ),
                          const SizedBox(width: 12),
                          ...List.generate(5, (index) {
                            final starIndex = index + 1;
                            final filled = starIndex <= _book.rating;
                            return GestureDetector(
                              onTap: () => _onStarTapped(starIndex),
                              child: Icon(
                                filled ? Icons.star : Icons.star_border,
                                size: 24,
                                color: Colors.amber[600],
                              ),
                            );
                          }),
                          const SizedBox(width: 8),
                          Text(
                            _book.rating == 0
                                ? 'No rating'
                                : '${_book.rating}/5',
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // button to toggle rating history(only if completedReadings > 1)
                      if (_book.completedReadings > 1)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            onPressed: () {
                              setState(() {
                                _showHistory = !_showHistory;
                              });
                            },
                            icon: Icon(
                              _showHistory
                                  ? Icons.expand_less
                                  : Icons.expand_more,
                              size: 18,
                            ),
                            label: Text(
                              _showHistory
                                  ? 'Hide rating history'
                                  : 'Show rating history',
                            ),
                          ),
                        ),

                      // the box with the history appears only when the toggle is true
                      if (_showHistory) ...[
                        const SizedBox(height: 8),
                        _buildRatingHistorySection(primary),
                      ],

                      const SizedBox(height: 16),

                      Row(
                        children: [
                          Text(
                            'Progress :',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: primary,
                                ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            '${_book.pageProgress} / ${_book.pages} pages',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),

                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 6,
                          backgroundColor: Colors.white24,
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            Color(0xFF8BC34A),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: _openNotes,
                          icon: const Icon(
                            Icons.sticky_note_2_outlined,
                            size: 18,
                          ),
                          label: const Text('Notes'),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Description :',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: primary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _book.description,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  //nick

  Widget _buildRatingHistorySection(Color primary) {
    final hasPastRatings = _book.ratingHistory.isNotEmpty;
    final hasCurrentRating = _book.rating > 0;
    final hasCompletionDate = _book.lastProgressUpdated != null;

    // If no history to show, return empty
    if (!hasPastRatings && !hasCurrentRating && !hasCompletionDate) {
      return const SizedBox.shrink();
    }

    final tiles = <Widget>[];

    // 1) Past ratings (those added to history via startReread)
    for (var i = 0; i < _book.ratingHistory.length; i++) {
      final rating = _book.ratingHistory[i];
      String dateText = '';
      if (i < _book.ratingHistoryDates.length) {
        dateText = _formatDate(_book.ratingHistoryDates[i]);
      }

      // If rating == 0, show as "No rating" (thats for the history )
      final ratingText = rating == 0 ? 'No rating' : '$rating/5';

      tiles.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            children: [
              Expanded(
                flex: 2,
                child: Text(
                  'Reading ${i + 1}:',
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
              ),
              Expanded(
                flex: 3,
                child: Text(
                  dateText.isEmpty ? ratingText : '$ratingText  •  $dateText',
                ),
              ),
            ],
          ),
        ),
      );
    }

    //   Current reading 
    final shouldShowCurrent =
        hasCurrentRating ||
        (_book.section == Status.finished && hasCompletionDate);

    if (shouldShowCurrent) {
      final readingIndex = _book.ratingHistory.length + 1;
      final label = _book.section == Status.finished
          ? 'Reading $readingIndex (current):'
          : 'Current reading:';

      String dateText = '';
      if (_book.lastProgressUpdated != null) {
        dateText = _formatDate(_book.lastProgressUpdated!.toIso8601String());
      }

      String value;
      if (_book.rating > 0) {
        value = dateText.isEmpty
            ? '${_book.rating}/5'
            : '${_book.rating}/5  •  $dateText';
      } else {
        value = dateText.isEmpty ? 'No rating' : 'No rating  •  $dateText';
      }

      tiles.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            children: [
              Expanded(
                flex: 2,
                child: Text(
                  label,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
              ),
              Expanded(flex: 3, child: Text(value)),
            ],
          ),
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF1E4D4),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.history, size: 18),
              const SizedBox(width: 8),
              Text(
                'Reading & rating history',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...tiles,
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(flex: 3, child: Text(value)),
        ],
      ),
    );
  }
}
