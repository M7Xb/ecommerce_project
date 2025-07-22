from rest_framework import serializers
from .models import Order, OrderItem, Notification, Review, Product, ProductImage
from django.conf import settings

class OrderItemSerializer(serializers.ModelSerializer):
    class Meta:
        model = OrderItem
        fields = ['product_id', 'title', 'quantity', 'price', 'image_url']

class OrderSerializer(serializers.ModelSerializer):
    items = OrderItemSerializer(many=True, read_only=True)
    
    class Meta:
        model = Order
        fields = ['id', 'user_order_number', 'amount', 'date_time', 'status', 'delivery_info', 'items_data', 'items']

    def create(self, validated_data):
        items_data = validated_data.pop('items')
        order = Order.objects.create(**validated_data)
        
        for item_data in items_data:
            OrderItem.objects.create(order=order, **item_data)
        
        return order

class NotificationSerializer(serializers.ModelSerializer):
    class Meta:
        model = Notification
        fields = ['id', 'user', 'title', 'message', 'order_id', 'is_read', 'created_at']

class ReviewSerializer(serializers.ModelSerializer):
    user_name = serializers.SerializerMethodField()
    user_id = serializers.SerializerMethodField()
    profile_image_url = serializers.SerializerMethodField()
    
    class Meta:
        model = Review
        fields = ['id', 'rating', 'comment', 'created_at', 'user_name', 'user_id', 'profile_image_url', 'is_approved']
        
    def get_user_name(self, obj):
        return f"{obj.user.first_name} {obj.user.last_name}"
    
    def get_user_id(self, obj):
        return obj.user.id
        
    def get_profile_image_url(self, obj):
        if obj.user.profile_image:
            return obj.user.profile_image.url
        return None

class ProductImageSerializer(serializers.ModelSerializer):
    image_url = serializers.SerializerMethodField()
    
    class Meta:
        model = ProductImage
        fields = ['id', 'image_url', 'is_primary']
        
    def get_image_url(self, obj):
        if obj.image:
            request = self.context.get('request')
            if request:
                return request.build_absolute_uri(obj.image.url)
            return obj.image.url
        return None

class ProductSerializer(serializers.ModelSerializer):
    average_rating = serializers.FloatField(read_only=True)
    review_count = serializers.IntegerField(read_only=True)
    image_url = serializers.SerializerMethodField()
    images = ProductImageSerializer(many=True, read_only=True)
    
    class Meta:
        model = Product
        fields = ['id', 'title', 'price', 'sale_price', 'description', 'image_url', 
                  'category', 'is_new', 'is_on_sale', 'average_rating', 'review_count', 
                  'images', 'stock_quantity']  # Ensure stock_quantity is included
                  
    def get_image_url(self, obj):
        if obj.image:
            request = self.context.get('request')
            if request:
                return request.build_absolute_uri(obj.image.url)
            return obj.image.url
        return None

# Remove WishlistSerializer class









