from django.urls import path
from . import views as v
urlpatterns = [
    path('health/',v.HealthView.as_view()), path('auth/register/',v.RegisterView.as_view()),
    path('auth/login/',v.LoginView.as_view()), path('auth/logout/',v.LogoutView.as_view()),
    path('auth/password/',v.PasswordView.as_view()), path('profile/',v.ProfileView.as_view()),
    path('scans/',v.ScanListView.as_view()), path('scans/<uuid:pk>/',v.ScanDetailView.as_view()),
    path('scans/<uuid:pk>/image/',v.ScanImageView.as_view()), path('reminders/',v.ReminderView.as_view()),
    path('notifications/',v.NotificationListView.as_view()),path('notifications/<uuid:pk>/read/',v.ReadNotificationView.as_view()),
    path('nearby/',v.NearbyView.as_view()),path('weather/',v.WeatherView.as_view()),path('devices/',v.DeviceView.as_view()),
]
