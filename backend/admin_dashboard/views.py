import os
from django.shortcuts import render, redirect, get_object_or_404
from django.contrib.auth.decorators import login_required, user_passes_test
from django.contrib.auth import get_user_model
from django.contrib import messages
from .models import Category, Product, Deal, Order, OrderItem, Notification, Review, Wishlist, Cart, CartItem, ProductImage
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import AllowAny, IsAdminUser, IsAuthenticated
from rest_framework.response import Response
from rest_framework import status
from django.utils import timezone
from .serializers import OrderSerializer, ReviewSerializer, ProductImageSerializer, ProductSerializer
from django.http import JsonResponse, HttpResponse
from django.views.decorators.http import require_http_methods
import json
import logging
import requests
from django.conf import settings
from django.db.models.signals import post_save
from django.dispatch import receiver
from django.middleware.csrf import get_token
from django.views.decorators.csrf import csrf_exempt
import firebase_admin
from firebase_admin import credentials, messaging
from authentication.models import FCMToken

# Check if Firebase is initialized
try:
    firebase_app = firebase_admin.get_app()
    print("Firebase already initialized")
except ValueError:
    # Firebase not initialized, initialize it
    try:
        print("Initializing Firebase...")
        if hasattr(settings, 'FIREBASE_CREDENTIALS'):
            cred = credentials.Certificate(settings.FIREBASE_CREDENTIALS)
            firebase_admin.initialize_app(cred)
            print("Firebase initialized successfully")
        else:
            print("FIREBASE_CREDENTIALS not found in settings")
    except Exception as e:
        print(f"Error initializing Firebase: {str(e)}")

logger = logging.getLogger(__name__)

User = get_user_model()

def is_admin(user):
    print(f"is_admin check for user: {user}")
    print(f"user.is_staff: {user.is_staff}")
    print(f"user.is_authenticated: {user.is_authenticated}")
    result = user.is_staff
    print(f"is_admin result: {result}")
    return result

@login_required
def dashboard(request):
    # Debug logging
    print(f"Dashboard accessed by user: {request.user}")
    print(f"User is_authenticated: {request.user.is_authenticated}")
    print(f"User is_staff: {request.user.is_staff}")
    print(f"User is_active: {request.user.is_active}")
    
    # Get statistics
    total_users = User.objects.count()
    total_categories = Category.objects.count()
    total_products = Product.objects.count()
    total_deals = Deal.objects.count()
    total_orders = Order.objects.count()
    
    context = {
        'total_users': total_users,
        'total_categories': total_categories,
        'total_products': total_products,
        'total_deals': total_deals,
        'total_orders': total_orders,
    }
    return render(request, 'admin_dashboard/dashboard.html', context)

@login_required
@user_passes_test(is_admin)
def category_list(request):
    if request.method == 'POST':
        name = request.POST.get('name')
        
        if name:
            Category.objects.create(name=name)
            messages.success(request, 'Category added successfully.')
            return redirect('admin_dashboard:category_list')
        else:
            messages.error(request, 'Category name is required.')

    categories = Category.objects.all().order_by('-created_at')
    return render(request, 'admin_dashboard/categories.html', {'categories': categories})

@login_required
@user_passes_test(is_admin)
def user_list(request):
    users = User.objects.all().order_by('-date_joined')
    return render(request, 'admin_dashboard/users.html', {'users': users})

@login_required
@user_passes_test(is_admin)
def toggle_user_status(request, user_id):
    if request.method == 'POST':
        user = get_object_or_404(User, id=user_id)
        user.is_active = not user.is_active
        user.save()
        status = 'activated' if user.is_active else 'deactivated'
        messages.success(request, f'User {user.email} has been {status}.')
    return redirect('admin_dashboard:user_list')

@login_required
@user_passes_test(is_admin)
def delete_category(request, category_id):
    if request.method == 'POST':
        category = get_object_or_404(Category, id=category_id)
        category.delete()
        messages.success(request, f'Category "{category.name}" has been deleted.')
    return redirect('admin_dashboard:category_list')

@api_view(['GET'])
@permission_classes([AllowAny])
def category_list_api(request):
    categories = Category.objects.all().order_by('-created_at')
    data = [{
        'id': category.id,
        'name': category.name,
        'icon': category.name.lower(),  # Use the lowercase category name as the icon
        'created_at': category.created_at.isoformat()
    } for category in categories]
    return Response({'categories': data})

@login_required
@user_passes_test(is_admin)
def product_list(request):
    products = Product.objects.all().order_by('-created_at')
    categories = Category.objects.all()
    return render(request, 'admin_dashboard/products.html', {
        'products': products,
        'categories': categories
    })

@login_required
@user_passes_test(is_admin)
def add_product(request):
    """Add a new product"""
    if request.method == 'POST':
        title = request.POST.get('title')
        price = request.POST.get('price')
        sale_price = request.POST.get('sale_price')
        description = request.POST.get('description')
        category_id = request.POST.get('category')
        stock_quantity = request.POST.get('stock_quantity', 0)
        is_new = request.POST.get('is_new') == 'on'
        is_on_sale = request.POST.get('is_on_sale') == 'on'

        try:
            category = Category.objects.get(id=category_id)
            product = Product.objects.create(
                title=title,
                price=price,
                sale_price=sale_price if sale_price else None,
                description=description,
                category=category,
                stock_quantity=stock_quantity,
                is_new=is_new,
                is_on_sale=is_on_sale
            )

            # Handle main image upload
            if 'image' in request.FILES:
                product.image = request.FILES['image']
                product.save()
            
            # Handle gallery images
            for key in request.FILES:
                if key.startswith('gallery_image_'):
                    image_file = request.FILES[key]
                    ProductImage.objects.create(
                        product=product,
                        image=image_file,
                        is_primary=False
                    )

            messages.success(request, 'Product added successfully.')
            return redirect('admin_dashboard:product_list')
        except Exception as e:
            messages.error(request, f'Error adding product: {str(e)}')

    categories = Category.objects.all()
    return render(request, 'admin_dashboard/add_product.html', {'categories': categories})

