from django.db import models
from django.utils import timezone
from django.contrib.auth import get_user_model
from django.conf import settings
from model_utils.models import TimeStampedModel
from model_utils import FieldTracker
from django.db.models.signals import post_save
from django.dispatch import receiver

User = get_user_model()

class Category(models.Model):
    name = models.CharField(max_length=100)
    # No icon field
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        verbose_name_plural = "Categories"

    def __str__(self):
        return self.name
        
    @property
    def icon(self):
        """Return the lowercase name as the icon"""
        return self.name.lower()

class Product(models.Model):
    title = models.CharField(max_length=200)
    price = models.DecimalField(max_digits=10, decimal_places=2)
    sale_price = models.DecimalField(max_digits=10, decimal_places=2, null=True, blank=True)
    description = models.TextField()
    image = models.ImageField(upload_to='products/%Y/%m/%d/', null=True, blank=True)
    category = models.ForeignKey(Category, on_delete=models.CASCADE, related_name='products')
    is_new = models.BooleanField(default=False)
    is_on_sale = models.BooleanField(default=False)
    stock_quantity = models.PositiveIntegerField(default=0)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    def __str__(self):
        return self.title

    @property
    def image_url(self):
        if self.image:
            return self.image.url
        return None

    def display_price(self):
        """Format price to remove decimal places if it's a whole number"""
        if self.price == int(self.price):
            return int(self.price)
        return self.price
    
    def display_sale_price(self):
        """Format sale price to remove decimal places if it's a whole number"""
        if self.sale_price is None:
            return None
        if self.sale_price == int(self.sale_price):
            return int(self.sale_price)
        return self.sale_price

    @property
    def average_rating(self):
        reviews = self.reviews.all()
        if reviews:
            return sum(review.rating for review in reviews) / reviews.count()
        return 0
    
    @property
    def review_count(self):
        return self.reviews.count()

class ProductImage(models.Model):
    product = models.ForeignKey(Product, on_delete=models.CASCADE, related_name='images')
    image = models.ImageField(upload_to='products/gallery/%Y/%m/%d/', null=True, blank=True)
    is_primary = models.BooleanField(default=False)
    created_at = models.DateTimeField(auto_now_add=True)
    
    class Meta:
        ordering = ['-is_primary', 'created_at']
    
    def __str__(self):
        return f"Image for {self.product.title}"

class Deal(models.Model):
    product = models.ForeignKey(Product, on_delete=models.CASCADE, related_name='deals')
    discount_percentage = models.IntegerField()
    discount_price = models.DecimalField(max_digits=10, decimal_places=2)
    start_date = models.DateTimeField()
    end_date = models.DateTimeField()
    is_active = models.BooleanField(default=False)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    def save(self, *args, **kwargs):
        # Convert values to correct types before calculation
        product_price = float(self.product.price)
        discount_percent = float(self.discount_percentage)
        
        # Calculate discount price
        self.discount_price = product_price * (1 - (discount_percent / 100))
        
        # Add debug print
        print(f"Saving deal for {self.product.title}")
        print(f"Is active: {self.is_active}")
        print(f"Start date: {self.start_date}")
        print(f"End date: {self.end_date}")
        
        super().save(*args, **kwargs)

    def __str__(self):
        return f"Deal for {self.product.title}"

    @property
    def is_expired(self):
        return timezone.now() > self.end_date

    @property
    def is_started(self):
        return timezone.now() >= self.start_date

    @property
    def status(self):
        if not self.is_active:
            return 'inactive'
        if self.is_expired:
            return 'expired'
        if not self.is_started:
            return 'scheduled'
        return 'active'

