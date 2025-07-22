
import '../services/api_service.dart';

class Product {
  final String id;
  final String title;
  final double price;
  final double? salePrice;
  final String description;
  final String imageUrl;
  final CategoryInfo category;
  final bool isNew;
  final bool isOnSale;
  final int stockQuantity; // Make sure this field exists
  final double? oldPrice;

  Product({
    required this.id,
    required this.title,
    required this.price,
    this.salePrice,
    required this.description,
    required this.imageUrl,
    required this.category,
    this.isNew = false,
    this.isOnSale = false,
    this.stockQuantity = 0, 
    this.oldPrice,
  });

  // Add getter for discount percentage
  int? get discountPercentage {
    if (!isOnSale || salePrice == null || price == 0) return null;
    return ((price - salePrice!) / price * 100).round();
  }

  // Keep existing methods
  String formattedPrice(double price) {
    // Remove decimal zeros if the number is a whole number
    if (price == price.roundToDouble()) {
      return price.toInt().toString();
    } else {
      return price.toStringAsFixed(2);
    }
  }

  // Use this method for displaying prices
  String get displayPrice => formattedPrice(price);
  String get displaySalePrice => salePrice != null ? formattedPrice(salePrice!) : '';

  factory Product.fromJson(Map<String, dynamic> json) {
    // Debug print to see what we're getting
    print('Product.fromJson - Input JSON: $json');
    
    // Handle image URL
    String imageUrl = json['image_url'] ?? json['imageUrl'] ?? '';
    if (imageUrl.isNotEmpty && !imageUrl.startsWith('http')) {
      imageUrl = '${ApiService.baseUrl}$imageUrl';
    }

    // Handle category
    CategoryInfo categoryInfo;
    if (json['category'] is Map) {
      categoryInfo = CategoryInfo.fromJson(json['category']);
    } else {
      // If category is not a Map, try to construct from individual fields
      categoryInfo = CategoryInfo(
        id: (json['category_id'] ?? json['category'] ?? '').toString(),
        name: json['category_name'] ?? '',
        icon: json['category_icon'],
      );
    }

    // Make sure we parse stock_quantity correctly
    int stockQuantity = 0; // Default to 0
    if (json.containsKey('stock_quantity') && json['stock_quantity'] != null) {
      try {
        stockQuantity = int.parse(json['stock_quantity'].toString());
        print('Parsed stock_quantity: $stockQuantity');
      } catch (e) {
        print('Error parsing stock_quantity: $e');
      }
    } else {
      print('stock_quantity field not found in product JSON');
    }

    return Product(
      id: json['id'].toString(),
      title: json['title'],
      price: double.parse(json['price'].toString()),
      salePrice: json['sale_price'] != null ? double.parse(json['sale_price'].toString()) : null,
      description: json['description'] ?? '',
      imageUrl: imageUrl,
      category: categoryInfo,
      isNew: json['is_new'] == true || json['isNew'] == true,
      isOnSale: json['is_on_sale'] == true || json['isOnSale'] == true,
      stockQuantity: stockQuantity,
      oldPrice: json['old_price'] != null ? double.parse(json['old_price'].toString()) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'price': price,
      'sale_price': salePrice,
      'description': description,
      'image_url': imageUrl,
      'category': category,
      'is_new': isNew,
      'is_on_sale': isOnSale,
      'stock_quantity': stockQuantity,
    };
  }
}

// Update CategoryInfo class to include icon
class CategoryInfo {
  final String id;
  final String name;
  final String? icon;  // Add icon field as optional

  CategoryInfo({
    required this.id,
    required this.name,
    this.icon,  // Make it optional
  });

  factory CategoryInfo.fromJson(Map<String, dynamic> json) {
    return CategoryInfo(
      id: json['id'].toString(),
      name: json['name'].toString(),
      icon: json['icon'],  // Include icon in fromJson
    );
  }
}






