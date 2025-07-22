import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/category_provider.dart';
import '../widgets/main_app_bar.dart';
import './category_products_screen.dart';
import '../models/product.dart';

class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({super.key});

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(Duration.zero, () {
      Provider.of<CategoryProvider>(context, listen: false).fetchCategories();
    });
  }

 IconData _getIconData(String categoryName) {
  // Define the icon map here
  final iconMap = {
    'electronics': Icons.devices,
    'store': Icons.store,
    'home': Icons.home,
    'beauty': Icons.face,
    'sports': Icons.sports_basketball,
    'books': Icons.book,
    'automotive': Icons.directions_car,
    'miscellaneous': Icons.category,
    'food': Icons.restaurant_menu,
    'computers': Icons.laptop,
    'phones': Icons.smartphone,
    'cameras': Icons.camera_alt,
    'audio': Icons.headphones,
    'watches': Icons.watch,
    'gifts': Icons.card_giftcard,
    'bags': Icons.shopping_bag,
    'fashion': Icons.checkroom,
    'cosmetics': Icons.brush,
    'toys': Icons.toys,
    'grocery': Icons.local_grocery_store,
    'furniture': Icons.weekend,
    'pets': Icons.pets,
    'health': Icons.health_and_safety,
    'baby': Icons.child_friendly,
    'music': Icons.music_note,
    'jewelry': Icons.diamond,
    'games': Icons.sports_esports,
    'tools': Icons.build,
    'garden': Icons.grass,
    'office': Icons.work,
    'travel': Icons.card_travel,
    'lighting': Icons.lightbulb,
    'kitchen': Icons.kitchen,
    'appliances': Icons.electrical_services,
    'cleaning': Icons.cleaning_services,
    'pharmacy': Icons.local_pharmacy,
    'shoes': Icons.hiking,
    'outdoor': Icons.park,
    'art': Icons.palette,
    'security': Icons.security,
    'bathroom': Icons.bathtub,
    'video': Icons.videocam,
    'fitness': Icons.fitness_center,
    'clothing': Icons.shopping_bag_outlined,
  };

  // Convert to lowercase and remove spaces for matching
  String normalizedName = categoryName.toLowerCase().replaceAll(' ', '');
  
  // Try exact match first
  if (iconMap.containsKey(normalizedName)) {
    return iconMap[normalizedName]!;
  }
  
  // Try partial match
  for (var entry in iconMap.entries) {
    if (normalizedName.contains(entry.key) || entry.key.contains(normalizedName)) {
      return entry.value;
    }
  }
  
  // Default icon
  return Icons.category;
}


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const MainAppBar(title: 'Categories'),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Consumer<CategoryProvider>(
                builder: (context, categoryProvider, child) {
                  if (categoryProvider.isLoading) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (categoryProvider.error != null) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.error_outline,
                            size: 64,
                            color: Colors.red[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Error: ${categoryProvider.error}',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.red[600],
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: () {
                              Provider.of<CategoryProvider>(context, listen: false)
                                  .fetchCategories();
                            },
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    );
                  }

                  if (categoryProvider.categories.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.category_outlined,
                            size: 64,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No categories found',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return GridView.builder(
                    padding: const EdgeInsets.all(16),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 1.1,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                    ),
                    itemCount: categoryProvider.categories.length,
                    itemBuilder: (context, index) {
                      final category = categoryProvider.categories[index];
                      return Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          color: Colors.white,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.08),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                              spreadRadius: 0,
                            ),
                            BoxShadow(
                              color: Colors.black.withOpacity(0.04),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                              spreadRadius: 0,
                            ),
                          ],
                        ),
                        child: InkWell(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => CategoryProductsScreen(
                                  category: CategoryInfo(  // Convert to CategoryInfo
                                    id: category.id,
                                    name: category.name,
                                    icon: category.icon,
                                  ),
                                ),
                              ),
                            );
                          },
                          borderRadius: BorderRadius.circular(16),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                _getIconData(category.icon),  // Handle null icon
                                size: 48,
                                color: Theme.of(context).primaryColor,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                category.name,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
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
    );
  }
}




