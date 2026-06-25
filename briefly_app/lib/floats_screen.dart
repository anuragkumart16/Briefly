import 'package:flutter/material.dart';

class FloatModel {
  final String id;
  String text;
  bool isActive;
  final DateTime createdAt;
  DateTime updatedAt;

  FloatModel({
    required this.id,
    required this.text,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });
}

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
  final List<FloatModel> _floats = [];
  String _sortBy = 'last_added'; // last_added, last_modified, a_z, z_a
  String _filterBy = 'all'; // all, active, inactive

  // Selection mode variables
  bool _isSelectionMode = false;
  final Set<String> _selectedIds = {};

  @override
  void initState() {
    super.initState();
    // Pre-populate with initial mock data
    final now = DateTime.now();
    final initialStrings = [
      'The string on table moves the world',
      'Silence is the loudest scream',
      'Every moment is a fresh beginning',
      'Act as if what you do makes a difference',
      'Knowledge is power, use it wisely',
      'Small steps lead to big journeys',
      'You are stronger than you think',
      'Believe in your infinite potential',
    ];

    for (var i = 0; i < initialStrings.length; i++) {
      _floats.add(
        FloatModel(
          id: i.toString(),
          text: initialStrings[i],
          isActive: i % 3 != 2, // Set some inactive for visual testing
          createdAt: now.subtract(Duration(hours: i * 2)),
          updatedAt: now.subtract(Duration(hours: i * 2, minutes: i * 5)),
        ),
      );
    }
  }

  List<FloatModel> _getFilteredAndSortedList() {
    var list = _floats;
    if (widget.searchQuery.isNotEmpty) {
      list = list
          .where((f) => f.text.toLowerCase().contains(widget.searchQuery.toLowerCase()))
          .toList();
    } else {
      list = List.from(list);
    }

    // Apply Filter
    if (_filterBy == 'active') {
      list = list.where((f) => f.isActive).toList();
    } else if (_filterBy == 'inactive') {
      list = list.where((f) => !f.isActive).toList();
    }

    // Apply Sort
    if (_sortBy == 'last_added') {
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    } else if (_sortBy == 'last_modified') {
      list.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    } else if (_sortBy == 'a_z') {
      list.sort((a, b) => a.text.toLowerCase().compareTo(b.text.toLowerCase()));
    } else if (_sortBy == 'z_a') {
      list.sort((a, b) => b.text.toLowerCase().compareTo(a.text.toLowerCase()));
    }

    return list;
  }

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
                      setState(() {
                        _floats.insert(
                          0,
                          FloatModel(
                            id: DateTime.now().millisecondsSinceEpoch.toString(),
                            text: text,
                            isActive: true,
                            createdAt: DateTime.now(),
                            updatedAt: DateTime.now(),
                          ),
                        );
                      });
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

  void _confirmDeleteFloat(FloatModel float, BuildContext sheetCtx) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          title: const Text('Delete Float', style: TextStyle(fontFamily: 'Open Sans', fontWeight: FontWeight.bold)),
          content: const Text('Are you sure you want to delete this float?', style: TextStyle(fontFamily: 'Open Sans')),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey, fontFamily: 'Open Sans')),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context); // close dialog
                Navigator.pop(sheetCtx); // close bottom sheet
                setState(() {
                  _floats.removeWhere((f) => f.id == float.id);
                });
              },
              child: const Text('Delete', style: TextStyle(color: Color(0xFFEA4335), fontFamily: 'Open Sans')),
            ),
          ],
        );
      },
    );
  }

  void _confirmDeleteSelected() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          title: const Text('Delete Selected', style: TextStyle(fontFamily: 'Open Sans', fontWeight: FontWeight.bold)),
          content: Text('Are you sure you want to delete the ${_selectedIds.length} selected floats?', style: const TextStyle(fontFamily: 'Open Sans')),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey, fontFamily: 'Open Sans')),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context); // close dialog
                setState(() {
                  _floats.removeWhere((f) => _selectedIds.contains(f.id));
                  _selectedIds.clear();
                  _isSelectionMode = false;
                });
              },
              child: const Text('Delete', style: TextStyle(color: Color(0xFFEA4335), fontFamily: 'Open Sans')),
            ),
          ],
        );
      },
    );
  }

  void _markSelectedInactive() {
    setState(() {
      for (var f in _floats) {
        if (_selectedIds.contains(f.id)) {
          f.isActive = false;
          f.updatedAt = DateTime.now();
        }
      }
      _selectedIds.clear();
      _isSelectionMode = false;
    });
  }

  void _showFloatDetailsSheet(FloatModel float) {
    final TextEditingController editController = TextEditingController(text: float.text);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
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
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Float Details',
                      style: TextStyle(
                        fontFamily: 'Open Sans',
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFFF5B24),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Color(0xFFEA4335), size: 28),
                      onPressed: () => _confirmDeleteFloat(float, ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                
                // Header with boundary outlined edit text box
                const Text(
                  'Float Text',
                  style: TextStyle(
                    fontFamily: 'Open Sans',
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF888888),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: editController,
                  maxLines: 4,
                  onChanged: (text) {
                    setState(() {
                      float.text = text.trim();
                      float.updatedAt = DateTime.now();
                    });
                  },
                  style: const TextStyle(
                    fontFamily: 'Open Sans',
                    fontSize: 16,
                    color: Color(0xFF222222),
                  ),
                  decoration: InputDecoration(
                    hintText: 'Type wisdom here...',
                    filled: true,
                    fillColor: const Color(0xFFF7F7F7),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Color(0xFFE5E7EB), width: 1),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Color(0xFFFF5B24), width: 1),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Color(0xFFE5E7EB), width: 1),
                    ),
                    contentPadding: const EdgeInsets.all(16),
                  ),
                ),
                const SizedBox(height: 16),
                
                // Active Toggle (Switch widget)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Active',
                      style: TextStyle(
                        fontFamily: 'Open Sans',
                        fontSize: 16,
                        color: Color(0xFF222222),
                      ),
                    ),
                    Switch(
                      value: float.isActive,
                      onChanged: (val) {
                        setSheetState(() {
                          float.isActive = val;
                          float.updatedAt = DateTime.now();
                        });
                        setState(() {}); // refresh list view items opacity
                      },
                      activeThumbColor: Colors.white,
                      activeTrackColor: const Color(0xFF2F6FF2),
                      inactiveThumbColor: Colors.white,
                      inactiveTrackColor: const Color(0xFFE0E0E0),
                    ),
                  ],
                ),
                const Divider(color: Color(0xFFEEEEEE), height: 16),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }


  String _sortByLabel(String val) {
    switch (val) {
      case 'last_added': return 'Last Added';
      case 'last_modified': return 'Last Modified';
      case 'a_z': return 'A -> Z';
      case 'z_a': return 'Z -> A';
      default: return '';
    }
  }

  String _filterByLabel(String val) {
    switch (val) {
      case 'all': return 'All';
      case 'active': return 'All Active';
      case 'inactive': return 'All Inactive';
      default: return '';
    }
  }

  Widget _buildSortFilterHeader() {
    if (_isSelectionMode) {
      return Container(
        color: Colors.white,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Selected: ${_selectedIds.length}',
              style: const TextStyle(
                fontFamily: 'Open Sans',
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Color(0xFF222222),
              ),
            ),
            Row(
              children: [
                if (_selectedIds.isNotEmpty) ...[
                  GestureDetector(
                    onTap: _markSelectedInactive,
                    behavior: HitTestBehavior.opaque,
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                      child: Text(
                        'Mark Inactive',
                        style: TextStyle(
                          fontFamily: 'Open Sans',
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2F6FF2),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: _confirmDeleteSelected,
                    behavior: HitTestBehavior.opaque,
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                      child: Text(
                        'Delete',
                        style: TextStyle(
                          fontFamily: 'Open Sans',
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFEA4335),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _isSelectionMode = false;
                      _selectedIds.clear();
                    });
                  },
                  child: const Icon(Icons.close_rounded, color: Color(0xFF888888), size: 22),
                ),
              ],
            ),
          ],
        ),
      );
    }

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 4), // Reduced spacing
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Sort Dropdown
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _sortBy,
              icon: const SizedBox.shrink(),
              style: const TextStyle(fontFamily: 'Open Sans', fontSize: 13, color: Color(0xFF222222)),
              onChanged: (val) {
                if (val != null) {
                  setState(() => _sortBy = val);
                }
              },
              selectedItemBuilder: (context) => [
                'last_added',
                'last_modified',
                'a_z',
                'z_a'
              ].map((val) => Row(
                children: [
                  const Text('Sorting : ', style: TextStyle(color: Color(0xFF222222), fontFamily: 'Open Sans', fontSize: 13, fontWeight: FontWeight.w600)),
                  Text(_sortByLabel(val), style: const TextStyle(color: Color(0xFF2F6FF2), fontFamily: 'Open Sans', fontSize: 13, fontWeight: FontWeight.w600)),
                ],
              )).toList(),
              items: const [
                DropdownMenuItem(value: 'last_added', child: Text('Last Added')),
                DropdownMenuItem(value: 'last_modified', child: Text('Last Modified')),
                DropdownMenuItem(value: 'a_z', child: Text('A -> Z')),
                DropdownMenuItem(value: 'z_a', child: Text('Z -> A')),
              ],
            ),
          ),
          
          // Filter Dropdown
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _filterBy,
              icon: const SizedBox.shrink(),
              style: const TextStyle(fontFamily: 'Open Sans', fontSize: 13, color: Color(0xFF222222)),
              onChanged: (val) {
                if (val != null) {
                  setState(() => _filterBy = val);
                }
              },
              selectedItemBuilder: (context) => [
                'all',
                'active',
                'inactive'
              ].map((val) => Row(
                children: [
                  const Text('Filter : ', style: TextStyle(color: Color(0xFF222222), fontFamily: 'Open Sans', fontSize: 13, fontWeight: FontWeight.w600)),
                  Text(_filterByLabel(val), style: const TextStyle(color: Color(0xFF2F6FF2), fontFamily: 'Open Sans', fontSize: 13, fontWeight: FontWeight.w600)),
                ],
              )).toList(),
              items: const [
                DropdownMenuItem(value: 'all', child: Text('All')),
                DropdownMenuItem(value: 'active', child: Text('All Active')),
                DropdownMenuItem(value: 'inactive', child: Text('All Inactive')),
              ],
            ),
          ),

          // Selection Icon (Checklist icon as requested)
          GestureDetector(
            onTap: () {
              setState(() {
                _isSelectionMode = true;
                _selectedIds.clear();
              });
            },
            child: const Icon(Icons.checklist_rounded, color: Color(0xFFFF5B24), size: 24),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.layers_outlined, size: 64, color: Color(0xFFFFB39A)),
          const SizedBox(height: 16),
          const Text(
            'No floats found.',
            style: TextStyle(
              fontFamily: 'Open Sans',
              fontSize: 16,
              color: Color(0xFF888888),
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Try changing your filter or add a float.',
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

  @override
  Widget build(BuildContext context) {
    final list = _getFilteredAndSortedList();

    return Column(
      children: [
        _buildSortFilterHeader(),
        Expanded(
          child: list.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                  itemCount: list.length,
                  itemBuilder: (context, index) {
                    final float = list[index];
                    final isSelected = _selectedIds.contains(float.id);
                    return _FloatTile(
                      float: float,
                      isSelectionMode: _isSelectionMode,
                      isSelected: isSelected,
                      onSelectChanged: (val) {
                        setState(() {
                          if (val == true) {
                            _selectedIds.add(float.id);
                          } else {
                            _selectedIds.remove(float.id);
                          }
                        });
                      },
                      onTap: () {
                        if (_isSelectionMode) {
                          setState(() {
                            if (isSelected) {
                              _selectedIds.remove(float.id);
                            } else {
                              _selectedIds.add(float.id);
                            }
                          });
                        } else {
                          _showFloatDetailsSheet(float);
                        }
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _FloatTile extends StatelessWidget {
  final FloatModel float;
  final VoidCallback onTap;
  final bool isSelectionMode;
  final bool isSelected;
  final ValueChanged<bool?>? onSelectChanged;

  const _FloatTile({
    required this.float,
    required this.onTap,
    this.isSelectionMode = false,
    this.isSelected = false,
    this.onSelectChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: float.isActive ? 1.0 : 0.6,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F7FA),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
              child: Row(
                children: [
                  if (isSelectionMode) ...[
                    Checkbox(
                      value: isSelected,
                      activeColor: const Color(0xFFFF5B24),
                      onChanged: onSelectChanged,
                    ),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: Text(
                      float.text,
                      style: const TextStyle(
                        fontFamily: 'Open Sans',
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF606060),
                      ),
                    ),
                  ),
                  if (!isSelectionMode)
                    const Icon(Icons.chevron_right_rounded, color: Color(0xFFFF5B24), size: 22),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
