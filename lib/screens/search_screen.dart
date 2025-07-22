import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../widgets/main_app_bar.dart';
import '../providers/product_provider.dart';
import '../widgets/product_card.dart';
import '../models/product.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _searchController = TextEditingController();
  String _sortOption = ''; // Empty means no sorting, 'asc' for low to high, 'desc' for high to low
  String _searchQuery = '';
  
  @override
  void initState() {
    super.initState();
    // Load all products when screen initializes
    Future.microtask(() {
      final provider = Provider.of<ProductProvider>(context, listen: false);
      if (provider.products.isEmpty) {
        provider.fetchProducts();
      }
    });
  }

  void _filterProducts(String query) {
    setState(() {
      _searchQuery = query.trim();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final productProvider = Provider.of<ProductProvider>(context);
    final allProducts = productProvider.products;
    final isLoading = productProvider.isLoading;
    final hasError = productProvider.error != null;

    // Filter products based on search query - character by character
    final filteredProducts = _searchQuery.isEmpty 
        ? allProducts 
        : allProducts.where((product) {
            final title = product.title.toLowerCase();
            final query = _searchQuery.toLowerCase();
            
            // Only check if product title contains the search query
            return title.contains(query);
          }).toList();

    // Apply price sorting if selected
    if (_sortOption.isNotEmpty && filteredProducts.isNotEmpty) {
      filteredProducts.sort((a, b) {
        final priceA = a.isOnSale && a.salePrice != null ? a.salePrice! : a.price;
        final priceB = b.isOnSale && b.salePrice != null ? b.salePrice! : b.price;
        return _sortOption == 'asc' 
            ? priceA.compareTo(priceB)  // Low to High
            : priceB.compareTo(priceA); // High to Low
      });
    }

    return Scaffold(
      appBar: MainAppBar(
        title: 'Search Products',
        additionalActions: [], // Remove the filter button
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search products...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty 
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        _filterProducts('');
                      },
                    )
                  : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.grey[200],
              ),
              onChanged: _filterProducts,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                FilterChip(
                  label: const Text('Price: Low to High'),
                  onSelected: (selected) {
                    setState(() {
                      _sortOption = selected ? 'asc' : '';
                    });
                  },
                  selected: _sortOption == 'asc',
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('Price: High to Low'),
                  onSelected: (selected) {
                    setState(() {
                      _sortOption = selected ? 'desc' : '';
                    });
                  },
                  selected: _sortOption == 'desc',
                ),
              ],
            ),
          ),
          Expanded(
            child: _buildProductGrid(isLoading, filteredProducts, hasError),
          ),
        ],
      ),
    );
  }

  Widget _buildProductGrid(bool isLoading, List<Product> products, bool hasError) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (hasError) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red[400]),
            const SizedBox(height: 16),
            Text(
              'Error: ${Provider.of<ProductProvider>(context).error}',
              style: TextStyle(color: Colors.red[600]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                Provider.of<ProductProvider>(context, listen: false).fetchProducts();
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    // This is the key part - if search query exists but no products match
    if (_searchQuery.isNotEmpty && products.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No products found for "$_searchQuery"',
              style: TextStyle(color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    if (products.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inventory_2_outlined, size: 80, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No products available',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.68, // Match the home screen's aspect ratio
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: products.length,
      itemBuilder: (ctx, i) => ProductCard(
        product: products[i],
        showDiscountBadge: products[i].isOnSale,
        discountPercentage: products[i].discountPercentage,
        discountPrice: products[i].salePrice,
        // Don't set isFullWidth to true as we want the regular card style
      ),
    );
  }
}











