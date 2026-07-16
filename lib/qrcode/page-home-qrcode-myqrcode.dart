import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/io_client.dart';
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';
import '../l10n/app_localizations.dart';
import '../utils/api-qrcode.dart';
import '../utils/constants/app_constants.dart';
import '../utils/providers/provider-session.dart';
import '../utils/util-http-client.dart';
import 'package:bushra_mobile/utils/dto/api-response-login.dart';

class MyQRScreen extends StatefulWidget {
  const MyQRScreen({super.key});
  @override
  State<MyQRScreen> createState() => _MyQRScreenState();
}

class _MyQRScreenState extends State<MyQRScreen> {
  ScreenshotController screenshotController = ScreenshotController();
  final apiQrCode = ApiQrCode();
  String? qrString;
  bool isLoadingQR = false;
  double amount = 0.0;
  String? selectedAccount;
  String debitAccountNumber ='';
  String debitAccountCurrency ='';
  final TextEditingController _amountController = TextEditingController();
  Timer? _amountDebounce;

  @override
  void initState() {
    super.initState();
    _generateInitialQR();
    // WidgetsBinding.instance.addPostFrameCallback((_) {
    // });
  }

  @override
  void dispose() {
    _amountDebounce?.cancel();
    _amountController.dispose();
    super.dispose();
  }

