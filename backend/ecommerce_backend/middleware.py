class CsrfExemptMiddleware:
    def __init__(self, get_response):
        self.get_response = get_response

    def __call__(self, request):
        # Check if the request path starts with any of these prefixes
        exempt_prefixes = ['/api/', '/auth/', '/login/', '/register/', '/mobile/']
        for prefix in exempt_prefixes:
            if request.path.startswith(prefix):
                setattr(request, '_dont_enforce_csrf_checks', True)
                break
        return self.get_response(request)