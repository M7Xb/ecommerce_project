import '../services/api_service.dart';
import 'product.dart';

class Deal {
  final String id;
  final int discountPercentage;
  final double discountPrice;
  final DateTime startDate;
  final DateTime endDate;
  final Product product;

  Deal({
    required this.id,
    required this.discountPercentage,
    required this.discountPrice,
    required this.startDate,
    required this.endDate,
    required this.product,
  });

  factory Deal.fromJson(Map<String, dynamic> json) {
    
    
    // Handle the product data
    Map<String, dynamic> productData = Map<String, dynamic>.from(json['product']);
    
    
    // If the product data contains image_url, modify it to include base URL
    if (productData['image_url'] != null) {
      String imageUrl = productData['image_url'];
      if (imageUrl.isNotEmpty && !imageUrl.startsWith('http')) {
        productData['image_url'] = '${ApiService.baseUrl}$imageUrl';
      }
    }
    
    // Create the product from the product data
    final product = Product.fromJson(productData);
    
    
    // Create the deal object
    return Deal(
      id: json['id'].toString(),
      discountPercentage: json['discount_percentage'],
      discountPrice: double.parse(json['discount_price'].toString()),
      startDate: DateTime.parse(json['start_date']),
      endDate: DateTime.parse(json['end_date']),
      product: product,
    );
  }
  
 
}
