@login_required
@user_passes_test(is_admin)
def edit_product(request, product_id):
    """Edit an existing product"""
    product = get_object_or_404(Product, id=product_id)
    product_images = ProductImage.objects.filter(product=product)
    
    if request.method == 'POST':
        # Process basic product information
        product.title = request.POST.get('title')
        product.price = request.POST.get('price')
        product.sale_price = request.POST.get('sale_price') or None
        product.description = request.POST.get('description')
        product.category_id = request.POST.get('category')
        product.stock_quantity = request.POST.get('stock_quantity', 0)
        product.is_new = request.POST.get('is_new') == 'on'
        product.is_on_sale = request.POST.get('is_on_sale') == 'on'

        # Handle main product image
        if 'image' in request.FILES:
            if product.image:
                product.image.delete()
            product.image = request.FILES['image']
        
        product.save()
        
        # Handle gallery images
        # 1. Process deleted images
        if 'deleted_images' in request.POST:
            deleted_ids = request.POST.getlist('deleted_images')
            for image_id in deleted_ids:
                try:
                    image = ProductImage.objects.get(id=image_id)
                    image.delete()
                except ProductImage.DoesNotExist:
                    pass
        
        # 2. Set primary image
        if 'primary_image' in request.POST:
            primary_id = request.POST.get('primary_image')
            ProductImage.objects.filter(product=product).update(is_primary=False)
            try:
                primary_image = ProductImage.objects.get(id=primary_id)
                primary_image.is_primary = True
                primary_image.save()
            except ProductImage.DoesNotExist:
                pass
        
        # 3. Add new gallery images
        for key in request.FILES:
            if key.startswith('gallery_image_'):
                image_file = request.FILES[key]
                ProductImage.objects.create(
                    product=product,
                    image=image_file,
                    is_primary=False
                )
        
        messages.success(request, 'Product updated successfully.')
        return redirect('admin_dashboard:product_list')
    
    categories = Category.objects.all()
    return render(request, 'admin_dashboard/edit_product.html', {
        'product': product,
        'product_images': product_images,
        'categories': categories
    })

@login_required
@user_passes_test(is_admin)
def delete_product(request, product_id):
    if request.method == 'POST':
        product = get_object_or_404(Product, id=product_id)
        product.delete()
        messages.success(request, f'Product "{product.title}" has been deleted.')
    return redirect('admin_dashboard:product_list')

@api_view(['GET'])
@permission_classes([AllowAny])
def product_list_api(request):
    category_id = request.GET.get('category')
    
    if category_id:
        products = Product.objects.filter(category_id=category_id).order_by('-created_at')
    else:
        products = Product.objects.all().order_by('-created_at')
    
    data = [{
        'id': product.id,
        'title': product.title,
        'price': product.display_price(),
        'sale_price': product.display_sale_price() if product.sale_price else None,
        'description': product.description,
        'imageUrl': product.image.url if product.image else None,
        'category': {
            'id': product.category.id,
            'name': product.category.name,
            'icon': product.category.icon
        },
        'stock_quantity': product.stock_quantity,
        'is_new': product.is_new,
        'is_on_sale': product.is_on_sale,
    } for product in products]
    
    return Response({'products': data})

@api_view(['GET'])
@permission_classes([AllowAny])
def active_deals_api(request):
    try:
        current_time = timezone.now()
        active_deals = Deal.objects.filter(
            is_active=True,
            start_date__lte=current_time,
            end_date__gte=current_time
        ).select_related('product', 'product__category')

        data = {
            'deals': [{
                'id': str(deal.id),
                'discount_percentage': deal.discount_percentage,
                'discount_price': float(deal.discount_price),
                'start_date': deal.start_date.isoformat(),
                'end_date': deal.end_date.isoformat(),
                'product': {
                    'id': str(deal.product.id),
                    'title': deal.product.title,
                    'price': float(deal.product.price),
                    'description': deal.product.description,
                    'image_url': request.build_absolute_uri(deal.product.image.url) if deal.product.image else None,
                    'category': {
                        'id': deal.product.category.id,
                        'name': deal.product.category.name,
                        'icon': deal.product.category.icon
                    },
                    'stock_quantity': deal.product.stock_quantity,  # Add stock quantity to the product data
                    'is_new': deal.product.is_new,
                    'is_on_sale': True,
                    'sale_price': float(deal.discount_price),
                }
            } for deal in active_deals]
        }
        return Response(data)
    except Exception as e:
        print(f"Error in active_deals_api: {str(e)}")
        return Response(
            {'error': 'Failed to fetch deals'},
            status=status.HTTP_500_INTERNAL_SERVER_ERROR
        )

@login_required
@user_passes_test(is_admin)
def deal_list(request):
    deals = Deal.objects.all().order_by('-created_at')
    context = {
        'deals': deals,
    }
    return render(request, 'admin_dashboard/deals.html', context)

@login_required
@user_passes_test(is_admin)
def add_deal(request):
    if request.method == 'POST':
        product_id = request.POST.get('product')
        discount_percentage = request.POST.get('discount_percentage')
        start_date = request.POST.get('start_date')
        end_date = request.POST.get('end_date')
        is_active = request.POST.get('is_active') == 'on'

        try:
            product = Product.objects.get(id=product_id)
            deal = Deal.objects.create(
                product=product,
                discount_percentage=discount_percentage,
                start_date=start_date,
                end_date=end_date,
                is_active=is_active
            )
            messages.success(request, 'Deal added successfully.')
            return redirect('admin_dashboard:deal_list')
        except Exception as e:
            messages.error(request, f'Error adding deal: {str(e)}')

    products = Product.objects.all()
    return render(request, 'admin_dashboard/add_deal.html', {'products': products})

@login_required
@user_passes_test(is_admin)
def edit_deal(request, deal_id):
    deal = get_object_or_404(Deal, id=deal_id)
    
    if request.method == 'POST':
        try:
            # Get form data
            product_id = request.POST.get('product')
            discount_percentage = request.POST.get('discount_percentage')
            start_date = request.POST.get('start_date')
            end_date = request.POST.get('end_date')
            is_active = request.POST.get('is_active') == 'on'

            # Update deal
            deal.product_id = product_id
            deal.discount_percentage = int(discount_percentage)
            deal.start_date = start_date
            deal.end_date = end_date
            deal.is_active = is_active

            deal.save()
            messages.success(request, 'Deal updated successfully.')
            return redirect('admin_dashboard:deal_list')
        except Exception as e:
            messages.error(request, f'Error updating deal: {str(e)}')

    products = Product.objects.all()
    return render(request, 'admin_dashboard/edit_deal.html', {
        'deal': deal,
        'products': products
    })

