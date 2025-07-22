
from django.contrib import admin
from django.urls import path, include
from django.contrib.auth import views as auth_views
from django.shortcuts import redirect
from admin_dashboard.admin_views import AdminLoginView
from .admin import CustomAdminSite
from admin_dashboard.views import category_list_api, product_list_api, active_deals_api
from django.conf import settings
from django.conf.urls.static import static
from admin_dashboard import views as admin_views

# Initialize the custom admin site
admin.site = CustomAdminSite()

urlpatterns = [
    path('admin/', admin.site.urls),
    path('auth/', include('authentication.urls')),  # Make sure this matches your API service URL
    path('dashboard/', include('admin_dashboard.urls')),
    
    # Add api prefix to match frontend expectations
    path('api/categories/', category_list_api, name='categories'),
    path('api/products/', product_list_api, name='product-list'),
    path('api/deals/active/', active_deals_api, name='active-deals'),
    path('api/orders/list/', admin_views.order_list_api, name='order-list'),
    path('api/orders/create/', admin_views.create_user_order, name='create-user-order'),
    path('admin/dashboard/orders/<int:order_id>/update-status/', admin_views.update_order_status, name='update_order_status'),
    path('api/products/<int:product_id>/reviews/', admin_views.product_reviews, name='product-reviews'),
    path('api/products/<int:product_id>/reviews/create/', admin_views.create_review, name='create-review'),
    path('api/reviews/<int:review_id>/report/', admin_views.report_review, name='report-review'),
    path('api/orders/<str:order_id>/delete/', admin_views.delete_user_order, name='delete_user_order'),
    path('api/reviews/<int:review_id>/delete/', admin_views.delete_user_review, name='delete_user_review'),
    # Custom admin login/logout
    path('admin/login/', AdminLoginView.as_view(), name='admin_login'),
    path('admin/logout/', auth_views.LogoutView.as_view(
        template_name='admin/logged_out.html',
        next_page='admin_login'
    ), name='admin_logout'),
    path('', lambda request: redirect('admin_dashboard:dashboard'), name='root'),
    # Add these URLs
    path('api/wishlist/', admin_views.get_wishlist, name='get-wishlist'),
    path('api/wishlist/toggle/<int:product_id>/', admin_views.toggle_wishlist, name='toggle-wishlist'),
    path('api/wishlist/check/<int:product_id>/', admin_views.check_wishlist, name='check-wishlist'),
    path('api/cart/', admin_views.get_user_cart, name='get-user-cart'),
    path('api/cart/sync/', admin_views.sync_user_cart, name='sync-user-cart'),
    path('api/cart/add-item/', admin_views.add_cart_item, name='add-cart-item'),
    path('api/cart/remove-item/<str:product_id>/', admin_views.remove_cart_item, name='remove-cart-item'),
    path('api/cart/clear/', admin_views.clear_cart, name='clear-cart'),
    path('api/cart/update-item/<str:product_id>/', admin_views.update_cart_item, name='update-cart-item'),
    path('api/products/<int:product_id>/details/', admin_views.product_detail_api, name='product-detail'),
    path('api/products/<int:product_id>/images/add/', admin_views.add_product_image, name='add-product-image'),
    path('api/products/images/<int:image_id>/delete/', admin_views.delete_product_image, name='delete-product-image'),
    path('api/products/<int:product_id>/add-test-images/', admin_views.add_test_images, name='add-test-images'),
    path('api/products/<int:product_id>/check-images/', admin_views.check_product_images, name='check-product-images'),
    path('api/orders/status-updates/', admin_views.order_status_updates, name='order_status_updates'),
]

if settings.DEBUG:
    urlpatterns += static(settings.MEDIA_URL, document_root=settings.MEDIA_ROOT)
