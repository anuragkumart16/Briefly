import 'package:flutter/material.dart';

/// Pure body widget for the Floats tab.
/// No Scaffold, no AppBar, no BottomNav — all owned by MainShell.
class FloatsBody extends StatefulWidget {
  final TextEditingController searchController;
  final String searchQuery;
  final ValueChanged<String> onSearchChanged;

  const FloatsBody({
    super.key,
    required this.searchController,
    required this.searchQuery,
    required this.onSearchChanged,
  });

  @override
  State<FloatsBody> createState() => FloatsBodyState();
}

class FloatsBodyState extends State<FloatsBody> {
  final List<String> _floats = [
    'The string on table moves the world',
    'Silence is the loudest scream',
    'Every moment is a fresh beginning',
    'Act as if what you do makes a difference',
    'Knowledge is power, use it wisely',
    'Small steps lead to big journeys',
    'You are stronger than you think',
    'Believe in your infinite potential',
  ];

  List<String> get _filtered => widget.searchQuery.isEmpty
      ? _floats
      : _floats
          .where((f) => f.toLowerCase().contains(widget.searchQuery.toLowerCase()))
          .toList();

  void showAddFloatSheet() {
    final TextEditingController controller = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEEEEEE),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Add a Float',
                style: TextStyle(
                  fontFamily: 'Open Sans',
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFFF5B24),
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'A wisdom you want to be reminded of',
                style: TextStyle(
                  fontFamily: 'Open Sans',
                  fontSize: 13,
                  color: Color(0xFF888888),
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: controller,
                autofocus: true,
                maxLines: 3,
                style: const TextStyle(
                    fontFamily: 'Open Sans', fontSize: 15, color: Color(0xFF222222)),
                decoration: InputDecoration(
                  hintText: 'Type your float here...',
                  hintStyle:
                      const TextStyle(fontFamily: 'Open Sans', color: Color(0xFFBBBBBB)),
                  filled: true,
                  fillColor: const Color(0xFFF7F7F7),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.all(16),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    final text = controller.text.trim();
                    if (text.isNotEmpty) {
                      setState(() => _floats.insert(0, text));
                    }
                    Navigator.pop(ctx);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF5B24),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text(
                    'Save Float',
                    style: TextStyle(
                      fontFamily: 'Open Sans',
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.layers_outlined, size: 64, color: const Color(0xFFFFB39A)),
            const SizedBox(height: 16),
            const Text(
              'No floats yet.',
              style: TextStyle(
                fontFamily: 'Open Sans',
                fontSize: 16,
                color: Color(0xFF888888),
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Tap + to add your first wisdom.',
              style: TextStyle(
                fontFamily: 'Open Sans',
                fontSize: 13,
                color: Color(0xFFBBBBBB),
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      itemCount: _filtered.length,
      itemBuilder: (context, index) {
        return _FloatTile(
          text: _filtered[index],
          onDelete: () {
            setState(() => _floats.remove(_filtered[index]));
          },
        );
      },
    );
  }
}

class _FloatTile extends StatelessWidget {
  final String text;
  final VoidCallback onDelete;

  const _FloatTile({required this.text, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFF5B24),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () {},
          onLongPress: onDelete,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    text,
                    style: const TextStyle(
                      fontFamily: 'Open Sans',
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, color: Colors.white, size: 22),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