class Order(models.Model):
    STATUS_CHOICES = (
        ('pending', 'Pending'),
        ('accepted', 'Accepted'),
        ('refused', 'Refused'),
        ('shipped', 'Shipped'),
        ('delivered', 'Delivered'),
    )

    id = models.AutoField(primary_key=True)
    user = models.ForeignKey(get_user_model(), on_delete=models.SET_NULL, null=True, blank=True)
    amount = models.DecimalField(max_digits=10, decimal_places=2)
    date_time = models.DateTimeField(auto_now_add=True)
    status = models.CharField(
        max_length=20,
        choices=STATUS_CHOICES,
        default='pending'
    )
    delivery_info = models.JSONField(default=dict)
    items_data = models.JSONField(default=list)
    user_order_number = models.PositiveIntegerField(null=True, blank=True)
    
    # Add the tracker
    tracker = FieldTracker(fields=['status'])
    
    class Meta:
        ordering = ['id']  # Change to ascending order

    def save(self, *args, **kwargs):
        # If this is a new order and has a user
        if not self.id and self.user:
            # Get the count of existing orders for this user
            user_order_count = Order.objects.filter(user=self.user).count()
            # Assign the next number in sequence (1-based)
            self.user_order_number = user_order_count + 1
        super().save(*args, **kwargs)

class OrderItem(models.Model):
    order = models.ForeignKey(Order, related_name='items', on_delete=models.CASCADE)
    product_id = models.CharField(max_length=100)
    title = models.CharField(max_length=255)
    quantity = models.IntegerField()
    price = models.DecimalField(max_digits=10, decimal_places=2)
    image_url = models.URLField()

    class Meta:
        ordering = ['id']

class Notification(models.Model):
    NOTIFICATION_TYPES = (
        ('ORDER_STATUS', 'Order Status Update'),
        ('GENERAL', 'General Notification'),
        ('PROMOTION', 'Promotion'),
    )
    
    user = models.ForeignKey(get_user_model(), on_delete=models.CASCADE)
    title = models.CharField(max_length=255)
    message = models.TextField()
    order_id = models.IntegerField(null=True, blank=True)
    is_read = models.BooleanField(default=False)
    created_at = models.DateTimeField(auto_now_add=True)
    notification_type = models.CharField(
        max_length=20,
        choices=NOTIFICATION_TYPES,
        default='GENERAL'
    )
    
    class Meta:
        ordering = ['-created_at']

class Review(models.Model):
    RATING_CHOICES = [(1, '1'), (2, '2'), (3, '3'), (4, '4'), (5, '5')]
    
    product = models.ForeignKey(Product, on_delete=models.CASCADE, related_name='reviews')
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE)
    rating = models.IntegerField(choices=RATING_CHOICES)
    comment = models.TextField()
    is_approved = models.BooleanField(default=True)  # Changed to default=True
    created_at = models.DateTimeField(auto_now_add=True)
    reported = models.BooleanField(default=False)  # New field to track reported reviews
    report_reason = models.TextField(blank=True, null=True)  # Optional reason for report
    
    class Meta:
        unique_together = ('product', 'user')  # One review per product per user
        
    def __str__(self):
        return f"{self.user.username}'s review on {self.product.title}"

class Wishlist(models.Model):
    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='wishlists')
    product = models.ForeignKey(Product, on_delete=models.CASCADE, related_name='wishlist_items')
    added_at = models.DateTimeField(auto_now_add=True)
    
    class Meta:
        unique_together = ('user', 'product')  # Prevent duplicates
        
    def __str__(self):
        return f"{self.user.username}'s wishlist item: {self.product.title}"

class Cart(models.Model):
    user = models.OneToOneField(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='cart')
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    
    def __str__(self):
        return f"{self.user.username}'s cart"

class CartItem(models.Model):
    cart = models.ForeignKey(Cart, on_delete=models.CASCADE, related_name='items')
    product_id = models.CharField(max_length=100)
    quantity = models.PositiveIntegerField(default=1)
    
    class Meta:
        unique_together = ('cart', 'product_id')
    
    def __str__(self):
        return f"{self.quantity} x Product {self.product_id} in {self.cart}"

@receiver(post_save, sender=Order)
def order_post_save(sender, instance, created, **kwargs):
    """Send notification when order status changes"""
    print(f"Order post_save signal triggered for order {instance.id}")
    # Only send notification if status has changed
    if instance.tracker.has_changed('status'):
        print(f"Order {instance.id} status changed to {instance.status}")
        from .views import send_order_status_notification
        send_order_status_notification(instance)
    else:
        print(f"Order {instance.id} status did not change")
