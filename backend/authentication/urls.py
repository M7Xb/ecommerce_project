from django.urls import path
from . import views

urlpatterns = [
    path('register/', views.RegisterView.as_view(), name='register'),
    path('login/', views.login_view, name='login'),
    path('profile/update/', views.UpdateProfileView.as_view(), name='update_profile'),
    path('shipping-address/update/', views.UpdateShippingAddressView.as_view(), name='update_shipping_address'),
    path('user-profile/', views.UserProfileView.as_view(), name='user_profile'),
    path('fcm-token/', views.update_fcm_token, name='update_fcm_token'),
    path('register-fcm-token/', views.register_fcm_token, name='register_fcm_token'),
    path('check-fcm-token/', views.check_fcm_token, name='check_fcm_token'),
]















