from django.urls import path
from django.contrib.auth import views as auth_views
from django.contrib.admin.views.decorators import staff_member_required
from . import views

app_name = 'admin_dashboard'

urlpatterns = [
    path('', views.dashboard, name='dashboard'),
    path('categories/', views.category_list, name='category_list'),
    path('users/', views.user_list, name='user_list'),
    path('users/<int:user_id>/toggle/', views.toggle_user_status, name='toggle_user_status'),
    path('users/<int:user_id>/delete/', views.delete_user, name='delete_user'),
    path('categories/<int:category_id>/delete/', views.delete_category, name='delete_category'),
   
    path('api/categories/', views.category_list_api, name='category_list_api'),
    path('products/', views.product_list, name='product_list'),
    path('products/add/', views.add_product, name='add_product'),
    path('products/<int:product_id>/edit/', views.edit_product, name='edit_product'),
    path('products/<int:product_id>/delete/', views.delete_product, name='delete_product'),
    path('deals/', views.deal_list, name='deal_list'),
    path('deals/add/', views.add_deal, name='add_deal'),
    path('deals/<int:deal_id>/edit/', views.edit_deal, name='edit_deal'),
    path('deals/<int:deal_id>/toggle/', views.toggle_deal, name='toggle_deal'),
    path('deals/<int:deal_id>/delete/', views.delete_deal, name='delete_deal'),
    path('api/products/', views.product_list_api, name='product_list_api'),
    path('api/deals/active/', views.active_deals_api, name='active_deals_api'),
    path('api/orders/', views.order_list_api, name='order_list_api'),
    path('api/orders/<int:order_id>/', views.order_detail_api, name='order_detail_api'),
    path('orders/', views.order_list, name='order_list'),
    path('orders/<int:order_id>/update-status/', views.update_order_status, name='update_order_status'),
    path('orders/<int:order_id>/delete/', views.delete_order, name='delete_order'),
    path('api/orders/status/<int:order_id>/', views.order_status, name='order_status'),
    path('api/notifications/', views.get_notifications, name='get_notifications'),
    path('api/notifications/<int:notification_id>/read/', views.mark_notification_as_read, name='mark_notification_as_read'),
    path('api/notifications/create/', views.create_notification_api, name='create_notification_api'),
    path('reviews/', views.review_list, name='review_list'),
    path('reviews/<int:review_id>/toggle-approval/', views.toggle_review_approval, name='toggle_review_approval'),
    path('reviews/<int:review_id>/delete/', views.delete_user_review, name='delete_review'),
    path('api/reviews/<int:review_id>/report/', views.report_review, name='report_review'),
    path('api/reviews/<int:review_id>/delete/', views.delete_user_review, name='delete_user_review'),
    path('api/csrf-token/', views.get_csrf_token, name='get_csrf_token'),
    path('admin/csrf-token/', views.get_csrf_token, name='get_csrf_token'),
    path('api/orders/<str:order_id>/', views.delete_user_order, name='delete_user_order'),
    path('api/products/<int:product_id>/', views.product_detail_api, name='product_detail_api'),
    path('api/products/<int:product_id>/images/add/', views.add_product_image, name='add_product_image'),
    path('api/products/images/<int:image_id>/delete/', views.delete_product_image, name='delete_product_image'),
    # Wishlist endpoints
    path('api/wishlist/', views.get_wishlist, name='get_wishlist'),
    path('api/wishlist/toggle/<str:product_id>/', views.toggle_wishlist, name='toggle_wishlist'),
    path('api/wishlist/check/<str:product_id>/', views.check_wishlist, name='check_wishlist'),
    path('test-fcm-notification/', views.test_fcm_notification, name='test_fcm_notification'),
]












