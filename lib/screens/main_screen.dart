// ignore_for_file: unused_import

import 'package:flutter/material.dart';
import 'home_screen.dart';
import 'categories_screen.dart';
import 'search_screen.dart';
import 'orders_screen.dart';
import 'profile_screen.dart';
import '../providers/cart_provider.dart';
// import 'notification_test_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with TickerProviderStateMixin {
  int _selectedIndex = 0;
  
  // Initialize with empty list
  final List<AnimationController> _animationControllers = [];
  
  // Flag to track initialization
  bool _isInitialized = false;
  
  final List<Widget> _screens = [
    const HomeScreen(),
    const CategoriesScreen(),
    const SearchScreen(),
    const OrdersScreen(),
    const ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    
    // Use a post-frame callback to ensure the widget is fully built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeAnimations();
    });
  }
  
  void _initializeAnimations() {
    // Clear any existing controllers
    for (var controller in _animationControllers) {
      controller.dispose();
    }
    _animationControllers.clear();
    
    // Add new controllers
    for (int i = 0; i < 5; i++) {
      _animationControllers.add(
        AnimationController(
          duration: const Duration(milliseconds: 400),
          vsync: this,
        ),
      );
    }
    
    // Start the animation for the initially selected tab
    if (_animationControllers.isNotEmpty) {
      _animationControllers[_selectedIndex].forward();
    }
    
    setState(() {
      _isInitialized = true;
    });
  }

  @override
  void dispose() {
    // Dispose all animation controllers
    for (var controller in _animationControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _onItemTapped(int index) {
    if (index == _selectedIndex || !_isInitialized) return;
    
    setState(() {
      // Reset the previous animation
      if (_animationControllers.isNotEmpty) {
        _animationControllers[_selectedIndex].reverse();
      }
      
      _selectedIndex = index;
      
      // Start the new animation
      if (_animationControllers.isNotEmpty) {
        _animationControllers[_selectedIndex].forward();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_selectedIndex],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withAlpha(77),
              spreadRadius: 1,
              blurRadius: 10,
              offset: const Offset(0, -3),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(0, Icons.home_outlined, Icons.home, 'Home'),
                _buildNavItem(1, Icons.grid_view_outlined, Icons.grid_view, 'Categories'),
                _buildNavItem(2, Icons.search_outlined, Icons.search, 'Search'),
                _buildNavItem(3, Icons.shopping_bag_outlined, Icons.shopping_bag, 'Orders'),
                _buildNavItem(4, Icons.person_outline, Icons.person, 'Profile'),
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildNavItem(int index, IconData icon, IconData activeIcon, String label) {
    final isSelected = _selectedIndex == index;
    final primaryColor = Theme.of(context).primaryColor;
    
    // Create a simpler version if animations aren't ready
    if (!_isInitialized || _animationControllers.isEmpty) {
      return InkWell(
        onTap: () => _onItemTapped(index),
        customBorder: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isSelected ? activeIcon : icon,
                color: isSelected ? primaryColor : Colors.grey,
                size: 24,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  color: isSelected ? primaryColor : Colors.grey,
                ),
              ),
            ],
          ),
        ),
      );
    }
    
    // Use the animated version once initialized
    final animation = _animationControllers[index];
    
    return InkWell(
      onTap: () => _onItemTapped(index),
      customBorder: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? primaryColor.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedBuilder(
              animation: animation,
              builder: (context, child) {
                return Transform.translate(
                  offset: Offset(0, isSelected ? -4 * animation.value : 0),
                  child: Transform.scale(
                    scale: 1.0 + (isSelected ? 0.2 * animation.value : 0),
                    child: Icon(
                      isSelected ? activeIcon : icon,
                      color: isSelected ? primaryColor : Colors.grey,
                      size: 24,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 4),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                color: isSelected ? primaryColor : Colors.grey,
              ),
              child: Text(label),
            ),
          ],
        ),
      ),
    );
  }
}