@login_required
@user_passes_test(is_admin)
def toggle_deal(request, deal_id):
    if request.method == 'POST':
        deal = get_object_or_404(Deal, id=deal_id)
        deal.is_active = not deal.is_active
        
        # Add debug prints
        print(f"Toggling deal for {deal.product.title}")
        print(f"New active status: {deal.is_active}")
        print(f"Start date: {deal.start_date}")
        print(f"End date: {deal.end_date}")
        print(f"Current time: {timezone.now()}")
        
        deal.save()
        status = 'activated' if deal.is_active else 'deactivated'
        messages.success(request, f'Deal has been {status}.')
    return redirect('admin_dashboard:deal_list')

@login_required
@user_passes_test(is_admin)
def delete_deal(request, deal_id):
    if request.method == 'POST':
        deal = get_object_or_404(Deal, id=deal_id)
        deal.delete()
        messages.success(request, f'Deal has been deleted.')
    return redirect('admin_dashboard:deal_list')

@api_view(['GET'])
@permission_classes([IsAuthenticated])
def order_list_api(request):
    try:
        # Add debug logging
        print(f"Fetching orders for user: {request.user.id}")
        print(f"Authentication header: {request.META.get('HTTP_AUTHORIZATION', 'None')}")
        
        # Only return orders for the authenticated user
        orders = Order.objects.filter(user=request.user).order_by('-date_time')
        
        # Add debug logging
        print(f"Found {orders.count()} orders")
        
        serializer = OrderSerializer(orders, many=True)
        return Response(serializer.data)
    except Exception as e:
        print(f"Error in order_list_api: {str(e)}")  # Add logging
        return Response(
            {'error': 'Failed to fetch orders'},
            status=status.HTTP_500_INTERNAL_SERVER_ERROR
        )

@api_view(['GET'])
@permission_classes([AllowAny])
def order_detail_api(request, order_id):
    try:
        order = Order.objects.get(id=order_id)
        serializer = OrderSerializer(order)
        return Response(serializer.data)
    except Order.DoesNotExist:
        return Response(
            {'error': 'Order not found'}, 
            status=status.HTTP_404_NOT_FOUND
        )

@api_view(['POST'])
@permission_classes([AllowAny])
def create_order(request):
    serializer = OrderSerializer(data=request.data)
    if serializer.is_valid():
        serializer.save()
        return Response(serializer.data, status=status.HTTP_201_CREATED)
    return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

@api_view(['POST'])
@permission_classes([IsAuthenticated])
def create_user_order(request):
    try:
        data = request.data
        order = Order.objects.create(
            user=request.user,  # Always use the authenticated user
            amount=data['total_amount'],
            delivery_info={
                'phone_number': data['phone_number'],
                'wilaya': data['wilaya'],
                'address': data['address'],
                'name': data['name']
            },
            items_data=data['items']
        )
        
        # Create OrderItem instances and update stock quantities
        for item in data['items']:
            OrderItem.objects.create(
                order=order,
                product_id=item['product_id'],
                title=item['title'],
                quantity=item['quantity'],
                price=item['price'],
                image_url=item['image_url']
            )
            
            # Update product stock quantity
            try:
                product = Product.objects.get(id=item['product_id'])
                # Ensure stock doesn't go below zero
                product.stock_quantity = max(0, product.stock_quantity - item['quantity'])
                product.save()
            except Product.DoesNotExist:
                # Log error but continue processing the order
                print(f"Product with ID {item['product_id']} not found when updating stock")
        
        return Response({
            'id': order.id,
            'amount': float(order.amount),
            'date_time': order.date_time,
            'status': order.status,
            'delivery_info': order.delivery_info,
            'items': order.items_data
        }, status=status.HTTP_201_CREATED)
    except Exception as e:
        print(f"Error in create_user_order: {str(e)}")  # Add logging
        return Response(
            {'error': str(e)},
            status=status.HTTP_400_BAD_REQUEST
        )
# Create your views here.
@login_required
@user_passes_test(is_admin)
def order_list(request):
    search_query = request.GET.get('search', '').strip()
    
    # Base queryset
    orders = Order.objects.all().order_by('id')
    
    # Apply search filter if search_query exists
    if search_query:
        orders = orders.filter(delivery_info__name__icontains=search_query)
    
    # Calculate statistics
    total_orders = Order.objects.count()
    completed_orders = Order.objects.filter(status='delivered').count()
    pending_orders = Order.objects.filter(status='pending').count()
    total_revenue = sum(order.amount for order in Order.objects.all())
    
    context = {
        'orders': orders,
        'total_orders': total_orders,
        'completed_orders': completed_orders,
        'pending_orders': pending_orders,
        'total_revenue': total_revenue,
        'search_query': search_query,  # Pass the search query back to the template
        'status_choices': Order.STATUS_CHOICES,
    }
    
    return render(request, 'admin_dashboard/orders.html', context)

@login_required
@user_passes_test(is_admin)
def update_order_status(request, order_id):
    if request.method == 'POST':
        try:
            order = get_object_or_404(Order, id=order_id)
            new_status = request.POST.get('status')
            
            if new_status not in [status[0] for status in Order.STATUS_CHOICES]:
                messages.error(request, 'Invalid status')
                return redirect('admin_dashboard:order_list')
            
            old_status = order.status
            if old_status != new_status:
                order.status = new_status
                order.save()
                
                # Create notification in database
                notification = Notification.objects.create(
                    user=order.user,
                    title='Order Status Updated',
                    message=f'Your order #{order.id} status has been updated to {new_status}',
                    order_id=order.id,
                    is_read=False,
                    notification_type='ORDER_STATUS'
                )
                
                # Send FCM notification
                send_fcm_notification(order.user, notification)
                
                messages.success(request, f'Order #{order.id} status updated successfully')
            
            return redirect('admin_dashboard:order_list')
        except Exception as e:
            messages.error(request, f'Error updating order status: {str(e)}')
            return redirect('admin_dashboard:order_list')
    return redirect('admin_dashboard:order_list')

