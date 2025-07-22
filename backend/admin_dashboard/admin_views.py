from django.contrib.auth import REDIRECT_FIELD_NAME
from django.contrib.admin.forms import AdminAuthenticationForm
from django.contrib.auth.views import LoginView
from django.shortcuts import redirect

class AdminLoginView(LoginView):
    template_name = 'admin/login.html'
    form_class = AdminAuthenticationForm
    
    def get_success_url(self):
        return '/dashboard/'  # Always redirect to dashboard after successful login
        
    def dispatch(self, request, *args, **kwargs):
        if request.user.is_authenticated and request.user.is_staff:
            return redirect('admin_dashboard:dashboard')
        return super().dispatch(request, *args, **kwargs)
    
    def form_valid(self, form):
        """Debug login process"""
        response = super().form_valid(form)
        user = form.get_user()
        print(f"Login successful for user: {user.username}")
        print(f"User is_staff: {user.is_staff}")
        print(f"User is_active: {user.is_active}")
        print(f"Redirecting to: {self.get_success_url()}")
        return response
