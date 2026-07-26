import 'dart:async';
import 'dart:io';

import 'package:bushra_mobile/page-landing/page-home-landing-login.dart';
import 'package:bushra_mobile/page-landing/page-home-splash.dart';
import 'package:bushra_mobile/providers/local_provider.dart';
// import 'package:bushra_mobile/remote-config-services.dart'; // Disabled - Firebase dependent
import 'package:bushra_mobile/security/blocked_device_screen.dart';
import 'package:bushra_mobile/security/jail-break-check.dart';
// import 'package:bushra_mobile/security/jail-break-check.dart';
import 'package:bushra_mobile/utils/providers/provider-balances.dart';
import 'package:bushra_mobile/utils/providers/provider-favourites.dart';
import 'package:bushra_mobile/utils/providers/provider-mini-recent.dart';
import 'package:bushra_mobile/utils/providers/provider-mini-statement.dart';
import 'package:bushra_mobile/utils/providers/provider-notifications.dart';
import 'package:bushra_mobile/utils/providers/provider-registration.dart';
import 'package:bushra_mobile/utils/providers/provider-themes.dart';
import 'package:bushra_mobile/utils/providers/provider-transfer-favourite-data.dart';
import 'package:bushra_mobile/utils/providers/provider-session.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
// import 'package:bushra_mobile/widgets/placeholder-firebase-screen.dart'; // Disabled - Firebase dependent
// import 'package:firebase_core/firebase_core.dart'; // Disabled
// import 'package:firebase_crashlytics/firebase_crashlytics.dart'; // Disabled
// import 'package:firebase_remote_config/firebase_remote_config.dart'; // Disabled
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:image_picker_android/image_picker_android.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'change-pin/forgot-pin-set-pin/page-forgot-pin.dart';
import 'home/page-home.dart';
import 'l10n/app_localizations.dart';
import 'localization/somali_localizations_delegate.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  //TODO - Initialize Provider in main.dart
  WidgetsFlutterBinding.ensureInitialized();

  // Use the Android system photo picker so we never request READ_MEDIA_IMAGES.
  final imagePicker = ImagePickerPlatform.instance;
  if (imagePicker is ImagePickerAndroid) {
    imagePicker.useAndroidPhotoPicker = true;
  }

  final localeProvider = LocaleProvider();
  await localeProvider.loadLocale();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => SessionProvider()),
        ChangeNotifierProvider(create: (_) => RegistrationData()),
        ChangeNotifierProvider(create: (_) => BalanceProvider()),
        ChangeNotifierProvider(create: (_) => MiniStatementProvider()),
        ChangeNotifierProvider(create: (_) => MiniRecentStatementProvider()),
        ChangeNotifierProvider(create: (_) => FavouritesProvider()),
        ChangeNotifierProvider(create: (_) => FavoriteTransferDataProvider()),
        ChangeNotifierProvider(create: (_) => NotificationServiceProvider()),
        // ChangeNotifierProvider(create: (_) => LocaleProvider()),
        ChangeNotifierProvider.value(value: localeProvider),
      ],
      child: MyApp()
    ),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key,});
  @override
  State<MyApp> createState() => _MyAppState();
}
class _MyAppState extends State<MyApp> {
  // This widget is the root of your application.
  bool _firebaseReady = true; // Set to true since Firebase is disabled
  bool _initializing = true;
  bool _forceUpdateRequired = false;
  bool _isDeviceSecure = false;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    setState(() {
      _initializing = true;
    });
    try {
      await Firebase.initializeApp();
      // WidgetsBinding.instance.addPostFrameCallback((_) async {
      //   await checkForceUpdate(navigatorKey.currentContext!);
      // });

      // todo Initialize Notifications
      // final notificationsProvider = NotificationServiceProvider();
      // await notificationsProvider.safeInit();
      final notificationsProvider = Provider.of<NotificationServiceProvider>(
        navigatorKey.currentContext!,
        listen: false,
      );
      await notificationsProvider.safeInit();


      FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterError;
      await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(true);
      // Test crash (optional)
      //FirebaseCrashlytics.instance.log('APP_START_UP');
      //FirebaseCrashlytics.instance.recordError(Exception('Fake crash'), StackTrace.current, fatal: false);
      //FirebaseCrashlytics.instance.crash();
      final isSecure = await SecurityService.isDeviceSecure();
      //await AppInstallManager.handleFirstInstall();
      setState(() {
        // _isDeviceSecure = isSecure;
        _isDeviceSecure = true;
        _firebaseReady = true; // Always true since Firebase is disabled
      });
    } catch (e) {
      debugPrint('❌ App initialization failed: $e');
    } finally {
      setState(() {
        _initializing = false;
      });
    }
  }

  // Firebase Remote Config disabled - commented out entire function
  /*
  Future<void> checkForceUpdate(BuildContext context) async {
    String installedVersionAndBuildNumber = '';
    String latestVersion = '';

    final remoteConfig = FirebaseRemoteConfig.instance;
    await RemoteConfigService.initialize();

    await remoteConfig.fetchAndActivate();
    final minVersion = remoteConfig.getString('min_version').isNotEmpty
        ? remoteConfig.getString('min_version')
        : '1.0.0'; // Default fallback version
    final minBuild = int.tryParse(remoteConfig.getString('min_build') ?? '') ?? 20;
    latestVersion = '( Version: $minVersion, Build: $minBuild )';

    final info = await PackageInfo.fromPlatform();
    final currentVersion = info.version;
    final currentBuild = int.tryParse(info.buildNumber) ?? 0;

    installedVersionAndBuildNumber = '( Version: $currentVersion, Build: $currentBuild )';

    final shouldForceUpdate = _isVersionLower(currentVersion, minVersion) || currentBuild < minBuild;

    if (shouldForceUpdate) {
      debugPrint('🚨 Force update required: $currentVersion (min: $minVersion, build: $minBuild)');
      _forceUpdateRequired = true;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showForceUpdateDialog(navigatorKey.currentContext!, installedVersionAndBuildNumber, latestVersion);
      });
    } else {
      debugPrint('✅ App is up to date: $currentVersion (min: $minVersion, build: $minBuild)');
    }
  }
  */

  bool _isVersionLower(String current, String required) {
    try {
      List<int> c = current.split('.').map((e) => int.tryParse(e) ?? 0).toList();
      List<int> r = required.split('.').map((e) => int.tryParse(e) ?? 0).toList();
      for (int i = 0; i < r.length; i++) {
        if (i >= c.length || c[i] < r[i]) return true;
        if (c[i] > r[i]) return false;
      }
      return false;
    } catch (e) {
      debugPrint('🚨 Version parse error: $e');
      return false;
    }
  }

  void _showForceUpdateDialog(BuildContext context, String installedVersions, latestVersion) {
    final info = PackageInfo.fromPlatform();
    info.then((packageInfo) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => VersionUpdateDialog(installedVersions: installedVersions, latestVersion: latestVersion),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final sessionProvider = Provider.of<SessionProvider>(context);
    final localeProvider = context.watch<LocaleProvider>();
    return MaterialApp(
        navigatorKey: navigatorKey,
        title: 'Bushra Mobile App',
        locale: localeProvider.locale,
        supportedLocales: const [
          Locale('en'),
          Locale('so'),
        ],
        localizationsDelegates: [
          AppLocalizations.delegate,
          localeProvider.locale.languageCode == 'so'
              ? SomaliMaterialLocalizationsDelegate()
              : GlobalMaterialLocalizations.delegate,
          localeProvider.locale.languageCode == 'so'
              ? SomaliWidgetsLocalizationsDelegate()
              : GlobalWidgetsLocalizations.delegate,
          localeProvider.locale.languageCode == 'so'
              ? SomaliCupertinoLocalizationsDelegate()
              : GlobalCupertinoLocalizations.delegate,
        ],
        theme: ThemeData(
          dividerColor: const Color(0xFFECEDF1),
          brightness: Brightness.light,
          primaryColor: Colors.white,
          fontFamily: 'Exo2',
          textTheme: const TextTheme(
            titleLarge: TextStyle(fontSize: 17.0, fontWeight: FontWeight.bold),
            titleMedium: TextStyle(fontSize: 16.0, fontWeight: FontWeight.bold),
            titleSmall: TextStyle(fontSize: 14),
            bodyLarge: TextStyle(fontSize: 16.0),
            bodyMedium: TextStyle(fontSize: 12.0),
            bodySmall: TextStyle(fontSize: 10.0),
            headlineLarge: TextStyle(fontSize: 18.0, color: Colors.black54),
            headlineMedium: TextStyle(fontSize: 16.0, color: Colors.black54),
            headlineSmall: TextStyle(fontSize: 14.0, fontWeight: FontWeight.bold),
            displayLarge: TextStyle(fontSize: 20.0, color: Colors.black54),
            displayMedium: TextStyle(fontSize: 16.0, color: Colors.black54),
            displaySmall: TextStyle(fontSize: 14.0, color: Colors.black54),
          ),
          inputDecorationTheme: const InputDecorationTheme(
            hintStyle: TextStyle(fontSize: 14.0, color: Colors.grey),
            labelStyle: TextStyle(fontSize: 14.0, color: Colors.black),
            floatingLabelStyle: TextStyle(fontSize: 16.0, fontWeight: FontWeight.bold),
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            border: OutlineInputBorder(),
            filled: true,
            fillColor: Colors.white,
          ),
          dropdownMenuTheme: DropdownMenuThemeData(
            textStyle: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.black,
            ),
            inputDecorationTheme: InputDecorationTheme(
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
          ),
          useMaterial3: true,
        ),
        debugShowCheckedModeBanner: false,
        home: _initializing
            ? Center(child: CircularProgressIndicator(color: Colors.red.shade900))
            : // Firebase placeholder removed since Firebase is disabled
        // !_firebaseReady
        // ? FirebaseOfflinePlaceholder(onRetry: _initializeApp)
        // :
        // !_isDeviceSecure
        //     ? const BlockedDeviceScreen()
        //     : _forceUpdateRequired
        //     ? const SizedBox.shrink()
        //     : sessionProvider.isLoggedIn && sessionProvider.user != null
        //     ? DashboardScreen()
        //     : SplashScreen(),
        _forceUpdateRequired
            ? const SizedBox.shrink()
            : sessionProvider.isLoggedIn && sessionProvider.user != null
            ? DashboardScreen()
            : SplashScreen(),
        routes: {
          '/splash': (_) => SplashScreen(),
          '/login': (_) => LandingPageLogin(),
          '/home': (_) => DashboardScreen(),
          '/forgot-password': (_) => ForgotPinScreen(),
        }
    );
  }
}

class VersionUpdateDialog extends StatelessWidget {
  final String installedVersions;
  final String latestVersion;
  const VersionUpdateDialog({super.key, required this.installedVersions, required this.latestVersion});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'A new version of the app is available.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Please update to continue. \n\n''Installed version: $installedVersions',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 2),
              Text(
                'Latest version: $latestVersion',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: screenWidth * 0.8,
                child: ElevatedButton(
                  onPressed: () async {
                    final url = Platform.isAndroid
                        ? 'https://play.google.com/store/apps/details?id=com.bbbank.so.bushra_mobile'
                        : 'https://apps.apple.com/app/id6741591752';
                    if (await canLaunchUrl(Uri.parse(url))) {
                      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade900,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'UPDATE',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}