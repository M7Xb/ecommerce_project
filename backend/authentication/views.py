from rest_framework import status
from rest_framework.response import Response
from rest_framework.views import APIView
from rest_framework_simplejwt.tokens import RefreshToken
from django.contrib.auth import get_user_model
from .serializers import UserSerializer, UserLoginSerializer
from rest_framework.permissions import AllowAny, IsAuthenticated
from django.views.decorators.csrf import csrf_exempt
from django.utils.decorators import method_decorator
import logging
from rest_framework.parsers import MultiPartParser, FormParser, JSONParser
from rest_framework.decorators import api_view, permission_classes
from .models import FCMToken

logger = logging.getLogger(__name__)

User = get_user_model()

class TestConnectionView(APIView):
    permission_classes = [AllowAny]
    
    def get(self, request):
        return Response({"message": "Connection successful"}, status=status.HTTP_200_OK)

class RegisterView(APIView):
    permission_classes = [AllowAny]

    def post(self, request):
        serializer = UserSerializer(data=request.data)
        if serializer.is_valid():
            user = serializer.save()
            refresh = RefreshToken.for_user(user)
            return Response({
                'refresh': str(refresh),
                'access': str(refresh.access_token),
                'user': UserSerializer(user).data
            }, status=status.HTTP_201_CREATED)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

@csrf_exempt
@api_view(['POST'])
@permission_classes([AllowAny])
def login_view(request):
    serializer = UserLoginSerializer(data=request.data)
    if serializer.is_valid():
        email = serializer.validated_data['email']
        password = serializer.validated_data['password']
        
        try:
            user = User.objects.filter(email=email).first()
            
            if user and user.check_password(password):
                try:
                    refresh = RefreshToken.for_user(user)
                    
                    # Safely handle profile image
                    profile_image_url = None
                    if user.profile_image and hasattr(user.profile_image, 'url'):
                        try:
                            profile_image_url = request.build_absolute_uri(user.profile_image.url)
                        except Exception as img_err:
                            print(f"Error getting profile image URL: {img_err}")
                    
                    return Response({
                        'refresh': str(refresh),
                        'access': str(refresh.access_token),
                        'user': {
                            'id': user.id,
                            'email': user.email,
                            'first_name': user.first_name,
                            'last_name': user.last_name,
                            'profile_image': profile_image_url,
                            'address': user.address,
                            'wilaya': user.wilaya,
                            'phone': user.phone,
                        }
                    })
                except Exception as e:
                    return Response({'error': f'Error generating token: {str(e)}'}, status=500)
            else:
                return Response({'error': 'Invalid credentials'}, status=401)
        except Exception as e:
            return Response({'error': f'Login error: {str(e)}'}, status=500)
    return Response(serializer.errors, status=400)

@method_decorator(csrf_exempt, name='dispatch')
class UpdateProfileView(APIView):
    permission_classes = [IsAuthenticated]
    parser_classes = [MultiPartParser, FormParser, JSONParser]

    def put(self, request):
        logger.info(f"Received profile update request. Data: {request.data}")
        
        user = request.user
        try:
            # Log the incoming data
            logger.info(f"Updating user {user.email} with data: {request.data}")
            
            # Get the data with default values
            first_name = request.data.get('first_name')
            last_name = request.data.get('last_name')
            phone = request.data.get('phone')
            profile_image = request.FILES.get('profile_image')

            if first_name is not None:
                user.first_name = first_name
            if last_name is not None:
                user.last_name = last_name
            if phone is not None:
                user.phone = phone
            if profile_image is not None:
                # Save the profile image
                user.profile_image = profile_image

            user.save()

            # Get the profile image URL
            profile_image_url = None
            if user.profile_image:
                profile_image_url = request.build_absolute_uri(user.profile_image.url)

            response_data = {
                'user': {
                    'id': user.id,
                    'email': user.email,
                    'first_name': user.first_name,
                    'last_name': user.last_name,
                    'phone': getattr(user, 'phone', None),
                    'profile_image': profile_image_url,
                }
            }
            
            logger.info(f"Profile updated successfully. Response: {response_data}")
            return Response(response_data, status=status.HTTP_200_OK)
            
        except Exception as e:
            logger.error(f"Error updating profile: {str(e)}")
            return Response({
                'detail': str(e)
            }, status=status.HTTP_400_BAD_REQUEST)

