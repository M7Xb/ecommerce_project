from django.shortcuts import redirect
from django.urls import reverse

class AdminAccessMiddleware:
    def __init__(self, get_response):
        self.get_response = get_response

    def __call__(self, request):
        if request.path.startswith('/admin/') and not request.path.startswith('/admin/login/'):
            if not request.user.is_authenticated:
                return redirect('admin_login')
            if not request.user.is_staff:
                return redirect('admin_dashboard:dashboard')
        return self.get_response(request)