@login_required
@user_passes_test(is_admin)
def delete_order(request, order_id):
    if request.method == 'POST':
        order = get_object_or_404(Order, id=order_id)
        order_id = order.id  # Store the ID before deletion
        
        # Get all order items
        order_items = OrderItem.objects.filter(order=order)
        
        # Restore stock quantities for each item, regardless of order status
        for item in order_items:
            try:
                product = Product.objects.get(id=item.product_id)
                # Increase the stock quantity by the ordered quantity
                product.stock_quantity += item.quantity
                product.save()
                print(f"Admin restored {item.quantity} items to product {product.title} (ID: {product.id}) from {order.status} order")
            except Product.DoesNotExist:
                print(f"Product with ID {item.product_id} not found when restoring stock")
        
        order.delete()
        messages.success(request, f'Order #{order_id} has been deleted and stock quantities have been restored.')
    return redirect('admin_dashboard:order_list')

@require_http_methods(["GET"])
def order_status(request, order_id):
    try:
        order = Order.objects.get(id=order_id)
        return JsonResponse({
            'status': order.status,
            'order_id': order_id,
            'updated_at': order.updated_at.isoformat() if hasattr(order, 'updated_at') else None
        })
    except Order.DoesNotExist:
        # Add logging to track which orders are being requested but don't exist
        print(f"Status check for non-existent order ID: {order_id}")
        return JsonResponse({
            'error': f'Order not found with id: {order_id}',
            'code': 'order_not_found'
        }, status=404)
    except Exception as e:
        print(f"Error checking status for order {order_id}: {str(e)}")
        return JsonResponse({
            'error': str(e),
            'code': 'server_error'
        }, status=500)

def create_notification(user, title, message, order_id=None):
    """Helper function to create notifications"""
    return Notification.objects.create(
        user=user,
        title=title,
        message=message,
        order_id=order_id
    )

# Signal handler removed as we're handling notifications directly

@api_view(['GET'])
@permission_classes([IsAuthenticated])
def get_notifications(request):
    """Get user notifications"""
    try:
        notifications = Notification.objects.filter(user=request.user).order_by('-created_at')
        return Response({
            'notifications': [{
                'id': notif.id,
                'title': notif.title,
                'message': notif.message,
                'created_at': notif.created_at,
                'is_read': notif.is_read,
                'order_id': notif.order_id,
                'user_id': notif.user.id
            } for notif in notifications]
        })
    except Exception as e:
        print(f"Error in get_notifications: {str(e)}")
        return Response(
            {'error': 'Failed to fetch notifications'},
            status=status.HTTP_500_INTERNAL_SERVER_ERROR
        )

@api_view(['POST'])
@permission_classes([IsAuthenticated])
def mark_notification_as_read(request, notification_id):
    """Mark a notification as read"""
    try:
        notification = Notification.objects.get(id=notification_id, user=request.user)
        notification.is_read = True
        notification.save()
        return Response({'success': True})
    except Notification.DoesNotExist:
        return Response(
            {'error': 'Notification not found'},
            status=status.HTTP_404_NOT_FOUND
        )
    except Exception as e:
        print(f"Error in mark_notification_as_read: {str(e)}")
        return Response(
            {'error': 'Failed to mark notification as read'},
            status=status.HTTP_500_INTERNAL_SERVER_ERROR
        )

@api_view(['POST'])
@permission_classes([IsAuthenticated])
def create_notification_api(request):
    """Create a notification"""
    try:
        title = request.data.get('title')
        message = request.data.get('message')
        order_id = request.data.get('order_id')
        
        if not title or not message:
            return Response(
                {'error': 'Title and message are required'},
                status=status.HTTP_400_BAD_REQUEST
            )
        
        notification = Notification.objects.create(
            user=request.user,
            title=title,
            message=message,
            order_id=order_id
        )
        
        return Response({
            'id': notification.id,
            'title': notification.title,
            'message': notification.message,
            'created_at': notification.created_at,
            'is_read': notification.is_read,
            'order_id': notification.order_id,
            'user_id': notification.user.id
        }, status=status.HTTP_201_CREATED)
    except Exception as e:
        print(f"Error in create_notification_api: {str(e)}")
        return Response(
            {'error': 'Failed to create notification'},
            status=status.HTTP_500_INTERNAL_SERVER_ERROR
        )

@login_required
@user_passes_test(is_admin)
def delete_user(request, user_id):
    if request.method == 'POST':
        user = get_object_or_404(User, id=user_id)
        # Don't allow admins to delete themselves
        if user == request.user:
            messages.error(request, "You cannot delete your own account.")
        else:
            email = user.email  # Store email before deletion for the success message
            user.delete()
            messages.success(request, f'User "{email}" has been deleted.')
    return redirect('admin_dashboard:user_list')

@login_required
@user_passes_test(is_admin)
def review_list(request):
    """View to list all reviews for admin management"""
    reported_only = request.GET.get('reported') == '1'
    
    if reported_only:
        reviews = Review.objects.filter(reported=True).order_by('-created_at')
    else:
        reviews = Review.objects.all().order_by('-created_at')
        
    return render(request, 'admin_dashboard/reviews.html', {
        'reviews': reviews,
        'reported_only': reported_only
    })

@login_required
@user_passes_test(is_admin)
def toggle_review_approval(request, review_id):
    """Toggle the approval status of a review"""
    review = get_object_or_404(Review, id=review_id)
    review.is_approved = not review.is_approved
    review.save()
    
    status_text = "approved" if review.is_approved else "unapproved"
    messages.success(request, f"Review has been {status_text}.")
    
    return redirect('admin_dashboard:review_list')

@login_required
@user_passes_test(is_admin)
def delete_review(request, review_id):
    """Delete a review"""
    review = get_object_or_404(Review, id=review_id)
    product_title = review.product.title
    review.delete()
    
    messages.success(request, f"Review for '{product_title}' has been deleted.")
    return redirect('admin_dashboard:review_list')

@api_view(['GET'])
@permission_classes([AllowAny])
def product_reviews(request, product_id):
    """Get all approved reviews for a product"""
    # Update to only return approved reviews
    reviews = Review.objects.filter(
        product_id=product_id, 
        is_approved=True
    ).order_by('-created_at')
    serializer = ReviewSerializer(reviews, many=True)
    return Response(serializer.data)