class UpdateShippingAddressView(APIView):
    permission_classes = [IsAuthenticated]

    def put(self, request):
        logger.info(f"Received shipping address update request. Data: {request.data}")
        
        user = request.user
        try:
            # Log the incoming data
            logger.info(f"Updating shipping address for user {user.email} with data: {request.data}")
            
            # Get the data
            address = request.data.get('address')
            wilaya = request.data.get('wilaya')
            phone = request.data.get('phone')

            # Validate required fields
            if not all([address, wilaya, phone]):
                return Response({
                    'detail': 'Address, wilaya, and phone are required fields'
                }, status=status.HTTP_400_BAD_REQUEST)

            # Update user fields
            user.address = address
            user.wilaya = wilaya
            user.phone = phone
            user.save()

            response_data = {
                'user': {
                    'id': user.id,
                    'email': user.email,
                    'first_name': user.first_name,
                    'last_name': user.last_name,
                    'phone': user.phone,
                    'address': user.address,
                    'wilaya': user.wilaya,
                }
            }
            
            logger.info(f"Shipping address updated successfully. Response: {response_data}")
            return Response(response_data, status=status.HTTP_200_OK)
            
        except Exception as e:
            logger.error(f"Error updating shipping address: {str(e)}")
            return Response({
                'detail': str(e)
            }, status=status.HTTP_400_BAD_REQUEST)

class UserProfileView(APIView):
    permission_classes = [IsAuthenticated]
    
    def get(self, request):
        user = request.user
        profile_image_url = None
        if user.profile_image and hasattr(user.profile_image, 'url'):
            try:
                profile_image_url = request.build_absolute_uri(user.profile_image.url)
            except Exception as img_err:
                print(f"Error getting profile image URL: {img_err}")
        
        return Response({
            'user': {
                'id': user.id,
                'email': user.email,
                'first_name': user.first_name,
                'last_name': user.last_name,
                'profile_image': profile_image_url,
                'address': user.address,
                'wilaya': user.wilaya,
                'phone': user.phone,
            }
        })

@api_view(['POST'])
@permission_classes([IsAuthenticated])
def update_fcm_token(request):
    """Update the FCM token for a user"""
    try:
        user = request.user
        token = request.data.get('token')
        
        if not token:
            return Response({'error': 'Token is required'}, status=status.HTTP_400_BAD_REQUEST)
        
        # Update or create FCM token
        FCMToken.objects.update_or_create(
            token=token,
            defaults={'user': user}
        )
        
        return Response({'success': True}, status=status.HTTP_200_OK)
    except Exception as e:
        print(f"Error updating FCM token: {str(e)}")
        return Response(
            {'error': 'Failed to update FCM token'},
            status=status.HTTP_500_INTERNAL_SERVER_ERROR
        )

@api_view(['POST'])
@permission_classes([IsAuthenticated])
def register_fcm_token(request):
    """Register FCM token for the current user"""
    try:
        user = request.user
        token = request.data.get('token')
        
        if not token:
            return Response(
                {'error': 'Token is required'},
                status=status.HTTP_400_BAD_REQUEST
            )
        
        # Check if token already exists for this user
        existing_token = FCMToken.objects.filter(user=user, token=token).first()
        if existing_token:
            # Token already registered
            return Response({'message': 'Token already registered'}, status=status.HTTP_200_OK)
        
        # Create new token
        FCMToken.objects.create(user=user, token=token)
        
        return Response({'message': 'Token registered successfully'}, status=status.HTTP_201_CREATED)
    except Exception as e:
        print(f"Error registering FCM token: {str(e)}")
        return Response(
            {'error': 'Failed to register token'},
            status=status.HTTP_500_INTERNAL_SERVER_ERROR
        )

@api_view(['GET'])
@permission_classes([IsAuthenticated])
def check_fcm_token(request):
    """Check if the user has FCM tokens registered"""
    try:
        user = request.user
        tokens = FCMToken.objects.filter(user=user)
        token_count = tokens.count()
        
        return Response({
            'has_token': token_count > 0,
            'token_count': token_count,
            'tokens': [t.token[:10] + '...' for t in tokens]  # Only show first 10 chars for security
        }, status=status.HTTP_200_OK)
    except Exception as e:
        print(f"Error checking FCM token: {str(e)}")
        return Response(
            {'error': 'Failed to check FCM token'},
            status=status.HTTP_500_INTERNAL_SERVER_ERROR
        )

