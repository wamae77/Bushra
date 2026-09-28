import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../l10n/app_localizations.dart';
import '../register/dto/customer-verification-details.dart';
import '../utils/api-login.dart';
import '../utils/constants/app_constants.dart';
import '../utils/providers/provider-session.dart';
import '../widgets/date-picker-custom.dart';
import '../widgets/dialog-error.dart';
import '../widgets/progress-dialog.dart';
import 'landing-login-2-security-qsn.dart';

class AccountLookupScreen extends StatefulWidget {
  const AccountLookupScreen({super.key});
  @override
  State<AccountLookupScreen> createState() => _AccountLookupScreenState();
}

class _AccountLookupScreenState extends State<AccountLookupScreen> {

  bool isLoading = false;
  FocusNode focusNode = FocusNode();
  final apiLogin = ApiLogin();

  TextEditingController idController = TextEditingController();
  TextEditingController phoneController = TextEditingController();
  TextEditingController dobController = TextEditingController();
  TextEditingController accountNumberController = TextEditingController();
  String phoneNumber = '';
  String selectedDocumentLabel = 'ID Number / Passport Number';
  String? _selectedDocumentValue;
  DocumentType? selectedDocumentType; // Starts as null (no selection)
  final List<DocumentType> documentTypes = [
    DocumentType(value: 'NATIONALID', description: 'National ID'),
    DocumentType(value: 'PASSPORT', description: 'Passport'),
  ];

  @override
  void dispose() {
    idController.dispose();
    phoneController.dispose();
    dobController.dispose();
    accountNumberController.dispose();
    super.dispose();
  }

  void clearInputFields(){
    idController.clear();
    phoneController.clear();
    accountNumberController.clear();
    dobController.clear();
  }