@api_view(['POST'])
@permission_classes([IsAuthenticated])
def create_review(request, product_id):
    """Create or update a review for a product"""
    try:
        product = get_object_or_404(Product, id=product_id)
        
        # Check if user already reviewed this product
        review, created = Review.objects.get_or_create(
            product=product,
            user=request.user,
            defaults={
                'rating': request.data.get('rating'),
                'comment': request.data.get('comment'),
                'is_approved': True  # Reviews are approved by default
            }
        )
        
        # If review exists, update it
        if not created:
            review.rating = request.data.get('rating')
            review.comment = request.data.get('comment')
            # Keep existing approval status when updating
            review.save()
            
        return Response(ReviewSerializer(review).data, status=status.HTTP_201_CREATED)
    except Exception as e:
        return Response({'error': str(e)}, status=status.HTTP_400_BAD_REQUEST)

@api_view(['POST'])
@permission_classes([IsAuthenticated])
def report_review(request, review_id):
    """Report a review as inappropriate"""
    try:
        review = get_object_or_404(Review, id=review_id)
        
        # Mark the review as reported
        review.reported = True
        review.report_reason = request.data.get('reason', '')
        review.save()
        
        return Response({'message': 'Review reported successfully'}, status=status.HTTP_200_OK)
    except Exception as e:
        return Response({'error': str(e)}, status=status.HTTP_400_BAD_REQUEST)



@api_view(['GET'])
def get_csrf_token(request):
    """
    Returns a CSRF token for use in frontend forms
    """
    csrf_token = get_token(request)
    return JsonResponse({'csrf_token': csrf_token})

@api_view(['DELETE'])
@permission_classes([IsAuthenticated])
def delete_user_order(request, order_id):
    """
    API endpoint to delete a user's order.
    Only the user who placed the order can delete it.
    Only orders with 'pending' status can be deleted.
    """
    try:
        # Get the order and ensure it belongs to the requesting user
        order = get_object_or_404(Order, id=order_id, user=request.user)
        
        # Check if order can be deleted (only pending orders)
        if order.status.lower() != 'pending':
            return Response(
                {'error': f'Cannot cancel order with status "{order.status}". Only pending orders can be cancelled.'},
                status=status.HTTP_400_BAD_REQUEST
            )
        
        # Store the order items before deletion to restore stock
        order_items = OrderItem.objects.filter(order=order)
        
        # Restore stock quantities for each item
        for item in order_items:
            try:
                product = Product.objects.get(id=item.product_id)
                # Increase the stock quantity by the ordered quantity
                product.stock_quantity += item.quantity
                product.save()
                print(f"Restored {item.quantity} items to product {product.title} (ID: {product.id})")
            except Product.DoesNotExist:
                print(f"Product with ID {item.product_id} not found when restoring stock")
        
        # Store the order ID before deletion
        order_id_str = str(order.id)
        
        # Delete the order
        order.delete()
        
        # Return success response
        return Response(
            {'success': True, 'message': f'Order #{order_id_str} has been cancelled successfully.'},
            status=status.HTTP_200_OK
        )
        
    except Order.DoesNotExist:
        return Response(
            {'error': 'Order not found or not yours'},
            status=status.HTTP_404_NOT_FOUND
        )
    except Exception as e:
        print(f"Error in delete_user_order: {str(e)}")
        return Response(
            {'error': str(e)},
            status=status.HTTP_500_INTERNAL_SERVER_ERROR
        )

@api_view(['GET'])
@permission_classes([IsAuthenticated])
def get_wishlist(request):
    """Get user's wishlist items"""
    wishlist_items = Wishlist.objects.filter(user=request.user)
    products = [item.product for item in wishlist_items]
    
    data = [{
        'id': product.id,
        'title': product.title,
        'price': product.display_price(),
        'sale_price': product.display_sale_price() if product.sale_price else None,
        'description': product.description,
        'imageUrl': product.image.url if product.image else None,
        'category': {
            'id': product.category.id,
            'name': product.category.name,
            'icon': product.category.name.lower()  # Use lowercase name as icon
        },
        'stock_quantity': product.stock_quantity,
        'is_new': product.is_new,
        'is_on_sale': product.is_on_sale,
    } for product in products]
    
    return Response({'wishlist': data})

@api_view(['POST'])
@permission_classes([IsAuthenticated])
def toggle_wishlist(request, product_id):
    """Add/remove product from wishlist"""
    try:
        product = get_object_or_404(Product, id=product_id)
        
        # Check if product is already in wishlist
        wishlist_item = Wishlist.objects.filter(user=request.user, product=product).first()
        
        if wishlist_item:
            # Remove from wishlist
            wishlist_item.delete()
            return Response({'status': 'removed'}, status=status.HTTP_200_OK)
        else:
            # Add to wishlist
            Wishlist.objects.create(user=request.user, product=product)
            return Response({'status': 'added'}, status=status.HTTP_201_CREATED)
            
    except Exception as e:
        return Response({'error': str(e)}, status=status.HTTP_400_BAD_REQUEST)

@api_view(['GET'])
@permission_classes([IsAuthenticated])
def check_wishlist(request, product_id):
    """Check if product is in user's wishlist"""
    try:
        product = get_object_or_404(Product, id=product_id)
        is_in_wishlist = Wishlist.objects.filter(user=request.user, product=product).exists()
        
        return Response({'in_wishlist': is_in_wishlist})
    except Exception as e:
        return Response({'error': str(e)}, status=status.HTTP_400_BAD_REQUEST)

