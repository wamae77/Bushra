import 'dart:io';
import 'dart:developer';
import 'package:bushra_mobile/qrcode/page-home-qrcode-pay-merchant.dart';
import 'package:bushra_mobile/qrcode/page-home-qrcode-pay-p2p.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart' as ms;
import 'package:qr_code_scanner_plus/qr_code_scanner_plus.dart';
import 'package:image_picker/image_picker.dart';
import '../home/fund-transfers/page-home-transfer-v2-under-sps.dart';
import '../l10n/app_localizations.dart';
import '../utils/api-qrcode.dart';

class QRCodeScannerScreen extends StatefulWidget {
  const QRCodeScannerScreen({super.key});
  @override
  State<StatefulWidget> createState() => _QRCodeScannerScreenState();
}

class _QRCodeScannerScreenState extends State<QRCodeScannerScreen> with WidgetsBindingObserver {
  final apiQrCode = ApiQrCode();
  Barcode? result;
  ms.Barcode? msResult;
  QRViewController? controller;
  final GlobalKey qrKey = GlobalKey(debugLabel: 'QR');
  final ImagePicker _picker = ImagePicker();
  int _selectedIndex = 0;
  bool _isCameraActive = true;

  // QR code data fields P2P
  String? type;
  String? qrType;
  String? transferType;
  String? p2pSchemeIdentifier;
  String? transactionParticulars;
  String? financialInstitutionName;
  String? payloadFormatIndicator;
  String? accountHolderName;
  String? pointOfInitiationMethod;
  String? accountNumberOrWalletID;
  String? transactionAmount;