  Future<void> customerVerification(BuildContext context, String phone, String account, String passport, String dob) async {
    try {
      String phoneNumberFormatted ='';
      if(phone.startsWith('+')){
        phoneNumberFormatted = phone.replaceFirst('+', '');
      }else{
        phoneNumberFormatted = phone;
      }

      //TODO - TEST NUMBER: SKIP CBS DEDUPE AND CONTINUE THE NORMAL FLOW
      if (phoneNumberFormatted == AppConstants.dedupeBypassPhoneNumber) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('USER_LOGIN_ID', phoneNumberFormatted);
        if (!context.mounted) return;
        Provider.of<SessionProvider>(context, listen: false).setUserLoginId(phoneNumberFormatted);
        setState(() {
          isLoading = false;
        });
        Navigator.pop(context);
        showAlertDialogAccountActivation(context);
        return;
      }

      String cifRequest = account.substring(3, account.length - 3);
      String email = 'test@test.com';
      var responseData = await apiLogin.customerRegistrationStatus(phoneNumberFormatted, account, email, passport, formatDateString(dob), "false", _selectedDocumentValue!);
      ApiResponseModelCustomerVerification verificationResponse = ApiResponseModelCustomerVerification.fromJson(responseData);
      if (verificationResponse.customer != null) {
        if(passport.toUpperCase() != verificationResponse.customer?.passport.toUpperCase()){
          setState(() {
            isLoading = false;
            Navigator.pop(context);
            // showErrorDialog(context, 'Oops! Your Account Verification Failed', 'Passport Information Does Not match banks captured data.', onRetry);
            showErrorDialog(context, 'Oops! Your Account Verification Failed', 'Passport Information Does Not match banks captured data.', onRetry);
          });
          return;
        }
        String? cifResponse = verificationResponse.customer?.cif;
        if(cifRequest != cifResponse){
          setState(() {
            isLoading = false;
            Navigator.pop(context);
            showErrorDialog(context, 'Oops! Your Account Verification Failed', 'Account Information Does Not match banks captured data', onRetry);
          });
          return;
        }
        if (compareDates(dobController.text, verificationResponse.customer!.dateOfBirth)) {
          print('Dates match!');
        } else {
          print('Dates do not match');
          setState(() {
            isLoading = false;
            Navigator.pop(context);
            showErrorDialog(context, 'Oops! Your Account Verification Failed', 'Date of Birth Entered Does Not match banks Date of Birth During Account opening', onRetry);
          });
          return;
        }
        String? phoneNumberResponse = verificationResponse.customer?.phoneNumber;
        if(phoneNumberFormatted != phoneNumberResponse){
          setState(() {
            isLoading = false;
            Navigator.pop(context);
            showErrorDialog(context, 'Oops! Your Account Verification Failed', 'Phone Number Entered Does Not match banks Phone Number During Account opening', onRetry);
          });
          return;
        }
        //TODO Set Phone Number Globally
        final prefs = await SharedPreferences.getInstance();
        setState(() {
          prefs.setString('USER_LOGIN_ID',phoneNumberFormatted);
          Provider.of<SessionProvider>(context, listen: false).setUserLoginId(phoneNumberFormatted);
          isLoading = false;
          Navigator.pop(context);
          showAlertDialogAccountActivation(context);
        });
      }else{
        setState(() {
          isLoading = false;
          Navigator.pop(context);
          showErrorDialog(context, 'Oops! Your Account Verification Failed', verificationResponse.errorData.toString(), onRetry);
        });
      }
    } catch (error) {
      setState(() {
        isLoading = false;
        Navigator.pop(context);
        showErrorDialog(context, 'Oops! Your Account Verification Failed', error.toString(), onRetry);
      });
      throw Exception('FAILED CUSTOMER VERIFY : $error');
    }
  }

  void onRetry(){
    Navigator.pop(context);
  }

  void showErrorDialog(BuildContext context, String messageParent, String message, VoidCallback onRetry) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => ErrorAlertDialog(message: message, onRetry: onRetry, messageParent: messageParent,),
    );
  }

  bool compareDates(String inputDate, String accountDate) {
    try {
      final parsedInputDate = parseInputDate(inputDate);
      if (parsedInputDate == null) return false;
      // Normalize accountDate to extract only date part
      String dateOnly;
      if (accountDate.contains('T')) {
        dateOnly = accountDate.split('T')[0];
      } else {
        dateOnly = accountDate.split(' ')[0];
      }

      final accountDateParts = dateOnly.split('-');
      final accountYear = int.parse(accountDateParts[0]);
      final accountMonth = int.parse(accountDateParts[1]);
      final accountDay = int.parse(accountDateParts[2]);
      final parsedAccountDate = DateTime(accountYear, accountMonth, accountDay);

      return parsedInputDate.year == parsedAccountDate.year &&
          parsedInputDate.month == parsedAccountDate.month &&
          parsedInputDate.day == parsedAccountDate.day;
    } catch (e) {
      print('Error comparing dates: $e');
      return false;
    }
  }

  String formatDateString(String inputDate) {
    try {
      // Parse using the known and consistent format: dd/MM/yyyy
      final parsedDate = DateFormat('dd/MM/yyyy').parseStrict(inputDate);
      // Format as "yyyy-MM-dd 00:00:00.0"
      final formattedDate =
          "${parsedDate.year.toString().padLeft(4, '0')}-"
          "${parsedDate.month.toString().padLeft(2, '0')}-"
          "${parsedDate.day.toString().padLeft(2, '0')} 00:00:00.0";

      return formattedDate;
    } catch (e) {
      if (kDebugMode) {
        print('Error formatting date: $inputDate -> $e');
      }
      return inputDate;
    }
  }

  DateTime? parseInputDate(String inputDate) {
    try {
      // Force a consistent format, e.g., dd/MM/yyyy
      final format = DateFormat('dd/MM/yyyy');
      return format.parseStrict(inputDate);
    } catch (e) {
      print('Error parsing input date: $e');
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar:AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        title: Text(
          AppLocalizations.of(context)!.accountLookup,
          style: TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.bold),
        ),
        centerTitle: false,
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Container(
                color: Colors.white,
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppLocalizations.of(context)!.pleaseProvideTheFollowingDetails,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 20),

                    Text(AppLocalizations.of(context)!.selectDocumentType, style: TextStyle(color: Colors.grey)),
                    const SizedBox(height: 8),
                    _buildDocumentTypeDropDown(),

                    const SizedBox(height: 16),
                    Text(AppLocalizations.of(context)!.idNumberPassportNumber, style: TextStyle(color: Colors.grey)),
                    const SizedBox(height: 8),
                    _buildTextInputFieldRed("Eg. P12345678", idController, TextInputType.text),

                    const SizedBox(height: 20),

                    Text(AppLocalizations.of(context)!.phoneNumber, style: TextStyle(color: Colors.grey)),
                    const SizedBox(height: 8),
                    _buildTextInputFieldPhoneNumber('Eg 615566243', phoneController),
                    const SizedBox(height: 20),

                    Text( AppLocalizations.of(context)!.dateOfBirth, style: TextStyle(color: Colors.grey)),
                    const SizedBox(height: 8),
                    CustomDatePickerWidget(
                      context: context,
                      hint: 'Eg dd/MM/yyyy',
                      controller: dobController,
                    ),
                    const SizedBox(height: 20),

                    Text(AppLocalizations.of(context)!.accountNumber, style: TextStyle(color: Colors.grey)),
                    const SizedBox(height: 8),
                    _buildTextInputFieldGray("Eg. 0013000006100", accountNumberController, TextInputType.number),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0), // Add padding for spacing
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  setState(() {
                    isLoading = true;
                  });
                  showCrossingBallsProgressDialog(context, 'We are verifying your account \n Please Wait...');
                  String id = idController.text;
                  String dob = dobController.text;
                  String accountNumber = accountNumberController.text;

                  if(kDebugMode){
                    print("ID: $id");
                    print("DOB: $dob");
                    print("Account Number: $accountNumber");
                    print("Phone Number: $phoneNumber");
                  }

                  if (_selectedDocumentValue == null) {
                    showSnackBar(context, 'Document type is not selected', Colors.red);
                    setState(() {
                      isLoading = false;
                      Navigator.pop(context);
                    });
                    return;
                  }

                  if(id=='' || dob=='' || accountNumber=='' || phoneNumber ==''){
                    showSnackBar(context, 'All fields are mandatory', Colors.red);
                    setState(() {
                      isLoading = false;
                      Navigator.pop(context);
                    });
                    return;
                  }
                  if(id.isEmpty || dob.isEmpty || accountNumber.isEmpty || phoneNumber.isEmpty){
                    showSnackBar(context, 'All fields are mandatory', Colors.red);
                    setState(() {
                      isLoading = false;
                      Navigator.pop(context);
                    });
                    return;
                  }else if(phoneNumber.length != 13) {
                    showSnackBar(context, 'Invalid Phone Number Input Length (9 length required)', Colors.red);
                    setState(() {
                    isLoading = false;
                    Navigator.pop(context);
                    });
                    return;
                  }else{
                    customerVerification(context, phoneNumber, accountNumber, id.toUpperCase(),dob);
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
                  'CONTINUE',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void showAlertDialogAccountActivation(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final isLandscape = mediaQuery.orientation == Orientation.landscape;
    final dialogWidth = isLandscape
        ? mediaQuery.size.width * 0.5
        : mediaQuery.size.width * 0.8;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          content: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: dialogWidth,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Image.asset(
                    'assets/images/icons/success-check.png',
                    width: mediaQuery.size.width * 0.15,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(height: 18),
                  Text(
                    AppLocalizations.of(context)!.accountFoundSuccessfully,
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                   Text(
                      AppLocalizations.of(context)!.weFoundTheAccountWithTheDetailsYouProvidedToUsPleaseClickActivateButtonToContinue,
                    style: TextStyle(
                      color: Colors.black87,
                      fontSize: 12,
                      fontWeight: FontWeight.normal,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
          actions: <Widget>[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade900,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const LoginSecurityQuestions(),
                      ),
                    );
                  },
                  child: Text(
                    AppLocalizations.of(context)!.activate,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void showSnackBar(BuildContext context, String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 10),
        backgroundColor: color,
        action: SnackBarAction(
          label: "DISMISS",
          textColor: Colors.white,
          onPressed: () {}, // Dismiss action
        ),
      ),
    );
  }

  void showCrossingBallsProgressDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => CrossingBallsProgressDialog(message: message,),
    );
  }

  Widget _buildTextInputFieldRed(String hint, TextEditingController controller, TextInputType textInputType, {int maxLines = 1}){
    return Container(
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Stack(
        children: [
          TextField(
            controller: controller,
            maxLines: maxLines,
            keyboardType: textInputType,
            decoration: InputDecoration(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              hintText: hint,
              filled: true,
              fillColor: Colors.red.shade50,
              border: OutlineInputBorder(
                borderSide: BorderSide.none,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
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

  Widget _buildTextInputFieldGray(String hint, TextEditingController controller, TextInputType textInputType, {int maxLines = 1}){
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade100, // Light red background
        borderRadius: BorderRadius.circular(8), // Rounded corners
      ),
      child: Stack(
        children: [
          TextField(
            controller: controller,
            maxLines: maxLines,
            keyboardType: textInputType,
            decoration: InputDecoration(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              hintText: hint,
              filled: true,
              fillColor: Colors.grey.shade100,
              border: OutlineInputBorder(
                borderSide: BorderSide.none,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          Positioned(
            left: 10, // Aligning with the inner curve
            right: 10, // Aligning with the inner curve
            bottom: 0,
            child: Container(
              height: 1,
              color: Colors.grey.shade900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextInputFieldPhoneNumber(String hint, TextEditingController controller){
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade100, // Light red background
        borderRadius: BorderRadius.circular(8), // Rounded corners
      ),
      child: Stack(
        children: [
          IntlPhoneField(
            controller: controller,
            focusNode: focusNode,
            disableLengthCheck: true,
            decoration: InputDecoration(
              hintText: hint,
              filled: true,
              fillColor: Colors.grey.shade100,
              border: OutlineInputBorder(
                borderSide: BorderSide.none,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            languageCode: "en",
            initialCountryCode: "SO",
            onChanged: (phone) {
              if (kDebugMode) {
                print(phone.completeNumber);
              }
              setState(() {
                phoneNumber = phone.completeNumber;
              });
            },
            onCountryChanged: (country) {
              if (kDebugMode) {
                print('Country changed to: ${country.name}');
              }
            },
          ),
          // TextField(
          //   controller: controller,
          //   readOnly: true,
          //   decoration: InputDecoration(
          //     contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          //     hintText: hint,
          //     filled: true,
          //     fillColor: Colors.grey.shade100,
          //     border: OutlineInputBorder(
          //       borderSide: BorderSide.none,
          //       borderRadius: BorderRadius.circular(8),
          //     ),
          //     suffixIcon: const Icon(Icons.calendar_today),
          //   ),
          //   onTap: () async {
          //     DateTime? pickedDate = await showDatePicker(
          //       context: context,
          //       initialDate: DateTime.now(),
          //       firstDate: DateTime(1900), // Earliest selectable date
          //       lastDate: DateTime.now(), // Prevent future dates
          //     );
          //     if (pickedDate != null) {
          //       String formattedDate =
          //           "${pickedDate.day}/${pickedDate.month}/${pickedDate.year}";
          //       controller.text = formattedDate;
          //     }
          //   },
          // ),
          Positioned(
            left: 10, // Aligning with the inner curve
            right: 10, // Aligning with the inner curve
            bottom: 0,
            child: Container(
              height: 1,
              color: Colors.grey.shade900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentTypeDropDown() {
    return Container(
      margin: const EdgeInsets.only(top: 16),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Stack(
        children: [
          DropdownButtonFormField<DocumentType>(
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.red.shade50,
              border: OutlineInputBorder(
                borderSide: BorderSide.none,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            hint: Text(AppLocalizations.of(context)!.selectDocumentType, style: TextStyle(fontSize: 12, color: Colors.black, fontWeight: FontWeight.normal)),
            value: selectedDocumentType, // Can be null initially
            items: documentTypes.map((docType) {
              return DropdownMenuItem<DocumentType>(
                value: docType,
                child: Text(docType.description, style: const TextStyle(fontSize: 12, color: Colors.black, fontWeight: FontWeight.normal)),
              );
            }).toList(),
            onChanged: (DocumentType? newValue) {
              setState(() {
                selectedDocumentType = newValue;
                _selectedDocumentValue = newValue?.value;
                selectedDocumentLabel = newValue?.description ?? AppLocalizations.of(context)!.idNumberPassportNumber;
              });
            },
          ),
        ],
      ),
    );
  }

}

class DocumentType {
  final String value;
  final String description;
  DocumentType({required this.value, required this.description});
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DocumentType &&
        other.value == value &&
        other.description == description;
  }

  @override
  int get hashCode => value.hashCode ^ description.hashCode;
}