  Future<Uint8List?> _fetchImageBytes() async {
    try {
      print("-------------------------- Fetching profile image (Base64 string)...");
      // Try to load from cache
      final cached = await _loadImageFromCache();
      if (cached != null) {
        print('✅ Using cached profile image picture');
        return cached;
      }
      final authProvider = Provider.of<SessionProvider>(context, listen: false).user;
      final token = authProvider?.token;
      final httpClient = await createPinnedHttpClient();
      final ioClient = IOClient(httpClient);

      final response = await ioClient.get(
        Uri.parse(AppConstants.baseUrl + AppConstants.endpointFetchProfileImage + authProvider!.phoneNumber),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/octet-stream',
          'apikey': AppConstants.apiKey,
        },
      );

      print('-------------------------- Response status: ${response.statusCode}');
      if (response.statusCode == 200) {
        final contentType = response.headers['content-type']; // e.g. 'image/png'
        final base64Str = utf8.decode(response.bodyBytes);
        final bytes = base64Decode(base64Str);

        print("Decoded Base64 length: ${base64Str.length}");
        print("Response Content-Type: $contentType");

        // Save to cache with correct extension
        await _saveImageToCache(bytes, contentType);
        return bytes;
      } else {
        print('Error fetching image: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('Error decoding image: $e');
      return null;
    }
  }

  Future<File> _saveImageToCache(Uint8List bytes, String? contentType) async {
    final dir = await getApplicationDocumentsDirectory();
    // Decide extension based on content-type
    String extension = 'jpg'; // Default fallback
    if (contentType != null) {
      if (contentType.contains('png')) {
        extension = 'png';
      } else if (contentType.contains('jpeg') || contentType.contains('jpg')) {
        extension = 'jpg';
      }
    }
    final file = File('${dir.path}/cached_profile_image.$extension');
    return await file.writeAsBytes(bytes);
  }

  Future<Uint8List?> _loadImageFromCache() async {
    final dir = await getApplicationDocumentsDirectory();
    // Check for both .jpg and .png (or any other formats you've added)
    final jpgFile = File('${dir.path}/cached_profile_image.jpg');
    final jpegFile = File('${dir.path}/cached_profile_image.jpeg');
    final pngFile = File('${dir.path}/cached_profile_image.png');
    if (await jpgFile.exists()) {
      return await jpgFile.readAsBytes();
    } else if (await jpegFile.exists()) {
      return await jpegFile.readAsBytes();
    } else if (await pngFile.exists()) {
      return await pngFile.readAsBytes();
    }
    return null; // Return null if neither file exists
  }

  Future<String?> _generateDynamicQR() async {
    try {
      if(selectedAccount == null || selectedAccount!.isEmpty){
        return null; // No account selected
      }
      final authProvider = Provider.of<SessionProvider>(context, listen: false).user;
      final response = await apiQrCode.generateQrCode(
        selectedAccount!,
        "${authProvider?.customerDetails.firstName} ${authProvider?.customerDetails.lastName}",
        amount.toStringAsFixed(2),
        debitAccountCurrency,
        "p2p",
        "QR Bank Transfer",
      );
      if (response != null && response['data']['response_code'] == '00') {
        final qrData = response['data']['qrString'];
        return qrData;
      } else {
        _showSnackBar(context, "QR API error: ${response?['data']['response'] ?? 'Unknown error'}", Colors.red);
        debugPrint("❌ QR API error: ${response?['data']['response'] ?? 'Unknown error'}");
      }
      return null;
    } catch (e) {
      debugPrint("❌ QR API exception: $e");
      _showSnackBar(context, "QR API exception: $e", Colors.red);
      return null;
    }
  }

  Future<bool> _requestStoragePermission(BuildContext context) async {
    if (Platform.isAndroid) {
      final sdk = int.tryParse(
        RegExp(r'SDK (\d+)').firstMatch(Platform.version)?.group(1) ?? '33',
      ) ?? 33;

      if (sdk < 29) {
        // Android 9 and below
        final status = await Permission.storage.request();
        if (!status.isGranted) {
          _showDenied(context, "Storage permission denied");
          return false;
        }
      } else if (sdk >= 33) {
        // Android 13+
        final status = await Permission.photos.request();
        if (!status.isGranted) {
          _showDenied(context, "Photos permission denied");
          return false;
        }
      } else {
        // Android 10–12
        final status = await Permission.storage.request();
        if (!status.isGranted) {
          _showDenied(context, "Storage permission denied");
          return false;
        }
      }
    } else if (Platform.isIOS) {
      final status = await Permission.photosAddOnly.request();
      if (!status.isGranted) {
        _showDenied(context, "Photo permission denied");
        return false;
      }
    }
    return true;
  }

  void _showDenied(BuildContext context, String message) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  void _showSnackBar(BuildContext context, String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 7), // Set to any duration
        backgroundColor: color,
        action: SnackBarAction(
          label: "DISMISS",
          textColor: Colors.white,
          onPressed: () {
            //
          }, // Dismiss action
        ),
      ),
    );
  }

  Future<void> _generateInitialQR() async {
    setState(() {
      isLoadingQR = true;
    });
    final qr = await _generateDynamicQR();
    setState(() {
      qrString = qr;
      isLoadingQR = false;
    });
  }

  Future<void> _saveToGalleryCustom(BuildContext context) async {
    try {
      final image = await screenshotController.capture();
      if (image == null) return;
      if (!await _requestStoragePermission(context)) return;
      final result = await ImageGallerySaverPlus.saveImage(
        Uint8List.fromList(image),
        quality: 100,
        name: "dynamic_qr_${DateTime.now().millisecondsSinceEpoch}",
      );
      debugPrint("✅ Save result: $result");
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("QR Code Image Saved to gallery successfully")),
      );
    } catch (e) {
      debugPrint("❌ Error saving to gallery: $e");
      if (!context.mounted) return;
      _showSnackBar(context, "Failed to save QR image to gallery", Colors.red);
    }
  }

  Future<void> _shareQR() async {
    try {
      final image = await screenshotController.capture();
      if (image == null) return;
      final tempDir = await getTemporaryDirectory();
      final filePath = '${tempDir.path}/my-bbank-qr_code.png';
      final file = File(filePath)..writeAsBytesSync(image);
      await Share.shareXFiles(
        [XFile(file.path)],
        subject: "MY BB Bank QR Code",
        text: "Here is my BB Bank QR Code",
      );
    } catch (e) {
      debugPrint("❌ Error sharing QR: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<SessionProvider>(context).user;
    final accounts = authProvider?.accounts;
    final size = MediaQuery.of(context).size;
    final isPortrait = size.height > size.width;
    return Scaffold(
      backgroundColor: Colors.grey.shade300,
      appBar: AppBar(
        backgroundColor: Colors.grey.shade300,
        automaticallyImplyLeading: true,
        title:  Text(
          AppLocalizations.of(context)!.myQrCode,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 17.0,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Center(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Profile Image
              CircleAvatar(
                backgroundColor: Colors.grey.shade400,
                radius: size.width * 0.1, // responsive avatar size
                child: FutureBuilder<Uint8List?>(
                  future: _fetchImageBytes(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.done &&
                        snapshot.hasData) {
                      return ClipOval(
                        child: Image.memory(
                          snapshot.data!,
                          width: size.width * 0.2,
                          height: size.width * 0.2,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                          const Icon(Icons.person, size: 50, color: Colors.grey),
                        ),
                      );
                    } else {
                      return const Icon(Icons.person, size: 50, color: Colors.grey);
                    }
                  },
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${authProvider!.customerDetails.firstName} ${authProvider.customerDetails.lastName}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: size.width * 0.045, // scales with width
                ),
              ),
              // Text("Telephone: ${authProvider.customerDetails.phoneNumber}"),
              Text("Telephone: ${authProvider.customerDetails.phoneNumber}"),
              const SizedBox(height: 16),
              // QR Container
              Container(
                padding: const EdgeInsets.all(16),
                width: size.width * 0.9,
                // adapt height depending on orientation
                height: isPortrait ? size.height * 0.45 : size.height * 0.65,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 6,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    const SizedBox(height: 4),
                    _buildTextInputDropDownFieldRed(accounts),
                    const SizedBox(height: 12),
                    _buildTextInputFieldGrayAmount(),
                    const SizedBox(height: 12),
                    if (qrString != null)
                       Text(AppLocalizations.of(context)!.scanMyQrCodeForPayments),
                    const SizedBox(height: 12),
                    Expanded(
                      child: Center(
                        child: Screenshot(
                          controller: screenshotController,
                          child: Container(
                            color: Colors.white,
                            alignment: Alignment.center,
                            child: Builder(
                              builder: (context) {
                                if (isLoadingQR) {
                                  return CircularProgressIndicator(color: Colors.red.shade900);
                                } else if (qrString != null) {
                                  return QrImageView(
                                    padding: const EdgeInsets.all(0),
                                    data: qrString!,
                                    version: QrVersions.auto,
                                    size: size.width * 0.55,
                                  );
                                } else {
                                  return Text(
                                    AppLocalizations.of(context)!.selectAnAccountToGenerateQr,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
                                  );
                                }
                              },
                            ),
                          ),
                        ),
                      ),
                    )
                  ],
                ),
              ),
              const SizedBox(height: 30),
              // Action Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ActionButton(
                    icon: Icons.share_outlined,
                    label: "Share my QR",
                    onTap: _shareQR,
                  ),
                  ActionButton(
                    icon: Icons.download_outlined,
                    label: "Save to gallery",
                    onTap: () => _saveToGalleryCustom(context),
                  ),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextInputDropDownFieldRed(List<Account>? accounts){
    return Container(
      decoration: BoxDecoration(
        color: Colors.red.shade50, // Light red background
        borderRadius: BorderRadius.circular(8), // Rounded corners
      ),
      child: Stack(
        children: [
          DropdownButtonFormField<String>(
            value: accounts?.any((a) => a.iban == selectedAccount) == true ? selectedAccount : null,
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.red.shade50,
              border: OutlineInputBorder(
                borderSide: BorderSide.none,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            hint: Text(AppLocalizations.of(context)!.selectAnAccountToGenerateQr, style: TextStyle(fontSize: 12, fontWeight: FontWeight.normal), textAlign: TextAlign.center,),
            dropdownColor: Colors.white,
            icon: const Icon(Icons.arrow_drop_down),
            items: accounts?.map<DropdownMenuItem<String>>((account) {
              String maskedAccount =
                  "A/C #${account.iban.substring(0, 4)}";
              // String maskedAccount =
              //     "A/C #${account.iban.substring(0, 4)}****${account.iban.substring(account.iban.length - 4)}";
              return DropdownMenuItem<String>(
                value: account.iban,
                child: Text(maskedAccount, style: TextStyle(fontSize: 12),),
              );
            }).toList(),
            onChanged: (String? newValue) {
              setState(() {
                selectedAccount = newValue;
                debitAccountNumber = newValue!;
                debitAccountCurrency = accounts?.firstWhere((account) => account.iban == newValue).currency ?? '';
                _generateInitialQR();
              });
            },
          ),
          Positioned(
            left: 10, // Aligning with the inner curve
            right: 10, // Aligning with the inner curve
            bottom: 0,
            child: Container(
              height: 1,
              color: Colors.red.shade900,
            ),
          ),
        ],
      ),
    );
  }

  void _applyAmountSilently(String value) {
    final parsed = double.tryParse(value);
    if (parsed != null && parsed != amount) {
      setState(() {
        amount = parsed;
      });
      _generateInitialQR();
    }
  }

  void _onAmountChanged(String value) {
    _amountDebounce?.cancel();
    _amountDebounce = Timer(const Duration(milliseconds: 500), () {
      _applyAmountSilently(value);
    });
    setState(() {});
  }

  void _onAmountConfirmed(String value) {
    _amountDebounce?.cancel();
    final parsed = double.tryParse(value);
    if (parsed != null) {
      setState(() {
        amount = parsed;
      });
      _generateInitialQR();
    } else if (value.isNotEmpty) {
      _showSnackBar(context, "Invalid amount entered", Colors.red);
    }
    FocusScope.of(context).unfocus();
  }

  Widget _buildTextInputFieldGrayAmount() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Stack(
        children: [
          TextField(
            controller: _amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(
              labelText: AppLocalizations.of(context)!.amount,
              hintText: "eg. 1000.00",
              filled: true,
              fillColor: Colors.grey.shade100,
              border: OutlineInputBorder(
                borderSide: BorderSide.none,
                borderRadius: BorderRadius.circular(8),
              ),
              prefixIcon: Icon(Icons.attach_money, color: Colors.red.shade900),
              suffixIcon: _amountController.text.isNotEmpty
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(Icons.check_circle, color: Colors.green.shade700),
                          tooltip: "Confirm amount",
                          onPressed: () => _onAmountConfirmed(_amountController.text),
                        ),
                        IconButton(
                          icon: Icon(Icons.clear, color: Colors.red.shade900),
                          tooltip: "Clear amount",
                          onPressed: () {
                            _amountDebounce?.cancel();
                            _amountController.clear();
                            setState(() {
                              amount = 0.0;
                            });
                            _generateInitialQR();
                          },
                        ),
                      ],
                    )
                  : null,
            ),
            onChanged: _onAmountChanged,
            onEditingComplete: () => _onAmountConfirmed(_amountController.text),
          ),
          Positioned(
            left: 10,
            right: 10,
            bottom: 0,
            child: Container(
              height: 1,
              color: Colors.grey.shade400,
            ),
          ),
        ],
      ),
    );
  }

}

class ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const ActionButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(40),
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white, // light red background
            ),
            child: Icon(
              icon,
              size: 28,
              color: Colors.red.shade900, // dark red icon
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
