import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_carousel_widget/flutter_carousel_widget.dart';
import '../widgets/product_card.dart';
import '../providers/product_provider.dart';
// Remove: import '../providers/wishlist_provider.dart';
import '../widgets/main_app_bar.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    // Use addPostFrameCallback to schedule the fetch after the build is complete
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchData();
    });
  }

  Future<void> _fetchData() async {
    await Provider.of<ProductProvider>(context, listen: false).fetchProducts();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const MainAppBar(title: 'ecommerce'),
      body: Consumer<ProductProvider>(
        builder: (ctx, productData, child) {
          if (productData.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (productData.error != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(productData.error!),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _fetchData,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          final products = productData.products;
          final deals = productData.deals;

          return ListView(
            padding: const EdgeInsets.only(top: 16),
            children: [
              // Deals of the Day Section
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Row(
                  children: [
                    Icon(
                      Icons.local_fire_department,
                      color: Theme.of(context).primaryColor,
                      size: 24,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Deals of the Day',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).primaryColor,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Deals Carousel or Empty State
              deals.isEmpty 
                ? Container(
                    height: 180,
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.local_offer_outlined,
                            size: 48,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No deals available today',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : FlutterCarousel(
                    items: deals.map((deal) => Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0),
                      child: ProductCard(
                        product: deal.product,
                        discountPercentage: deal.discountPercentage,
                        discountPrice: deal.discountPrice,
                        showDiscountBadge: true,
                        isFullWidth: true,
                        deal: deal,
                      ),
                    )).toList(),
                    options: CarouselOptions(
                      height: 180,
                      viewportFraction: 0.92,
                      enlargeCenterPage: true,
                      autoPlay: true,
                      autoPlayInterval: const Duration(seconds: 5),
                      autoPlayAnimationDuration: const Duration(milliseconds: 1500),
                      enableInfiniteScroll: deals.length > 1,
                      showIndicator: true,
                      slideIndicator: CircularWaveSlideIndicator(),
                    ),
                  ),
              const SizedBox(height: 24),

              // All Products Section
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.0),
                child: Text(
                  'All Products',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Products Grid or Empty State
              products.isEmpty
                ? Container(
                    height: 200,
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.inventory_2_outlined,
                            size: 48,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No products available',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        childAspectRatio: 0.68,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                      ),
                      itemCount: products.length,
                      itemBuilder: (ctx, i) => ProductCard(
                        product: products[i],
                        showDiscountBadge: true,
                      ),
                    ),
                  ),
              const SizedBox(height: 24),
            ],
          );
        },
      ),
    );
  }
}









