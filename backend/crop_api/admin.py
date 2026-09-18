from django.contrib import admin
from django.contrib.auth.admin import UserAdmin
from .models import Farmer, Scan, Notification, Device

@admin.register(Farmer)
class FarmerAdmin(UserAdmin):
    fieldsets = UserAdmin.fieldsets + (('Farm',{'fields':('full_name','village','farm_name','latitude','longitude','share_reports','nearby_alerts','alert_radius_km')}),)
    list_display = ['email','full_name','village','is_active']

@admin.register(Scan)
class ScanAdmin(admin.ModelAdmin):
    list_display = ['id','user','condition','confidence','status','outcome','created_at']
    list_filter = ['status','crop','outcome','created_at']
    search_fields = ['user__email','condition']
    readonly_fields = ['id','created_at','confidence','predicted_label']

@admin.register(Notification)
class NotificationAdmin(admin.ModelAdmin):
    list_display = ['title','user','kind','created_at','read_at','pushed_at']
    list_filter = ['kind']

admin.site.register(Device)
admin.site.site_header = 'CropCare AI Administration'
admin.site.site_title = 'CropCare AI'
