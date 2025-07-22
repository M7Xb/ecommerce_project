from django.contrib import admin
from django.shortcuts import redirect
from django.contrib.admin.sites import AdminSite

class CustomAdminSite(AdminSite):
    def login(self, request, extra_context=None):
        if request.method == 'POST':
            from django.contrib.auth.forms import AuthenticationForm
            form = AuthenticationForm(request, data=request.POST)
            if form.is_valid():
                from django.contrib.auth import login
                login(request, form.get_user())
                return redirect('admin_dashboard:dashboard')
        return super().login(request, extra_context)

admin.site = CustomAdminSite()

