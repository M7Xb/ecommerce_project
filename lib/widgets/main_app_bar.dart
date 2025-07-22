import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/cart_provider.dart';
import '../providers/wishlist_provider.dart';
import '../providers/auth_provider.dart';
import '../screens/cart_screen.dart';
import '../screens/wishlist_screen.dart';

class MainAppBar extends StatefulWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? additionalActions;

  const MainAppBar({
    Key? key,
    required this.title,
    this.additionalActions,
  }) : super(key: key);

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  State<MainAppBar> createState() => _MainAppBarState();
}

class _MainAppBarState extends State<MainAppBar> {
  @override
  void initState() {
    super.initState();
    // Schedule the fetch to happen after the current build is complete
    Future.microtask(() {
      if (mounted) {
        Provider.of<WishlistProvider>(context, listen: false).fetchWishlist();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: Text(widget.title),
      actions: [
        // Add wishlist button with badge
        Consumer<WishlistProvider>(
          builder: (context, wishlist, child) => Stack(
            clipBehavior: Clip.none,
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 8.0), // Added right padding
                child: IconButton(
                  icon: const Icon(Icons.favorite_border),
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const WishlistScreen(),
                      ),
                    ).then((_) {
                      // Refresh wishlist count when returning from wishlist screen
                      Provider.of<WishlistProvider>(context, listen: false).fetchWishlist();
                    });
                  },
                ),
              ),
              if (wishlist.itemCount > 0)
                Positioned(
                  right: 8, // Adjusted to account for the new padding
                  top: 0,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    child: Text(
                      '${wishlist.itemCount}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
        ),
        // Existing cart button
        Consumer<CartProvider>(
          builder: (context, cart, child) {
            // Get auth status
            final isLoggedIn = Provider.of<AuthProvider>(context).isAuthenticated;
            
            return Stack(
              clipBehavior: Clip.none,
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 16.0),
                  child: IconButton(
                    icon: const Icon(Icons.shopping_cart_outlined),
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => const CartScreen(),
                        ),
                      );
                    },
                  ),
                ),
                // Only show badge if user is logged in AND cart has items
                if (isLoggedIn && cart.itemCount > 0)
                  Positioned(
                    right: 16,
                    top: 0,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 16,
                        minHeight: 16,
                      ),
                      child: Text(
                        '${cart.itemCount}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
        if (widget.additionalActions != null) ...widget.additionalActions!,
      ],
    );
  }
}










