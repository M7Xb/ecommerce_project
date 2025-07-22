import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import 'dart:convert';
import '../models/product.dart';
import '../models/deal.dart';
import '../providers/cart_provider.dart';
import '../models/review_model.dart';
import '../widgets/review_card.dart';
import '../services/api_service.dart';
import '../screens/cart_screen.dart';
import '../providers/wishlist_provider.dart';
import '../providers/auth_provider.dart';
import '../screens/login_screen.dart';

class ProductDetailScreen extends StatefulWidget {
  final Product product;
  final Deal? deal;

  const ProductDetailScreen({
    Key? key,
    required this.product,
    this.deal,
  }) : super(key: key);

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  Timer? _timer;
  String _timeLeft = '';
  int _quantity = 1;
  List<ReviewModel> _reviews = [];
  bool _isLoadingReviews = true;
  int _currentStockQuantity = 0; // Set a default value of 0 instead of 10
  bool _isInWishlist = false;
  bool _checkingWishlist = true;
  int _selectedImageIndex = 0;
  List<String> _productImages = [];

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

  // Add a method to fetch the latest product data for a deal

  @override
  void initState() {
    super.initState();
    _selectedImageIndex = 0;
    _productImages = [];
    
    // Set the stock quantity directly from the product without defaulting to 10
    _currentStockQuantity = widget.product.stockQuantity;
    
    _fetchProductDetails();
    
    // Start the timer if this is a deal
    if (widget.deal != null) {
      _startTimer();
    }
    
    // Schedule these operations after the build is complete
    Future.microtask(() {
      if (mounted) {
        _checkWishlistStatus();
        _loadReviews();
      }
    });
  }

