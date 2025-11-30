// lib/views/book_notes_page.dart
//
// Screen where the user can attach notes to a single book.
// Notes are stored on the Book model (book.notes) and persisted using
// PagerController / Books (user_library.json).

import 'package:flutter/material.dart';

import '../controller/pager_controller.dart';
import '../model/book.dart';

/// Screen used to view and add notes for a given [Book].
///
/// Notes are kept in [book.notes]. This widget edits that list in memory
/// and asks [PagerController] to persist the book state when it changes.
class BookNotesPage extends StatefulWidget {
  final Book book;

  /// Initial page pre-filled in the "Page" field when opening the screen.
  final int initialPage;

  const BookNotesPage({
    super.key,
    required this.book,
    required this.initialPage,
  });

  @override
  State<BookNotesPage> createState() => _BookNotesPageState();
}

class _BookNotesPageState extends State<BookNotesPage> {
  final PagerController _controller = PagerController.instance;

  final TextEditingController pageController = TextEditingController();
  final TextEditingController noteController = TextEditingController();

  /// Local reference to the notes list of this book.
  ///
  /// We keep a direct reference to [widget.book.notes] so any changes here
  /// are immediately reflected on the book model.
  late List<BookNote> _notes;

  @override
  void initState() {
    super.initState();

    // Use the current reading page as a default, clamped to valid range.
    final page = widget.initialPage.clamp(1, widget.book.pages);
    pageController.text = page.toString();

    // Attach to the book's notes list.
    _notes = widget.book.notes;
  }

  @override
  void dispose() {
    pageController.dispose();
    noteController.dispose();
    super.dispose();
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  /// Persist the whole book (including notes).
  Future<void> _persistNotes() async {
    final ok = await _controller.saveBook(widget.book);
    if (!ok && mounted) {
      _showSnack('Could not save notes.');
    }
  }

  /// Validate input and add a new note to the book, then persist.
  Future<void> _addNote() async {
    final rawPage = pageController.text.trim();
    final text = noteController.text.trim();

    if (rawPage.isEmpty) {
      _showSnack('Please enter a page number.');
      return;
    }

    if (text.isEmpty) {
      _showSnack('Please write a note.');
      return;
    }

    final parsedPage = int.tryParse(rawPage);
    if (parsedPage == null) {
      _showSnack('Page must be a number.');
      return;
    }

    if (parsedPage < 1 || parsedPage > widget.book.pages) {
      _showSnack('Page must be between 1 and ${widget.book.pages}.');
      return;
    }

    final newNote = BookNote(
      page: parsedPage,
      text: text,
      createdAt: DateTime.now(),
    );

    setState(() {
      // Insert at the top so the newest note appears first.
      _notes.insert(0, newNote);
      noteController.clear();
    });

    await _persistNotes();
  }

  Future<void> _deleteNote(BookNote note) async {
    setState(() {
      _notes.remove(note);
    });

    await _persistNotes();
  }

  void _openNote(BookNote note) {
    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFFF7EFE3),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: Text('Page ${note.page}'),
          content: SingleChildScrollView(child: Text(note.text)),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'Close',
                style: TextStyle(color: Color(0xFF6B3A19)),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    const background = Color(0xFFF5F0E8);
    const headerBrown = Color(0xFF6B3A19);
    const formBackground = Color(0xFFF7EFE3);

    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        backgroundColor: headerBrown,
        foregroundColor: Colors.white,
        title: Text(widget.book.title),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Add a note',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: headerBrown,
                ),
              ),
              const SizedBox(height: 12),

              // Form card.
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: formBackground,
                  borderRadius: BorderRadius.circular(22),
                ),
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Page field.
                    TextField(
                      controller: pageController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Page',
                        border: UnderlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '1 – ${widget.book.pages} (defaults to current page)',
                      style: TextStyle(
                        // ignore: deprecated_member_use
                        color: headerBrown.withOpacity(0.7),
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Note field.
                    TextField(
                      controller: noteController,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        labelText: 'Note',
                        border: UnderlineInputBorder(),
                      ),
                    ),

                    const SizedBox(height: 20),

                    Align(
                      alignment: Alignment.centerRight,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: headerBrown,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 28,
                            vertical: 10,
                          ),
                        ),
                        onPressed: _addNote,
                        child: const Text('Save'),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Existing notes list.
              Text(
                'Notes',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: headerBrown,
                ),
              ),
              const SizedBox(height: 8),

              if (_notes.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 8.0),
                  child: Text('No notes yet.'),
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _notes.length,
                  itemBuilder: (context, index) {
                    final note = _notes[index];

                    // Simple dd MMM yyyy formatting (e.g. 18 Oct 1851).
                    final created = note.createdAt;
                    final dateLabel =
                        '${created.day.toString().padLeft(2, '0')} '
                        '${_monthName(created.month)} '
                        '${created.year}';

                    return Card(
                      margin: const EdgeInsets.only(top: 10),
                      color: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: ListTile(
                        onTap: () => _openNote(note),
                        leading: const Icon(Icons.sticky_note_2_outlined),
                        title: Text('Page ${note.page}'),
                        subtitle: Text(
                          note.text,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              dateLabel,
                              style: const TextStyle(fontSize: 12),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(
                                Icons.delete_outline,
                                color: Colors.redAccent,
                              ),
                              onPressed: () => _deleteNote(note),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Returns month short name in English (Jan, Feb, …).
  String _monthName(int month) {
    const names = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return names[month - 1];
  }
}