@api_view(['GET'])
@permission_classes([IsAuthenticated])
def get_user_cart(request):
    """Get the current user's cart"""
    try:
        # Get or create the user's cart
        cart, created = Cart.objects.get_or_create(user=request.user)
        
        # Get cart items with product details
        cart_items = []
        for item in cart.items.all():
            try:
                product = Product.objects.get(id=item.product_id)
                
                # Ensure image URL is absolute
                image_url = ''
                if product.image:
                    image_url = request.build_absolute_uri(product.image.url)
                
                cart_items.append({
                    'product_id': str(item.product_id),
                    'quantity': item.quantity,  # Make sure we're returning the correct quantity
                    'price': float(product.price),
                    'title': product.title,
                    'image_url': image_url,
                    'stock_quantity': product.stock_quantity
                })
                print(f"Added item to cart response: {item.product_id}, quantity: {item.quantity}")
            except Product.DoesNotExist:
                print(f"Product with ID {item.product_id} not found")
                # Skip this item or handle as needed
        
        return Response({
            'items': cart_items
        }, status=status.HTTP_200_OK)
    except Exception as e:
        print(f"Error in get_user_cart: {str(e)}")
        return Response({'error': str(e)}, status=status.HTTP_400_BAD_REQUEST)

@api_view(['POST'])
@permission_classes([IsAuthenticated])
def sync_user_cart(request):
    """Sync the user's cart with the server"""
    try:
        data = request.data
        cart_items = data.get('items', [])
        
        # Get or create user's cart
        cart, created = Cart.objects.get_or_create(user=request.user)
        
        # Clear existing items
        cart.items.all().delete()
        
        # Add new items
        for item in cart_items:
            CartItem.objects.create(
                cart=cart,
                product_id=item['product_id'],
                quantity=item['quantity']
            )
        
        return Response({'status': 'success'}, status=status.HTTP_200_OK)
    except Exception as e:
        return Response({'error': str(e)}, status=status.HTTP_400_BAD_REQUEST)

@api_view(['GET'])
@permission_classes([AllowAny])
def product_detail_api(request, product_id):
    """API endpoint to get detailed product information"""
    try:
        product = Product.objects.get(id=product_id)
    except Product.DoesNotExist:
        return Response({'error': 'Product not found'}, status=status.HTTP_404_NOT_FOUND)
    
    # Get product images
    product_images = ProductImage.objects.filter(product=product)
    
    # Serialize the product with its images
    serializer = ProductSerializer(product, context={'request': request})
    return Response(serializer.data)

@api_view(['POST'])
@permission_classes([IsAdminUser])
def add_product_image(request, product_id):
    """API endpoint to add an image to a product"""
    try:
        product = Product.objects.get(id=product_id)
    except Product.DoesNotExist:
        return Response({'error': 'Product not found'}, status=status.HTTP_404_NOT_FOUND)
        
    # Check if image is in the request
    if 'image' not in request.FILES:
        return Response({'error': 'No image provided'}, status=status.HTTP_400_BAD_REQUEST)
        
    # Get is_primary flag
    is_primary = request.data.get('is_primary', False)
    
    # If this is a primary image, set all other images to non-primary
    if is_primary:
        ProductImage.objects.filter(product=product, is_primary=True).update(is_primary=False)
    
    # Create the new image
    product_image = ProductImage.objects.create(
        product=product,
        image=request.FILES['image'],
        is_primary=is_primary
    )
    
    serializer = ProductImageSerializer(product_image)
    return Response(serializer.data, status=status.HTTP_201_CREATED)

@api_view(['DELETE'])
@permission_classes([IsAdminUser])
def delete_product_image(request, image_id):
    """API endpoint to delete a product image"""
    try:
        image = ProductImage.objects.get(id=image_id)
        image.delete()
        return Response(status=status.HTTP_204_NO_CONTENT)
    except ProductImage.DoesNotExist:
        return Response({'error': 'Image not found'}, status=status.HTTP_404_NOT_FOUND)

@api_view(['POST'])
@permission_classes([IsAdminUser])
def add_test_images(request, product_id):
    """Add test images to a product for testing purposes"""
    try:
        product = Product.objects.get(id=product_id)
    except Product.DoesNotExist:
        return Response({'error': 'Product not found'}, status=status.HTTP_404_NOT_FOUND)
    
    # Check if there are already images
    existing_images = ProductImage.objects.filter(product=product).count()
    
    if existing_images == 0:
        # Create a test image (this assumes you have a test image in your media folder)
        # In a real scenario, you would upload actual images
        test_image = ProductImage.objects.create(
            product=product,
            is_primary=True
        )
        
        # You would normally set the image field here with an actual image
        # For testing, you can use a placeholder service
        return Response({
            'message': 'Test image placeholder created. Please upload a real image.',
            'image_id': test_image.id
        })
    else:
        return Response({
            'message': f'Product already has {existing_images} images',
            'count': existing_images
        })

@api_view(['GET'])
def check_product_images(request, product_id):
    """Check if a product has gallery images"""
    try:
        product = Product.objects.get(id=product_id)
    except Product.DoesNotExist:
        return Response({'error': 'Product not found'}, status=status.HTTP_404_NOT_FOUND)
    
    # Get all images for this product
    images = ProductImage.objects.filter(product=product)
    
    # Return image details
    image_data = []
    for img in images:
        image_url = None
        if img.image:
            request_obj = request
            image_url = request_obj.build_absolute_uri(img.image.url)
        
        image_data.append({
            'id': img.id,
            'is_primary': img.is_primary,
            'image_url': image_url,
            'created_at': img.created_at
        })
    
    return Response({
        'product_id': product.id,
        'product_title': product.title,
        'main_image_url': request.build_absolute_uri(product.image.url) if product.image else None,
        'gallery_images': image_data,
        'image_count': len(image_data)
    })

@api_view(['GET'])
def product_api(request, product_id=None):
    """API endpoint to get product information"""
    try:
        if product_id:
            # Get a specific product
            product = Product.objects.get(id=product_id)
            data = ProductSerializer(product, context={'request': request}).data
            
            # Ensure stock_quantity is included and is at least 1 if not specified
            if 'stock_quantity' not in data or data['stock_quantity'] is None:
                data['stock_quantity'] = 10
            
            return Response(data)
        else:
            # Get all products
            products = Product.objects.all()
            serialized_products = ProductSerializer(products, many=True, context={'request': request}).data
            
            # Ensure stock_quantity is included for each product
            for product in serialized_products:
                if 'stock_quantity' not in product or product['stock_quantity'] is None:
                    product['stock_quantity'] = 10
            
            return Response({'products': serialized_products})
    except Product.DoesNotExist:
        return Response({'error': 'Product not found'}, status=status.HTTP_404_NOT_FOUND)
    except Exception as e:
        return Response({'error': str(e)}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)

