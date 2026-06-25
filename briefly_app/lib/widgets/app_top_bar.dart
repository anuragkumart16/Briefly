import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Shared top app bar used across all screens.
///
/// Modes:
/// - Title mode (default): shows app/screen title as text on the left.
/// - Search mode: shows a search TextField in the center (pass [searchController] & [onSearchChanged]).
///
/// Always shows the account icon on the right.
/// Pass [onMenuTap] to handle the hamburger menu press.
/// Pass [trailingWidget] to inject extra content before the account icon (e.g. saved-time text).
class AppTopBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final VoidCallback? onMenuTap;
  final VoidCallback? onAccountTap;

  /// If provided, the title area becomes a search field instead.
  final TextEditingController? searchController;
  final ValueChanged<String>? onSearchChanged;

  /// Optional extra widget shown before the account icon (e.g. saved time).
  final Widget? trailingWidget;

  /// Whether to show a back button instead of menu.
  final bool showBackButton;

  /// Optional user initials to show in the account avatar.
  final String? userInitials;

  const AppTopBar({
    super.key,
    required this.title,
    this.onMenuTap,
    this.onAccountTap,
    this.searchController,
    this.onSearchChanged,
    this.trailingWidget,
    this.showBackButton = false,
    this.userInitials,
  });

  bool get _isSearchMode => searchController != null;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      systemOverlayStyle: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
        systemNavigationBarColor: Colors.white,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
      leading: showBackButton
          ? IconButton(
              icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFFFF5B24)),
              onPressed: () => Navigator.of(context).pop(),
            )
          : IconButton(
              icon: const Icon(Icons.menu, color: Color(0xFFFF5B24)),
              onPressed: onMenuTap,
            ),
      title: _isSearchMode
          ? Container(
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFFF2F2F2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: TextField(
                controller: searchController,
                onChanged: onSearchChanged,
                textAlignVertical: TextAlignVertical.center,
                style: const TextStyle(
                  fontFamily: 'Open Sans',
                  fontSize: 14,
                  color: Color(0xFF222222),
                ),
                decoration: const InputDecoration(
                  hintText: 'Search',
                  hintStyle: TextStyle(
                    fontFamily: 'Open Sans',
                    fontSize: 14,
                    color: Color(0xFFAAAAAA),
                  ),
                  prefixIcon: Icon(Icons.search, color: Color(0xFFAAAAAA), size: 20),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.only(right: 12),
                  isDense: true,
                ),
              ),
            )
          : Text(
              title,
              style: const TextStyle(
                fontFamily: 'Arya',
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Color(0xFFFF5B24),
              ),
            ),
      actions: [
        if (trailingWidget != null)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Center(child: trailingWidget),
          ),
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: GestureDetector(
            onTap: onAccountTap,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFF8A65), Color(0xFFFF5B24)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    border: Border.all(color: Colors.white, width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFF5B24).withValues(alpha: 0.25),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      userInitials ?? 'A',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Open Sans',
                      ),
                    ),
                  ),
                ),
                Positioned(
                  right: -1,
                  bottom: -1,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: const Color(0xFF4CAF50), // Active sync green
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