  // QR code data fields P2M (Bank)
  String? domainName;
  String? acquirerId;
  String? merchantId;
  String? countryCode;
  String? merchantCategoryCodeMcc;
  String? merchantCity;
  String? crc;
  String? terminalLabel;
  String? merchantName;
  String? postalCode;
  String? storeLabel;
  String? currencyCode;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopCamera();
    controller?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    switch (state) {
      case AppLifecycleState.resumed:
        if (_isCameraActive && mounted) {
          _resumeCamera();
        }
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
      case AppLifecycleState.inactive:
        _pauseCamera();
        break;
      case AppLifecycleState.hidden:
        break;
    }
  }

  @override
  void reassemble() {
    super.reassemble();
    if (Platform.isAndroid && _isCameraActive) {
      _resumeCamera();
    }
  }

  void _stopCamera() {
    try {
      controller?.stopCamera();
      _isCameraActive = false;
    } catch (e) {
      debugPrint("Error stopping camera: $e");
    }
  }

  void _pauseCamera() {
    try {
      controller?.pauseCamera();
    } catch (e) {
      debugPrint("Error pausing camera: $e");
    }
  }

  void _resumeCamera() {
    try {
      if (!_isCameraActive) {
        controller?.resumeCamera();
        _isCameraActive = true;
      }
    } catch (e) {
      debugPrint("Error resuming camera: $e");
    }
  }

  Future<void> _stopCameraAsync() async {
    try {
      await controller?.stopCamera();
      _isCameraActive = false;
    } catch (e) {
      debugPrint("Error stopping camera: $e");
    }
  }

  Future<void> _pauseCameraAsync() async {
    try {
      await controller?.pauseCamera();
    } catch (e) {
      debugPrint("Error pausing camera: $e");
    }
  }

  void showSnackBar(BuildContext context, String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 7),
        backgroundColor: color,
        action: SnackBarAction(
          label: "DISMISS",
          textColor: Colors.white,
          onPressed: () {},
        ),
      ),
    );
  }

  dynamic _getValueOrDefault(Map<String, dynamic> map, String key, dynamic defaultValue) {
    return map[key] ?? defaultValue;
  }

  Future<void> _processDynamicQR(String scannedCode) async {
    try {
      final response = await apiQrCode.processQrCode(scannedCode);
      if (response != null && response['data']['response_code'] == '00') {
        debugPrint("✅ QR API success: ${response['data']['response']}");
        final qrData = response['data']['qrData'] ?? {};
        print(qrData);

        // Update state safely
        setState(() {
          p2pSchemeIdentifier = _getValueOrDefault(qrData, 'P2P_Scheme_Identifier', p2pSchemeIdentifier);
          transactionParticulars = _getValueOrDefault(qrData, 'Transaction_Particulars', transactionParticulars);
          financialInstitutionName = _getValueOrDefault(qrData, 'Financial_Institution_Name', financialInstitutionName);
          type = _getValueOrDefault(qrData, 'Type', type);
          payloadFormatIndicator = _getValueOrDefault(qrData, 'Payload_Format_Indicator', payloadFormatIndicator);
          accountHolderName = _getValueOrDefault(qrData, 'Account_Holder_Name', accountHolderName);
          pointOfInitiationMethod = _getValueOrDefault(qrData, 'Point_of_Initiation_Method', pointOfInitiationMethod);
          accountNumberOrWalletID = _getValueOrDefault(qrData, 'Account_NumberOrWallet_ID', accountNumberOrWalletID);
          qrType = _getValueOrDefault(qrData, 'qrType', qrType);
          transferType = _getValueOrDefault(qrData, 'transferType', transferType);
          transactionAmount = _getValueOrDefault(qrData, 'Transaction_Amount', transactionAmount);

          domainName = _getValueOrDefault(qrData, 'Domain_Name', domainName);
          acquirerId = _getValueOrDefault(qrData, 'Acquirer_ID', acquirerId);
          merchantId = _getValueOrDefault(qrData, 'Merchant_ID', merchantId);
          countryCode = _getValueOrDefault(qrData, 'Country_Code', countryCode);
          merchantCategoryCodeMcc = _getValueOrDefault(qrData, 'Merchant_Category_Code_MCC', merchantCategoryCodeMcc);
          merchantCity = _getValueOrDefault(qrData, 'Merchant_City', merchantCity);
          crc = _getValueOrDefault(qrData, 'CRC', crc);
          terminalLabel = _getValueOrDefault(qrData, 'Terminal_Label', terminalLabel);
          merchantName = _getValueOrDefault(qrData, 'Merchant_Name', merchantName);
          postalCode = _getValueOrDefault(qrData, 'Postal_Code', postalCode);
          storeLabel = _getValueOrDefault(qrData, 'Store_Label', storeLabel);
          currencyCode = _getValueOrDefault(qrData, 'Currency_Code', currencyCode);
        });

        if (qrType == 'P2P' || qrType == 'p2p') {
          // Navigate and don't pop the scanner screen

          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => FundsTransferSpsScreen(
                fetchName: false,
                qrType: qrType ?? '', // in the select
                transferType: transferType ?? '',
                accountHolderName: accountHolderName ?? '',
                accountNumberOrWalletID: accountNumberOrWalletID ?? '',
                transactionAmount: transactionAmount ?? '',
                financialInstitutionName: financialInstitutionName ?? '',
                transactionParticulars: transactionParticulars ?? '',
              ),
            ),
          );
          // When coming back from the transfer screen, resume camera
          if (mounted) {
            _resumeCamera();
          }
        } else if (qrType == 'Bank' || qrType == 'BANK' || qrType == 'bank' || qrType == 'P2M') {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => MerchantPaymentScreen(
                pointOfInitiationMethod: pointOfInitiationMethod,
                payloadFormatIndicator: payloadFormatIndicator,
                qrType: qrType,
                transferType: transferType,
                domainName: domainName,
                acquirerId: acquirerId,
                merchantId: merchantId,
                countryCode: countryCode,
                merchantCategoryCodeMcc: merchantCategoryCodeMcc,
                merchantCity: merchantCity,
                crc: crc,
                terminalLabel: terminalLabel,
                merchantName: merchantName,
                postalCode: postalCode,
                storeLabel: storeLabel,
                currencyCode: currencyCode,
                transactionAmount: transactionAmount,
              ),
            ),
          );
          // When coming back from merchant screen, resume camera
          if (mounted) {
            _resumeCamera();
          }
        } else {
          showSnackBar(context, 'Unknown QR-Type Found, Allowed only Bank and P2P', Colors.red);
          // Don't pop - just resume camera
          _resumeCamera();
        }
      } else {
        debugPrint("❌ QR API error: ${response?['data']['response'] ?? 'Unknown error'}");
        showSnackBar(context, 'Error processing QR code: ${response?['data']['response'] ?? 'Unknown error'}', Colors.red);
        _resumeCamera();
      }
    } catch (e) {
      debugPrint("❌ QR API exception: $e");
      showSnackBar(context, 'Error processing QR code: $e', Colors.red);
      _resumeCamera();
    }
  }

  Future<void> _scanFromGallery() async {
    _pauseCamera();

    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      ms.MobileScannerController? tempController;
      try {
        tempController = ms.MobileScannerController();
        final ms.BarcodeCapture? barcodeCapture =
        await tempController.analyzeImage(image.path);

        if (barcodeCapture != null && barcodeCapture.barcodes.isNotEmpty) {
          final ms.Barcode firstBarcode = barcodeCapture.barcodes.first;
          log("Gallery Scan Result: ${firstBarcode.rawValue}");
          if (!mounted) return;
          await _processDynamicQR(firstBarcode.rawValue ?? '');
        } else {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No QR code found in this image')),
          );
          _resumeCamera();
        }
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Scan failed: $e')),
        );
        _resumeCamera();
      } finally {
        tempController?.dispose();
      }
    } else {
      // User cancelled gallery selection
      _resumeCamera();
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        _stopCamera();
        return true;
      },
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.close, color: Colors.black),
            onPressed: () {
              _stopCamera();
              if (mounted) Navigator.pop(context);
            },
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.flash_on, color: Colors.black),
              onPressed: () {
                try {
                  controller?.toggleFlash();
                } catch (e) {
                  debugPrint("Error toggling flash: $e");
                }
              },
            ),
          ],
        ),
        body: Stack(
          children: [
            /// Camera view
            Positioned.fill(child: _buildQrView(context)),
            /// Floating pill buttons (top center)
            Positioned(
              top: 20,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.grey.shade400,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: ToggleButtons(
                    isSelected: [_selectedIndex == 0, _selectedIndex == 1],
                    borderRadius: BorderRadius.circular(8),
                    fillColor: Colors.grey.shade200,
                    selectedColor: Colors.black,
                    color: Colors.black87,
                    renderBorder: false,
                    constraints: const BoxConstraints(
                      minHeight: 35,
                      minWidth: 150,
                    ),
                    children: [
                      Text(AppLocalizations.of(context)!.scanNow, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      Text(AppLocalizations.of(context)!.scanFromGallery, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    ],
                    onPressed: (int index) {
                      setState(() {
                        _selectedIndex = index;
                      });
                      if (index == 0) {
                        _resumeCamera();
                      } else {
                        _scanFromGallery();
                      }
                    },
                  ),
                ),
              ),
            ),
            /// Bottom Flip Camera Widget styled like a bottom sheet
            Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(0),
                    topRight: Radius.circular(0),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      AppLocalizations.of(context)!.scanAQrCode,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    InkWell(
                      onTap: () {
                        try {
                          controller?.flipCamera();
                        } catch (e) {
                          debugPrint("Error flipping camera: $e");
                        }
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.red.shade900,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.cameraswitch,
                          size: 32,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildQrView(BuildContext context) {
    var scanArea = (MediaQuery.of(context).size.width < 500 ||
        MediaQuery.of(context).size.height < 500)
        ? 280.0
        : 380.0;
    return QRView(
      key: qrKey,
      onQRViewCreated: _onQRViewCreated,
      overlay: QrScannerOverlayShape(
          borderColor: Colors.red,
          borderRadius: 10,
          borderLength: 30,
          borderWidth: 10,
          cutOutSize: scanArea),
      onPermissionSet: (ctrl, p) => _onPermissionSet(context, ctrl, p),
    );
  }

  void _onQRViewCreated(QRViewController controller) {
    this.controller = controller;
    _isCameraActive = true;

    controller.scannedDataStream.listen((scanData) async {
      if (_isProcessing) return;

      final String? code = scanData.code;
      if (code == null || code.isEmpty) return;

      _isProcessing = true;
      log("Camera Scan Result: $code");

      _pauseCamera();

      if (!mounted) {
        _isProcessing = false;
        return;
      }

      await _processDynamicQR(code);
      _isProcessing = false;
    });
  }

  void _onPermissionSet(BuildContext context, QRViewController ctrl, bool p) {
    log('_onPermissionSet $p');
    if (!p) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No Permission')),
      );
    }
  }
}