@api_view(['POST'])
@permission_classes([IsAuthenticated])
def add_cart_item(request):
    """Add a single item to the user's cart"""
    try:
        data = request.data
        product_id = data.get('product_id')
        quantity = int(data.get('quantity', 1))
        
        print(f"Adding item to cart: product_id={product_id}, quantity={quantity}")
        
        if not product_id:
            return Response({'error': 'Product ID is required'}, status=status.HTTP_400_BAD_REQUEST)
        
        # Get or create user's cart
        cart, created = Cart.objects.get_or_create(user=request.user)
        
        # Check if item already exists
        cart_item = CartItem.objects.filter(cart=cart, product_id=product_id).first()
        
        if cart_item:
            # Update quantity
            cart_item.quantity = quantity
            cart_item.save()
            print(f"Updated cart item quantity: {cart_item.quantity}")
        else:
            # Create new item
            cart_item = CartItem.objects.create(
                cart=cart,
                product_id=product_id,
                quantity=quantity
            )
            print(f"Created new cart item with quantity: {cart_item.quantity}")
        
        return Response({'status': 'success', 'quantity': cart_item.quantity}, status=status.HTTP_200_OK)
    except Exception as e:
        print(f"Error in add_cart_item: {str(e)}")
        return Response({'error': str(e)}, status=status.HTTP_400_BAD_REQUEST)

@api_view(['DELETE'])
@permission_classes([IsAuthenticated])
def remove_cart_item(request, product_id):
    """API endpoint to remove an item from the user's cart"""
    try:
        # Get the user's cart
        cart = Cart.objects.get(user=request.user)
        
        # Find the cart item
        cart_item = CartItem.objects.filter(cart=cart, product_id=product_id).first()
        
        if cart_item:
            # Remove the item
            cart_item.delete()
            return Response({'status': 'success', 'message': 'Item removed from cart'}, status=status.HTTP_200_OK)
        else:
            return Response({'status': 'error', 'message': 'Item not found in cart'}, status=status.HTTP_404_NOT_FOUND)
    except Cart.DoesNotExist:
        return Response({'status': 'error', 'message': 'Cart not found'}, status=status.HTTP_404_NOT_FOUND)
    except Exception as e:
        return Response({'status': 'error', 'message': str(e)}, status=status.HTTP_400_BAD_REQUEST)

@api_view(['DELETE'])
@permission_classes([IsAuthenticated])
def clear_cart(request):
    """API endpoint to clear the user's cart"""
    try:
        # Get the user's cart
        cart = Cart.objects.get(user=request.user)
        
        # Clear all items
        cart.items.all().delete()
        
        return Response({'status': 'success', 'message': 'Cart cleared'}, status=status.HTTP_200_OK)
    except Cart.DoesNotExist:
        return Response({'status': 'error', 'message': 'Cart not found'}, status=status.HTTP_404_NOT_FOUND)
    except Exception as e:
        print(f"Error clearing cart: {str(e)}")
        return Response({'status': 'error', 'message': str(e)}, status=status.HTTP_400_BAD_REQUEST)

@api_view(['PUT'])
@permission_classes([IsAuthenticated])
def update_cart_item(request, product_id):
    """API endpoint to update an item in the user's cart"""
    try:
        data = request.data
        quantity = int(data.get('quantity', 1))
        
        if quantity <= 0:
            return Response({'status': 'error', 'message': 'Quantity must be positive'}, status=status.HTTP_400_BAD_REQUEST)
        
        # Get the user's cart
        cart = Cart.objects.get(user=request.user)
        
        # Find the cart item
        cart_item = CartItem.objects.filter(cart=cart, product_id=product_id).first()
        
        if cart_item:
            # Update the quantity
            cart_item.quantity = quantity
            cart_item.save()
            return Response({'status': 'success', 'message': 'Item quantity updated'}, status=status.HTTP_200_OK)
        else:
            return Response({'status': 'error', 'message': 'Item not found in cart'}, status=status.HTTP_404_NOT_FOUND)
    except Cart.DoesNotExist:
        return Response({'status': 'error', 'message': 'Cart not found'}, status=status.HTTP_404_NOT_FOUND)
    except Exception as e:
        print(f"Error updating cart item: {str(e)}")
        return Response({'status': 'error', 'message': str(e)}, status=status.HTTP_400_BAD_REQUEST)

@api_view(['GET'])
def test_endpoint(request):
    return Response({'message': 'Test endpoint works!'})

@api_view(['DELETE'])
@permission_classes([IsAuthenticated])
def delete_user_review(request, review_id):
    """
    API endpoint to delete a user's own review.
    Only the user who created the review can delete it.
    """
    try:
        # Get the review and ensure it belongs to the requesting user
        review = get_object_or_404(Review, id=review_id, user=request.user)
        
        # Delete the review
        product_title = review.product.title
        review.delete()
        
        return Response(
            {'message': f'Your review for "{product_title}" has been deleted.'},
            status=status.HTTP_200_OK
        )
    except Review.DoesNotExist:
        return Response(
            {'error': 'Review not found or you do not have permission to delete it.'},
            status=status.HTTP_404_NOT_FOUND
        )
    except Exception as e:
        print(f"Error in delete_user_review: {str(e)}")
        return Response({'error': str(e)}, status=status.HTTP_400_BAD_REQUEST)