  Future<void> _fetchProductDetails() async {
    try {
      // Always start with the main product image
      setState(() {
        _productImages = [widget.product.imageUrl];
      });
      
      final response = await ApiService.get('/api/products/${widget.product.id}/details/');
      
      if (response.statusCode == 200) {
        final productData = json.decode(response.body);
        
        setState(() {
          // Add gallery images from the API
          if (productData['images'] != null && productData['images'].length > 0) {
            for (var image in productData['images']) {
              if (image['image_url'] != null) {
                _productImages.add(image['image_url']);
              }
            }
          }
        });
      }
    } catch (error) {
      print('Error fetching product details: $error');
      // Ensure we at least have the main product image
      if (_productImages.isEmpty) {
        setState(() {
          _productImages = [widget.product.imageUrl];
        });
      }
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _updateTimeLeft();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _updateTimeLeft();
    });
  }

  void _updateTimeLeft() {
    if (widget.deal == null) return;
    
    final now = DateTime.now();
    final end = widget.deal!.endDate;
    final difference = end.difference(now);

    if (difference.isNegative) {
      setState(() {
        _timeLeft = 'Expired';
      });
      _timer?.cancel();
      return;
    }

    final days = difference.inDays;
    final hours = difference.inHours % 24;
    final minutes = difference.inMinutes % 60;
    final seconds = difference.inSeconds % 60;

    setState(() {
      if (days > 0) {
        _timeLeft = '${days}d ${hours}h ${minutes}m';
      } else if (hours > 0) {
        _timeLeft = '${hours}h ${minutes}m ${seconds}s';
      } else {
        _timeLeft = '${minutes}m ${seconds}s';
      }
    });
  }

  Future<void> _loadReviews() async {
    setState(() {
      _isLoadingReviews = true;
    });
    
    try {
      final reviews = await ApiService.getProductReviews(widget.product.id);
      setState(() {
        _reviews = reviews;
        _isLoadingReviews = false;
      });
    } catch (e) {
      print('Error loading reviews: $e');
      setState(() {
        _isLoadingReviews = false;
      });
    }
  }

  // Add this method to calculate average rating
  double _calculateAverageRating() {
    if (_reviews.isEmpty) return 0;
    double sum = 0;
    for (var review in _reviews) {
      sum += review.rating;
    }
    return sum / _reviews.length;
  }

  // Add this method to build the rating stars
  Widget _buildRatingStars(double rating) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        if (index < rating.floor()) {
          return Icon(Icons.star, color: Colors.amber, size: 18);
        } else if (index == rating.floor() && rating % 1 > 0) {
          return Icon(Icons.star_half, color: Colors.amber, size: 18);
        } else {
          return Icon(Icons.star_border, color: Colors.amber, size: 18);
        }
      }),
    );
  }

  Widget _buildReviewsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Divider for visual separation
        Divider(color: Colors.grey.shade300, thickness: 1),
        const SizedBox(height: 16),
        
        // Reviews header with count
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Text(
                  'Customer Reviews',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor.withAlpha(25),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '(${_reviews.length})',
                    style: TextStyle(
                      color: Theme.of(context).primaryColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            ElevatedButton.icon(
              onPressed: () {
                _showAddReviewDialog();
              },
              icon: const Icon(Icons.rate_review, size: 18),
              label: const Text('Write a Review'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        
        // Average rating display
        if (_reviews.isNotEmpty) ...[
          Row(
            children: [
              _buildRatingStars(_calculateAverageRating()),
              const SizedBox(width: 8),
              Text(
                '${_calculateAverageRating().toStringAsFixed(1)} out of 5',
                style: TextStyle(
                  color: Colors.grey.shade700,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
        ],
        
        if (_isLoadingReviews)
          const Center(child: CircularProgressIndicator())
        else if (_reviews.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: const Center(
              child: Text(
                'No reviews yet. Be the first to review this product!',
                style: TextStyle(
                  color: Colors.grey,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _reviews.length,
            itemBuilder: (context, index) {
              return ReviewCard(
                review: _reviews[index],
                onReviewDeleted: _loadReviews, // Pass the refresh callback
              );
            },
          ),
      ],
    );
  }

  void _showAddReviewDialog() {
    int _rating = 5;
    final _commentController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Write a Review'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Rating:'),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) {
                  return IconButton(
                    icon: Icon(
                      index < _rating ? Icons.star : Icons.star_border,
                      color: Colors.amber,
                    ),
                    onPressed: () {
                      setState(() {
                        _rating = index + 1;
                      });
                    },
                  );
                }),
              ),
              TextField(
                controller: _commentController,
                decoration: const InputDecoration(
                  labelText: 'Your Review',
                  hintText: 'Share your experience with this product',
                ),
                maxLines: 3,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                if (_commentController.text.isNotEmpty) {
                  try {
                    await ApiService.createReview(
                      widget.product.id,
                      _rating,
                      _commentController.text,
                    );
                    Navigator.pop(context);
                    _loadReviews(); // Reload reviews
                    // Show enhanced success message with green background and icon
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Row(
                          children: [
                            Icon(Icons.check_circle, color: Colors.white),
                            SizedBox(width: 10),
                            Text('Review submitted successfully'),
                          ],
                        ),
                        backgroundColor: Colors.green,
                        duration: const Duration(seconds: 2),
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    );
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Row(
                          children: [
                            Icon(Icons.error, color: Colors.white),
                            SizedBox(width: 10),
                            Expanded(child: Text('Error: ${e.toString()}')),
                          ],
                        ),
                        backgroundColor: Colors.red,
                        duration: const Duration(seconds: 3),
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    );
                  }
                }
              },
              child: const Text('Submit'),
            ),
          ],
        ),
      ),
    );
  }

  // Remove these methods as they're now handled in the ReviewCard widget
  // void _showReportDialog(ReviewModel review) { ... }
  // Widget _buildReviewItem(ReviewModel review) { ... }

  // Add this method to fetch the latest stock information
  Future<void> _fetchLatestProductStock() async {
    // Just set the value directly from the product
    setState(() {
      _currentStockQuantity = widget.product.stockQuantity;
    });
  }

  Future<void> _checkWishlistStatus() async {
    if (!mounted) return;
    
    setState(() {
      _checkingWishlist = true;
    });
    
    try {
      final wishlistProvider = Provider.of<WishlistProvider>(context, listen: false);
      await wishlistProvider.fetchWishlist();
      
      if (mounted) {
        setState(() {
          _isInWishlist = wishlistProvider.isInWishlist(widget.product.id);
          _checkingWishlist = false;
        });
      }
    } catch (e) {
      print('Error checking wishlist status: $e');
      if (mounted) {
        setState(() {
          _checkingWishlist = false;
        });
      }
    }
  }

  Future<void> _toggleWishlist() async {
    try {
      final wishlistProvider = Provider.of<WishlistProvider>(context, listen: false);
      await wishlistProvider.toggleWishlistItem(widget.product.id, widget.product);
      
      final isAdded = wishlistProvider.isInWishlist(widget.product.id);
      setState(() {
        _isInWishlist = isAdded;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isAdded ? 'Added to wishlist' : 'Removed from wishlist',
            style: const TextStyle(color: Colors.white),
          ),
          backgroundColor: isAdded ? Colors.green : Colors.grey[700],
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Error updating wishlist: ${e.toString()}',
            style: const TextStyle(color: Colors.white),
          ),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Widget _buildImageGallery() {
    // Check if the product images list is empty
    if (_productImages.isEmpty) {
      // Return a placeholder when no images are available
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              height: 250,
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.image_not_supported, size: 64, color: Colors.grey.shade400),
                    const SizedBox(height: 16),
                    Text(
                      'No images available',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Original code for when images are available
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Main image display
          Container(
            height: 250,
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                _productImages[_selectedImageIndex],
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  color: Colors.grey.shade200,
                  child: const Center(
                    child: Icon(Icons.error_outline, size: 50, color: Colors.grey),
                  ),
                ),
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Image count indicator
          Text(
            'Image ${_selectedImageIndex + 1} of ${_productImages.length}',
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 14,
            ),
          ),
          
          const SizedBox(height: 12),
          
          // Only show thumbnail row if there's more than one image
          if (_productImages.length > 1)
            SizedBox(
              height: 80,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _productImages.length,
                itemBuilder: (context, index) {
                  final isSelected = index == _selectedImageIndex;
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedImageIndex = index;
                      });
                    },
                    child: Container(
                      width: 80,
                      margin: const EdgeInsets.only(right: 12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isSelected ? Theme.of(context).primaryColor : Colors.grey.shade300,
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(7),
                        child: Image.network(
                          _productImages[index],
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Container(
                            color: Colors.grey.shade200,
                            child: const Icon(Icons.error_outline, color: Colors.grey),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  // Add this method to build the stock status indicator
  Widget _buildStockStatus() {
    // Always show as in stock unless explicitly set to 0
    final bool inStock = _currentStockQuantity > 0;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: inStock ? Colors.green.shade50 : Colors.red.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: inStock ? Colors.green.shade200 : Colors.red.shade200,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            inStock ? Icons.check_circle : Icons.cancel,
            size: 16,
            color: inStock ? Colors.green : Colors.red,
          ),
          const SizedBox(width: 4),
          Text(
            inStock ? 'In Stock' : 'Out of Stock',
            style: TextStyle(
              color: inStock ? Colors.green.shade700 : Colors.red.shade700,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    print('Building ProductDetailScreen with stock: $_currentStockQuantity');
    
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: MediaQuery.of(context).size.height * 0.45,
                pinned: true,
                backgroundColor: Colors.white,
                elevation: 0,
                actions: [
                  IconButton(
                    icon: const Icon(Icons.share, color: Colors.white),
                    onPressed: () {
                      // Share functionality
                    },
                    tooltip: 'Share Product',
                  ),
                  IconButton(
                    icon: _checkingWishlist
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : Icon(
                            _isInWishlist ? Icons.favorite : Icons.favorite_border,
                            color: _isInWishlist ? Colors.red : Colors.white, // Changed to white when not selected
                          ),
                    onPressed: _toggleWishlist,
                  ),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      Hero(
                        tag: 'product-${widget.product.id}',
                        child: Image.network(
                          _productImages.isNotEmpty ? _productImages[_selectedImageIndex] : widget.product.imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Container(
                            color: Colors.grey.shade200,
                            child: const Center(
                              child: Icon(Icons.error_outline, size: 50, color: Colors.grey),
                            ),
                          ),
                        ),
                      ),
                      // Gradient overlay for better text visibility
                      const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black45,
                              Colors.transparent,
                              Colors.black45,
                            ],
                            stops: [0.0, 0.5, 1.0],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                leading: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: CircleAvatar(
                    backgroundColor: Color.fromRGBO(255, 255, 255, 0.9),
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.black87),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                ),
              ),
              SliverList(
                delegate: SliverChildListDelegate(
                  [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Deal timer - place it above the badges row
                          if (widget.deal != null)
                            Container(
                              margin: const EdgeInsets.only(bottom: 16),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Theme.of(context).colorScheme.primary.withAlpha(204),
                                    Theme.of(context).colorScheme.secondary.withAlpha(179),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: Theme.of(context).colorScheme.primary.withAlpha(76),
                                    blurRadius: 8,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: Color.fromRGBO(255, 255, 255, 0.25),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.timer_outlined,
                                        color: Colors.white,
                                        size: 22,
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            'LIMITED TIME OFFER',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                              color: Colors.white,
                                              letterSpacing: 0.5,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Row(
                                            children: [
                                              Text(
                                                'Ends in: ',
                                                style: TextStyle(
                                                  color: Colors.white.withAlpha(230),
                                                  fontSize: 13,
                                                ),
                                              ),
                                              Text(
                                                _timeLeft,
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 14,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    // Discount badge if applicable
                                    if (widget.product.discountPercentage != null && widget.product.discountPercentage! > 0)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                        child: Text(
                                          '${widget.product.discountPercentage}% OFF',
                                          style: TextStyle(
                                            color: Theme.of(context).colorScheme.primary,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          
                          // Badges row
                          Row(
                            children: [
                              if (widget.product.isNew)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.green.shade400,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: const Text(
                                    'NEW',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              if (widget.product.isNew && widget.product.isOnSale)
                                const SizedBox(width: 8),
                              if (widget.product.isOnSale)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.red.shade400,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    widget.product.discountPercentage != null 
                                        ? '${widget.product.discountPercentage}% OFF' 
                                        : 'SALE',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Product info in a clean table-like layout
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            child: Column(
                              children: [
                                // Name row
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    SizedBox(
                                      width: 80,
                                      child: Text(
                                        'Name:',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w500,
                                          color: Colors.grey.shade700,
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      child: Text(
                                        widget.product.title,
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                
                                // Price row
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    SizedBox(
                                      width: 80,
                                      child: Text(
                                        'Price:',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w500,
                                          color: Colors.grey.shade700,
                                        ),
                                      ),
                                    ),
                                    if (widget.product.isOnSale) ...[
                                      Text(
                                        '\$${widget.product.displaySalePrice}',
                                        style: TextStyle(
                                          fontSize: 22,
                                          fontWeight: FontWeight.bold,
                                          color: Theme.of(context).primaryColor,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Text(
                                        '\$${widget.product.displayPrice}',
                                        style: TextStyle(
                                          fontSize: 16,
                                          decoration: TextDecoration.lineThrough,
                                          color: Colors.red, // Changed from Colors.grey.shade600 to Colors.red
                                        ),
                                      ),
                                    ] else
                                      Text(
                                        '\$${widget.product.displayPrice}',
                                        style: TextStyle(
                                          fontSize: 22,
                                          fontWeight: FontWeight.bold,
                                          color: Theme.of(context).primaryColor,
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                
                                // Category row
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    SizedBox(
                                      width: 80,
                                      child: Text(
                                        'Category:',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w500,
                                          color: Colors.grey.shade700,
                                        ),
                                      ),
                                    ),
                                    Row(
                                      children: [
                                        Icon(
                                          _getIconData(widget.product.category.icon ?? widget.product.category.name),
                                          color: Theme.of(context).primaryColor,
                                          size: 24,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          widget.product.category.name,
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),

                                // Stock indicator row
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    SizedBox(
                                      width: 80,
                                      child: Text(
                                        'Stock:',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w500,
                                          color: Colors.grey.shade700,
                                        ),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: _currentStockQuantity > 5 
                                            ? Colors.green.shade100 
                                            : (_currentStockQuantity > 0 ? Colors.orange.shade100 : Colors.red.shade100),
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                          color: _currentStockQuantity > 5 
                                              ? Colors.green.shade600 
                                              : (_currentStockQuantity > 0 ? Colors.orange : Colors.red),
                                          width: 1,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.inventory_2_outlined,
                                            size: 16,
                                            color: _currentStockQuantity > 5 
                                                ? Colors.green.shade600 
                                                : (_currentStockQuantity > 0 ? Colors.orange : Colors.red),
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            _currentStockQuantity > 0 
                                                ? '$_currentStockQuantity in stock' 
                                                : 'Out of stock',
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w500,
                                              color: _currentStockQuantity > 5 
                                                  ? Colors.green.shade600 
                                                  : (_currentStockQuantity > 0 ? Colors.orange : Colors.red),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Description section with improved styling
                          const Text(
                            'Description',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            child: Text(
                              widget.product.description,
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey.shade800,
                                height: 1.6,
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Product Gallery Section - Now placed after the description
                          const Text(
                            'Product Gallery',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          _buildImageGallery(),
                          const SizedBox(height: 24),
                          
                          // Reviews section
                          _buildReviewsSection(),
                          
                          // Add padding at the bottom to account for the bottom sheet
                          SizedBox(
                            height: MediaQuery.of(context).padding.bottom + 180,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      bottomSheet: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(13),
              spreadRadius: 1,
              blurRadius: 10,
              offset: const Offset(0, -3),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Consumer<AuthProvider>(
              builder: (context, authProvider, _) {
                final isLoggedIn = authProvider.isAuthenticated;
                final isOutOfStock = _currentStockQuantity <= 0;
                final isDisabled = !isLoggedIn || isOutOfStock;
                
                return ElevatedButton(
                  onPressed: isDisabled ? () {
                    // If not logged in, show login prompt
                    if (!isLoggedIn) {
                      showDialog(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Login Required'),
                          content: const Text('Please log in to add items to your cart.'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(ctx).pop(),
                              child: const Text('CANCEL'),
                            ),
                            TextButton(
                              onPressed: () {
                                Navigator.of(ctx).pop();
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (context) => const LoginScreen(),
                                  ),
                                );
                              },
                              child: const Text('LOG IN'),
                            ),
                          ],
                        ),
                      );
                    }
                  } : () async {
                    final cart = Provider.of<CartProvider>(context, listen: false);
                    
                    // Ensure user ID is set if user is authenticated
                    cart.ensureUserIdSet(context);
                    
                    // Check if adding would exceed available stock
                    int currentCartQuantity = 0;
                    if (cart.items.containsKey(widget.product.id)) {
                      currentCartQuantity = cart.items[widget.product.id]!.quantity;
                    }
                    
                    if (currentCartQuantity + 1 > _currentStockQuantity) {
                      // Show error message
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Sorry, only $_currentStockQuantity items available in stock',
                            style: const TextStyle(color: Colors.white),
                          ),
                          backgroundColor: Colors.red.shade600,
                          duration: const Duration(seconds: 2),
                        ),
                      );
                      return;
                    }
                    
                    // Use the new method to add item directly to database
                    bool success = await cart.addItemToDatabase(
                      widget.product.id,
                      widget.product.isOnSale 
                          ? widget.product.salePrice ?? widget.product.price
                          : widget.product.price,
                      widget.product.title,
                      widget.product.imageUrl,
                      widget.product.stockQuantity,
                    );
                    
                    if (success) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text(
                            'Item added to cart',
                            style: TextStyle(color: Colors.white),
                          ),
                          backgroundColor: Colors.green,
                          duration: const Duration(seconds: 2),
                          action: SnackBarAction(
                            label: 'VIEW CART',
                            textColor: Colors.white,
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) => const CartScreen(),
                                ),
                              );
                            },
                          ),
                        ),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text(
                            'Failed to add item to cart',
                            style: TextStyle(color: Colors.white),
                          ),
                          backgroundColor: Colors.red,
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDisabled 
                        ? Colors.grey.shade300
                        : Theme.of(context).primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: isDisabled ? 0 : 4,
                    shadowColor: isDisabled 
                        ? Colors.transparent
                        : Theme.of(context).primaryColor.withAlpha(102),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        !isLoggedIn 
                            ? Icons.login
                            : (isOutOfStock ? Icons.remove_shopping_cart : Icons.shopping_cart),
                        size: 20,
                        color: isDisabled ? Colors.grey.shade600 : Colors.white,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        !isLoggedIn 
                            ? 'Login to Add to Cart'
                            : (isOutOfStock ? 'Out of Stock' : 'Add to Cart'),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isDisabled ? Colors.grey.shade600 : Colors.white,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}









