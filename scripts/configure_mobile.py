"""Apply native permissions after flutter create; safe to run again."""
from pathlib import Path
import plistlib
import re

ROOT = Path(__file__).resolve().parents[1] / 'mobile'
manifest = ROOT / 'android/app/src/main/AndroidManifest.xml'
if not manifest.exists():
    raise SystemExit('First run: cd mobile && flutter create --platforms=android,ios --org com.cropcare --project-name cropcare_ai .')
text = manifest.read_text()
permissions = ['INTERNET', 'ACCESS_COARSE_LOCATION', 'ACCESS_FINE_LOCATION', 'RECEIVE_BOOT_COMPLETED', 'POST_NOTIFICATIONS']
for permission in permissions:
    full = 'android.permission.' + permission
    if full not in text:
        text = text.replace('<application', f'<uses-permission android:name="{full}"/>\n    <application', 1)
if 'ScheduledNotificationReceiver' not in text:
    text = text.replace('</application>', '''<receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver" />
        <receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver">
            <intent-filter>
                <action android:name="android.intent.action.BOOT_COMPLETED"/>
                <action android:name="android.intent.action.MY_PACKAGE_REPLACED"/>
                <action android:name="android.intent.action.QUICKBOOT_POWERON"/>
                <action android:name="com.htc.intent.action.QUICKBOOT_POWERON"/>
            </intent-filter>
        </receiver>
        <meta-data android:name="com.google.firebase.messaging.default_notification_channel_id" android:value="cropcare_alerts"/>
        <meta-data android:name="com.google.firebase.messaging.default_notification_icon" android:resource="@drawable/ic_notification"/>
    </application>''')
text = text.replace('android:label="cropcare_ai"','android:label="CropCare AI"')
if 'android:allowBackup' not in text:
    text = text.replace('<application', '<application android:allowBackup="false"', 1)
text = text.replace('android:icon="@mipmap/ic_launcher"', 'android:icon="@drawable/ic_cropcare"')
manifest.write_text(text)
for variant in ['debug', 'profile']:
    path = ROOT / f'android/app/src/{variant}/AndroidManifest.xml'
    path.parent.mkdir(parents=True,exist_ok=True)
    path.write_text('''<manifest xmlns:android="http://schemas.android.com/apk/res/android">
  <uses-permission android:name="android.permission.INTERNET"/>
  <application android:usesCleartextTraffic="true"/>
</manifest>
''')
drawable = ROOT / 'android/app/src/main/res/drawable/ic_notification.xml'
drawable.parent.mkdir(parents=True,exist_ok=True)
drawable.write_text('''<vector xmlns:android="http://schemas.android.com/apk/res/android" android:width="24dp" android:height="24dp" android:viewportWidth="24" android:viewportHeight="24">
  <path android:fillColor="#FFFFFFFF" android:pathData="M20,3C12,3 4,5 4,13C4,16 6,19 9,19C15,19 20,12 20,3ZM5,22L3,20L15,8L5,22Z"/>
</vector>
''')
(drawable.parent / 'ic_cropcare.xml').write_text('''<vector xmlns:android="http://schemas.android.com/apk/res/android" android:width="108dp" android:height="108dp" android:viewportWidth="108" android:viewportHeight="108">
  <path android:fillColor="#2E7D32" android:pathData="M0,0H108V108H0Z"/>
  <path android:fillColor="#FFFFFF" android:pathData="M78,25C54,25 28,32 28,58C28,70 36,79 48,79C68,79 78,54 78,25ZM30,87L24,81L65,40L30,87Z"/>
</vector>
''')
gradle = ROOT / 'android/app/build.gradle.kts'
if not gradle.exists():
    raise SystemExit('Use Flutter 3.35.4 or newer with a Kotlin Gradle template; see docs/SETUP_WINDOWS.md.')
text = gradle.read_text()
if 'isCoreLibraryDesugaringEnabled' not in text:
    text = text.replace('compileOptions {','compileOptions {\n        isCoreLibraryDesugaringEnabled = true',1)
if 'desugar_jdk_libs' not in text:
    text += '\ndependencies {\n    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")\n}\n'
text = text.replace('minSdk = flutter.minSdkVersion','minSdk = 24').replace('minSdk = 23','minSdk = 24')
gradle.write_text(text)
plist = ROOT / 'ios/Runner/Info.plist'
if plist.exists():
    data = plistlib.loads(plist.read_bytes())
    data.update({
        'CFBundleDisplayName':'CropCare AI',
        'NSCameraUsageDescription':'Take a photo of a crop leaf for analysis.',
        'NSPhotoLibraryUsageDescription':'Choose a crop leaf photo for analysis.',
        'NSLocationWhenInUseUsageDescription':'Save your farm location for weather and nearby crop alerts.',
        'NSLocalNetworkUsageDescription':'Connect to your development crop analysis server on your local network.',
        'NSAppTransportSecurity': {'NSAllowsLocalNetworking': True},
    })
    plist.write_bytes(plistlib.dumps(data,sort_keys=False))
app_delegate = ROOT / 'ios/Runner/AppDelegate.swift'
if app_delegate.exists():
    text = app_delegate.read_text()
    if 'UNUserNotificationCenter.current().delegate' not in text:
        text = text.replace('GeneratedPluginRegistrant.register(with: self)', 'UNUserNotificationCenter.current().delegate = self\n    GeneratedPluginRegistrant.register(with: self)')
    app_delegate.write_text(text)
podfile = ROOT / 'ios/Podfile'
if (ROOT / 'ios/Runner').exists():
    if not podfile.exists():
        podfile.write_text((Path(__file__).parent / 'ios_Podfile.template').read_text())
    text = podfile.read_text()
    text = re.sub(r"#?\s*platform :ios, '[\d.]+'", "platform :ios, '15.0'", text, count=1)
    if 'BYPASS_PERMISSION_LOCATION_ALWAYS' not in text:
        text = text.replace('flutter_additional_ios_build_settings(target)', '''flutter_additional_ios_build_settings(target)
    if target.name == 'geolocator_apple'
      target.build_configurations.each do |config|
        config.build_settings['GCC_PREPROCESSOR_DEFINITIONS'] ||= ['$(inherited)', 'BYPASS_PERMISSION_LOCATION_ALWAYS=1']
      end
    end''')
    podfile.write_text(text)
    project = ROOT / 'ios/Runner.xcodeproj/project.pbxproj'
    if project.exists():
        project.write_text(re.sub(r'IPHONEOS_DEPLOYMENT_TARGET = [\d.]+;', 'IPHONEOS_DEPLOYMENT_TARGET = 15.0;', project.read_text()))
print('Available native projects configured. Android HTTP is enabled for debug/profile only.')