def send_fcm_notification(user, notification):
    """Send FCM notification to a user"""
    try:
        print(f"Attempting to send FCM notification to user {user.email} for notification ID {notification.id}")
        
        # Get user's FCM tokens
        fcm_tokens = FCMToken.objects.filter(user=user).values_list('token', flat=True)
        
        if not fcm_tokens:
            print(f"No FCM tokens found for user {user.email}")
            return
        
        print(f"Found {len(fcm_tokens)} FCM tokens for user {user.email}")
        
        # Create message
        message = messaging.MulticastMessage(
            tokens=list(fcm_tokens),
            notification=messaging.Notification(
                title=notification.title,
                body=notification.message,
            ),
            data={
                'orderId': str(notification.order_id),
                'notificationId': str(notification.id),
                'type': 'order_status_update',
                'userId': str(user.id),
                'userOrderNumber': str(notification.order_id),
            },
            android=messaging.AndroidConfig(
                priority='high',
                notification=messaging.AndroidNotification(
                    icon='ic_notification',
                    color='#2196F3',
                    channel_id='order_updates',
                ),
            ),
            apns=messaging.APNSConfig(
                payload=messaging.APNSPayload(
                    aps=messaging.Aps(
                        badge=1,
                        sound='default',
                    ),
                ),
            ),
        )
        
        print(f"Sending FCM message: {message}")
        
        # Send message
        response = messaging.send_multicast(message)
        print(f"Successfully sent message: {response.success_count} successful, {response.failure_count} failed")
        
        # Log failures if any
        if response.failure_count > 0:
            for idx, resp in enumerate(response.responses):
                if not resp.success:
                    print(f"Failed to send message to token {fcm_tokens[idx]}: {resp.exception}")
                    
        return response.success_count > 0
    except Exception as e:
        print(f"Error sending FCM notification: {str(e)}")
        print(f"Error details: {type(e).__name__}")
        import traceback
        traceback.print_exc()
        return False

# Connect the send_fcm_notification function to the post_save signal of the Notification model
@receiver(post_save, sender=Notification)
def handle_notification(sender, instance, created, **kwargs):
    if created:
        send_fcm_notification(instance.user, instance)

@api_view(['GET'])
@permission_classes([IsAuthenticated])
def order_status_updates(request):
    """Get status updates for user's orders"""
    try:
        # Get all orders for the current user
        orders = Order.objects.filter(user=request.user).order_by('-date_time')
        
        # Serialize orders
        orders_data = []
        for order in orders:
            orders_data.append({
                'id': str(order.id),
                'user_order_number': order.user_order_number,
                'amount': float(order.amount),
                'date_time': order.date_time.isoformat(),
                'status': order.status,
                'delivery_info': order.delivery_info,
                # Add other fields as needed
            })
        
        return JsonResponse({'orders': orders_data}, status=200)
    except Exception as e:
        print(f"Error getting order status updates: {str(e)}")
        return JsonResponse(
            {'error': 'Failed to get order status updates'},
            status=500
        )

def send_order_status_notification(order):
    """Send FCM notification for order status update"""
    try:
        # Get user's FCM tokens
        fcm_tokens = FCMToken.objects.filter(user=order.user).values_list('token', flat=True)
        
        if not fcm_tokens:
            print(f"No FCM tokens found for user {order.user.email}")
            return
        
        # Create message
        status_message = get_status_message(order.status)
        
        message = messaging.MulticastMessage(
            tokens=list(fcm_tokens),
            notification=messaging.Notification(
                title="Order Status Update",
                body=f"Your order #{order.user_order_number} has been {status_message}"
            ),
            data={
                'orderId': str(order.id),
                'userOrderNumber': str(order.user_order_number),
                'userId': str(order.user.id),
                'status': order.status,
                'type': 'order_update'
            }
        )
        
        # Send message
        response = messaging.send_multicast(message)
        print(f"Successfully sent message: {response.success_count} success, {response.failure_count} failure")
        
    except Exception as e:
        print(f"Error sending FCM notification: {str(e)}")

def get_status_message(status):
    """Get human-readable status message"""
    status = status.lower()
    if status == 'pending':
        return "received and is pending"
    elif status == 'processing':
        return "being processed"
    elif status == 'shipped':
        return "shipped"
    elif status == 'delivered':
        return "delivered"
    elif status == 'cancelled':
        return "cancelled"
    else:
        return f"updated to {status}"

@api_view(['POST'])
@permission_classes([IsAuthenticated])
def test_fcm_notification(request):
    """Test sending FCM notification to the current user"""
    try:
        user = request.user
        print(f"Attempting to send test FCM notification to user {user.email}")
        
        # Get user's FCM tokens
        fcm_tokens = FCMToken.objects.filter(user=user).values_list('token', flat=True)
        
        if not fcm_tokens:
            print(f"No FCM tokens found for user {user.email}")
            return Response(
                {'success': False, 'message': 'No FCM tokens found for this user'},
                status=status.HTTP_400_BAD_REQUEST
            )
        
        print(f"Found {len(fcm_tokens)} FCM tokens for user {user.email}")
        
        # Create a test notification in the database
        notification = Notification.objects.create(
            user=user,
            title='Test Notification',
            message='This is a test notification from the server',
            is_read=False,
            order_id=None
        )
        
        # Create message
        message = messaging.MulticastMessage(
            tokens=list(fcm_tokens),
            notification=messaging.Notification(
                title='Test Notification',
                body='This is a test notification from the server',
            ),
            data={
                'notificationId': str(notification.id),
                'type': 'test_notification',
                'userId': str(user.id),
            },
            android=messaging.AndroidConfig(
                priority='high',
                notification=messaging.AndroidNotification(
                    icon='ic_notification',
                    color='#2196F3',
                    channel_id='order_updates',
                ),
            ),
            apns=messaging.APNSConfig(
                payload=messaging.APNSPayload(
                    aps=messaging.Aps(
                        badge=1,
                        sound='default',
                    ),
                ),
            ),
        )
        
        print(f"Sending FCM test message to tokens: {[t[:10] + '...' for t in fcm_tokens]}")
        
        # Send message
        response = messaging.send_multicast(message)
        print(f"FCM response: {response.success_count} successful, {response.failure_count} failed")
        
        # Log failures if any
        if response.failure_count > 0:
            failures = []
            for idx, resp in enumerate(response.responses):
                if not resp.success:
                    error = f"Failed to send to token {fcm_tokens[idx][:10]}...: {resp.exception}"
                    print(error)
                    failures.append(error)
            
            if response.success_count == 0:
                return Response(
                    {'success': False, 'message': f'Failed to send notification: {failures[0]}'},
                    status=status.HTTP_500_INTERNAL_SERVER_ERROR
                )
        
        return Response({
            'success': response.success_count > 0,
            'message': f'Test notification sent successfully to {response.success_count} device(s)'
        })
    except Exception as e:
        print(f"Error sending test FCM notification: {str(e)}")
        import traceback
        traceback.print_exc()
        return Response(
            {'success': False, 'message': f'Error: {str(e)}'},
            status=status.HTTP_500_INTERNAL_SERVER_ERROR
        )

