import 'dart:async';
import 'package:flutter/material.dart';
import '../models/product.dart';
import '../models/deal.dart';
import '../screens/product_detail_screen.dart';

class ProductCard extends StatefulWidget {
  final Product product;
  final int? discountPercentage;
  final double? discountPrice;
  final bool showDiscountBadge;
  final bool isFullWidth;
  final Deal? deal;

  const ProductCard({
    Key? key,
    required this.product,
    this.discountPercentage,
    this.discountPrice,
    this.showDiscountBadge = false,
    this.isFullWidth = false,
    this.deal,
  }) : super(key: key);

  @override
  State<ProductCard> createState() => _ProductCardState();
}

class _ProductCardState extends State<ProductCard> {
  Timer? _timer;
  String _timeLeft = '';

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

  int? get effectiveDiscountPercentage {
    if (widget.discountPercentage != null) {
      return widget.discountPercentage;
    }
    if (widget.product.isOnSale && widget.product.discountPercentage != null) {
      return widget.product.discountPercentage;
    }
    return null;
  }

  double? get effectiveDiscountPrice {
    if (widget.discountPrice != null) {
      return widget.discountPrice;
    }
    if (widget.product.isOnSale && widget.product.salePrice != null) {
      return widget.product.salePrice;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    if (widget.deal != null) {
      _startTimer();
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

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => ProductDetailScreen(
              product: widget.product,
              deal: widget.deal,
            ),
          ),
        );
      },
      child: Container(
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
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: widget.isFullWidth
              ? _buildFullWidthCard(context)
              : _buildRegularCard(context),
        ),
      ),
    );
  }

  Widget _buildFullWidthCard(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        image: DecorationImage(
          image: NetworkImage(widget.product.imageUrl),
          fit: BoxFit.cover,
          colorFilter: ColorFilter.mode(
            Colors.black.withAlpha(77),
            BlendMode.darken,
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (widget.showDiscountBadge && widget.discountPercentage != null && widget.discountPercentage! > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.error,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${widget.discountPercentage}% OFF',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                if (widget.deal != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black.withAlpha(119),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.timer_outlined, color: Colors.white, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          _timeLeft,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Name: ${widget.product.title}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  'Category: ${widget.product.category.name}',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    if (widget.deal != null) ...[
                      // For deals, show the discounted price
                      Text(
                        'Price: \$${widget.product.formattedPrice(widget.deal!.discountPrice)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '\$${widget.product.displayPrice}',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 16,
                          decoration: TextDecoration.lineThrough,
                        ),
                      ),
                    ] else if (widget.product.isOnSale && effectiveDiscountPrice != null) ...[
                      // For sale products, show the sale price
                      Text(
                        'Price: \$${widget.product.formattedPrice(effectiveDiscountPrice!)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '\$${widget.product.displayPrice}',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 16,
                          decoration: TextDecoration.lineThrough,
                        ),
                      ),
                    ] else
                      // For regular products, show the regular price
                      Text(
                        'Price: \$${widget.product.displayPrice}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRegularCard(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Image part with badges
        Stack(
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
              child: Image.network(
                widget.product.imageUrl,
                height: 150,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
            
            // Deal countdown timer
            if (widget.deal != null)
              Positioned(
                bottom: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withAlpha(179),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.timer_outlined, color: Colors.white, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        _timeLeft,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // Discount badge - only show if there's an actual discount percentage > 0
            if ((widget.showDiscountBadge || widget.product.isOnSale) && 
                (widget.discountPercentage != null && widget.discountPercentage! > 0) || 
                (widget.product.discountPercentage != null && widget.product.discountPercentage! > 0))
              Positioned(
                top: 8,
                left: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.error,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${widget.discountPercentage ?? widget.product.discountPercentage}% OFF',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            // NEW badge
            if (widget.product.isNew)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.green,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'NEW',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
          ],
        ),

        // Text part with centered content
        Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Title with "Name:" prefix
              Text(
                'Name: ${widget.product.title}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
            
              // Category with circular background
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Theme.of(context).primaryColor.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _getIconData(widget.product.category.name),
                      size: 14,
                      color: Theme.of(context).primaryColor,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      widget.product.category.name,
                      style: TextStyle(
                        fontSize: 13,
                        color: Theme.of(context).primaryColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            
              // Price with "Price:" prefix
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (widget.deal != null) ...[
                    // For deals, show the discounted price
                    Text(
                      'Price: \$${widget.product.formattedPrice(widget.deal!.discountPrice)}',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).primaryColor,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '\$${widget.product.displayPrice}',
                      style: const TextStyle(
                        fontSize: 14,
                        decoration: TextDecoration.lineThrough,
                        color: Colors.red,
                      ),
                    ),
                  ] else if (widget.product.isOnSale && effectiveDiscountPrice != null) ...[
                    // For sale products, show the sale price
                    Text(
                      'Price: \$${widget.product.formattedPrice(effectiveDiscountPrice!)}',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).primaryColor,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '\$${widget.product.displayPrice}',
                      style: const TextStyle(
                        fontSize: 14,
                        decoration: TextDecoration.lineThrough,
                        color: Colors.red,
                      ),
                    ),
                  ] else
                    // For regular products, show the regular price
                    Text(
                      'Price: \$${widget.product.displayPrice}',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).primaryColor,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

}



















