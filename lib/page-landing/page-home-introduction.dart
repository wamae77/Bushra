import 'dart:io';

import 'package:bushra_mobile/page-landing/page-home-landing-login.dart';
import 'package:bushra_mobile/widgets/language-drop-down.dart';
import 'package:flutter/material.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter_svg/svg.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/app_localizations.dart';

class HomeOnBoarding extends StatefulWidget {
  const HomeOnBoarding({super.key});

  @override
  State<HomeOnBoarding> createState() => _HomeOnBoardingState();
}

class _HomeOnBoardingState extends State<HomeOnBoarding> {
  int _currentSliderIndex = 0;
  String currentImage ="";

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && Platform.isAndroid) {
        // ✅ Show your custom permission education dialog only on Android
        _checkPermissionEnabled(context);
      }
      // ❌ On iOS, don't show the custom dialog here
      // iOS will handle permission prompts when user tries the feature
    });
  }

  final List<String> sliderTextsTitle = [
    "Islamic Finance Available",
    "Card Management",
    "Term Deposits"
  ];

  final List<String> sliderTexts = [
    "Empower your dreams with our Hassle free loans",
    "Experience the ultimate peace of mind and convenience with our card management",
    "Secure your financial future with our term deposit"
  ];

  final List<String> sliderImages = [
    "assets/images/onboarding/onboarding-1.png",
    "assets/images/onboarding/onboarding-2.png",
    "assets/images/onboarding/onboarding-3.png"
  ];

  String selectedLanguage = "English";
  final List<Map<String, String>> languages = [
    {"name": "English", "flag": "assets/flags/uk.svg"},
    {"name": "العربية", "flag": "assets/flags/sa.svg"},
    {"name": "Swahili", "flag": "assets/flags/ke.svg"},
  ];

  void _checkPermissionEnabled(BuildContext context) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    bool? isPermissionDone = prefs.getBool('isPermissionDone');
    if (isPermissionDone != null) {
      if(!isPermissionDone){
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return const CheckboxDialog();
          },
        );
      }
    }else{
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return const CheckboxDialog();
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Builder(
        builder: (context) {
          final double height = MediaQuery.of(context).size.height;
          return CarouselSlider(
            options: CarouselOptions(
              height: height,
              viewportFraction: 1.0,
              enlargeCenterPage: false,
              autoPlay: true,
              onPageChanged: (index, reason) {
                setState(() {
                  _currentSliderIndex = index;
                });
              },
            ),
            items: sliderImages.map((item) => Stack(
              children: [
                Container(
                  decoration: BoxDecoration(
                    image: DecorationImage(
                      image: AssetImage(item),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                Container(
                    decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.red.shade900,
                        //Colors.purple.shade900,
                        Colors.transparent,
                      ],
                      stops: const [0.15, 0.5],
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                    ),
                  ),
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 40.0, left: 20.0, right: 4.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            SvgPicture.asset(
                              'assets/icons/open-door-logo.svg',
                              width: 25,
                              height: 25,
                              colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
                            ),
                            const LanguageDropdown(),
                          ],
                        ),
                      ),
                      const Spacer(),
                      // Slider Section
                      // ⬇️ Text Section moved near bottom
                      Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                            sliderTextsTitle[_currentSliderIndex],
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            sliderTexts[_currentSliderIndex],
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 16,
                              fontWeight: FontWeight.normal,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      // ⬇️ Dots Indicator (make active one larger)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: sliderTexts.asMap().entries.map((entry) {
                          bool isActive = _currentSliderIndex == entry.key;
                          return GestureDetector(
                            onTap: () => CarouselSlider.builder(
                              itemCount: sliderTexts.length,
                              itemBuilder: (_, __, ___) => Container(),
                              options: CarouselOptions(),
                            ),
                            child: Container(
                              width: isActive ? 40.0 : 14.0,  // Wider active bar
                              height: 2.5,
                              margin: const EdgeInsets.symmetric(vertical: 20.0, horizontal: 4.0),
                              decoration: BoxDecoration(
                                shape: BoxShape.rectangle,
                                color: _currentSliderIndex == entry.key
                                    ? Colors.white
                                    : Colors.white.withOpacity(0.4),
                              ),
                            ),
                          );
                        }).toList(),
                      ),

                      // Buttons
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 30.0),
                        child: Column(
                          children: [
                            ElevatedButton(
                              onPressed: () async {
                                SharedPreferences prefs = await SharedPreferences.getInstance();
                                await prefs.setBool('isIntroductionPageViewed', true);
                                Navigator.push(context, MaterialPageRoute(builder: (context) => const LandingPageLogin()));
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: Colors.red.shade900,
                                padding: const EdgeInsets.symmetric(vertical: 15),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  AppLocalizations.of(context)!.getStarted,
                                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.red.shade900),
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            ElevatedButton(
                              onPressed: () async {
                                SharedPreferences prefs = await SharedPreferences.getInstance();
                                await prefs.setBool('isIntroductionPageViewed', true);
                                Navigator.push(context, MaterialPageRoute(builder: (context) => const LandingPageLogin()));
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red.shade900,
                                foregroundColor: Colors.red.shade900,
                                padding: const EdgeInsets.symmetric(vertical: 15),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  side: const BorderSide(
                                    color: Colors.white,
                                    width: 0.5,
                                  ),
                                ),
                              ),
                              child: const Center(
                                child: Text(
                                  "CONTINUE",
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                                ),
                              ),
                            ),
                            const SizedBox(height: 60)
                          ],
                        ),
                      ),

                    ],
                  ),
                ),
              ],
            ),).toList(),
          );
        },
      ),
    );
  }
}



//TODO NEW
class CheckboxDialog extends StatefulWidget {
  const CheckboxDialog({super.key});
  @override
  State<CheckboxDialog> createState() => _CheckboxDialogState();
}

class _CheckboxDialogState extends State<CheckboxDialog> {
  bool _isChecked1 = false;
  bool _isChecked2 = false;
  bool _isChecked3 = false;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: isLandscape ? screenHeight * 0.8 : screenHeight * 0.9,
          maxWidth: screenWidth * 0.95,
        ),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: screenWidth * 0.25,
                  height: screenWidth * 0.28,
                  child: Image.asset(
                    'assets/images/icons/permission-icon.png',
                    fit: BoxFit.contain,
                  ),
                ),
                const SizedBox(height: 10),
                 Text(
                  AppLocalizations.of(context)!.grantPermission,
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                Text(
                  AppLocalizations.of(context)!.toHaveABetterExperienceWithOurProductngivePermissionToTheFollowing,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.black54,
                  ),
                ),
                const SizedBox(height: 16),
                _buildPermissionCard(
                  icon: Icons.contacts,
                  title: "Contacts",
                  subtitle: "We access your contacts to make transactions",
                  value: _isChecked1,
                  onChanged: (val) => setState(() => _isChecked1 = val ?? false),
                ),
                const SizedBox(height: 8),
                _buildPermissionCard(
                  icon: Icons.sd_card,
                  title: "Storage",
                  subtitle: "Make downloads of your statements",
                  value: _isChecked2,
                  onChanged: (val) => setState(() => _isChecked2 = val ?? false),
                ),
                const SizedBox(height: 8),
                _buildPermissionCard(
                  icon: Icons.share_location,
                  title: "Location",
                  subtitle: "Get direction to ATM & Branches",
                  value: _isChecked3,
                  onChanged: (val) => setState(() => _isChecked3 = val ?? false),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () async {
                        if (_isChecked1 && _isChecked2 && _isChecked3) {
                          Navigator.of(context).pop();
                          SharedPreferences prefs = await SharedPreferences.getInstance();
                          await prefs.setBool('isPermissionDone', true);
                          await _requestPermissions();
                        } else {
                          showSnackBar(context, 'It is recommended to enable all permissions for the app to work correctly.', Colors.red);
                        }
                      },
                      child: Text(
                        'CONTINUE',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.red.shade900,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    // TextButton(
                    //   onPressed: () {
                    //     Navigator.of(context).pop();
                    //   },
                    //   child: const Text(
                    //     'Skip',
                    //     style: TextStyle(
                    //       fontSize: 14,
                    //       fontWeight: FontWeight.normal,
                    //       color: Colors.black,
                    //     ),
                    //   ),
                    // ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPermissionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required Function(bool?) onChanged,
  }) {
    return Card(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8.0),
        side: const BorderSide(color: Colors.grey, width: 0.5),
      ),
      elevation: 0.0,
      child: ListTile(
        leading: CircleAvatar(
          radius: 16,
          backgroundColor: Colors.red.shade50,
          child: Icon(icon, color: Colors.red.shade900, size: 16,),
        ),
        title: Text(
          title,
          style: const TextStyle(fontSize: 12.0, fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          subtitle,
          textAlign: TextAlign.start,
          style: const TextStyle(fontSize: 10.0, fontWeight: FontWeight.normal),
        ),
        trailing: Checkbox(
          value: value,
          onChanged: onChanged,
          activeColor: Colors.red.shade900,
        ),
      ),
    );
  }

  Future<void> _requestPermissions() async {
    if (_isChecked3) await _requestPermission(Permission.location);
    if (_isChecked1) await _requestPermission(Permission.contacts);
  }

  Future<void> _requestPermission(Permission permission) async {
    final status = await permission.request();
    if (status.isPermanentlyDenied) openAppSettings();
  }

  void showSnackBar(BuildContext context, String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: 'DISMISS',
          textColor: Colors.white,
          onPressed: () {},
        ),
      ),
    );
  }
}