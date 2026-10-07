import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:bushra_mobile/utils/dto/api-response-login.dart';
import 'package:bushra_mobile/qrcode/page-home-qrcode-pin.dart';
import '../home/page-home.dart';
import '../l10n/app_localizations.dart';
import '../utils/api-customer-transfers.dart';
import '../utils/dto/api-response-get-charges.dart';
import '../utils/providers/provider-balances.dart';
import '../utils/providers/provider-session.dart';
import '../utils/reference-generator.dart';
import '../utils/util-log-service.dart';
import '../../widgets/dialog-transaction-charges.dart';

class MerchantPaymentScreen extends StatefulWidget {
  final String? pointOfInitiationMethod;
  final String? payloadFormatIndicator;
  final String? qrType;
  final String? transferType;
  final String? domainName;
  final String? acquirerId;
  final String? merchantId;
  final String? countryCode;
  final String? merchantCategoryCodeMcc;
  final String? merchantCity;
  final String? crc;
  final String? terminalLabel;
  final String? merchantName;
  final String? postalCode;
  final String? storeLabel;
  final String? currencyCode;
  final String? transactionAmount;

  const MerchantPaymentScreen({super.key,
    this.pointOfInitiationMethod,
    this.payloadFormatIndicator,
    this.qrType,
    this.transferType,
    this.domainName,
    this.acquirerId,
    this.merchantId,
    this.countryCode,
    this.merchantCategoryCodeMcc,
    this.merchantCity,
    this.crc,
    this.terminalLabel,
    this.merchantName,
    this.postalCode,
    this.storeLabel,
    this.currencyCode,
    this.transactionAmount,

  });
  @override
  State<MerchantPaymentScreen> createState() => _MerchantPaymentScreenState();
}

class _MerchantPaymentScreenState extends State<MerchantPaymentScreen> {
  final PageController _pageControllerAccountCard = PageController(viewportFraction: 0.9);
  int _currentAccountCardIndex = 0;
  late String _currentAccountCardIndexAccountNumber;
  late String _currentAccountCardIndexCurrency;
  bool hideBalance = false;
  bool isFetchingCharges = false;
  final referenceGenerator = ReferenceGenerator();
  final apiCustomerFundsTransfer = ApiCustomerFundsTransfers();

  TextEditingController beneficiaryNarration = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  final List<double> quickAmounts = [50, 100, 500, 1000];
  double? selectedAmount;

  String? selectedAccount;
  String debitAccountNumber ='';
  String debitAccountCurrency ='';
  String debitIban = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final balanceProvider = Provider.of<BalanceProvider>(context, listen: false);
      if (balanceProvider.accounts.isNotEmpty) {
        _currentAccountCardIndexAccountNumber = balanceProvider.accounts[0].accountNumber;
        _currentAccountCardIndexCurrency = balanceProvider.accounts[0].currency;
      }
    });

    // Prefill amount from QR code
    if (widget.transactionAmount != null && widget.transactionAmount!.isNotEmpty) {
      _amountController.text = widget.transactionAmount!;
      selectedAmount = double.tryParse(widget.transactionAmount!);
    }
  }

  @override
  void dispose() {
    _pageControllerAccountCard.dispose();
    super.dispose();
  }

  void _onPageAccountCardChanged(int index, String account, String currency) {
    if (!mounted) return;
    setState(() {
      _currentAccountCardIndex = index;
      _currentAccountCardIndexAccountNumber = account;
      _currentAccountCardIndexCurrency = currency;
    });
  }

  void showSnackBar(BuildContext context, String message, Color color) {
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

  Future<void> _fetchCharges(String phone, double amount) async{
    try{
      setState(() {
        isFetchingCharges = true;
      });
      var response = await apiCustomerFundsTransfer.transactionCharges(
        debitAccountNumber,
        widget.merchantId!,
        phone,
        debitAccountCurrency,
        amount,
      );
      ApiResponseGetTransactionCharges transactionCharges = ApiResponseGetTransactionCharges.fromJson(response);
      if(transactionCharges.data == null){
        showSnackBar(context, 'Failed to Fetch Charges', Colors.red);
        setState(() {
          isFetchingCharges = false;
        });
        return;
      }
      if(transactionCharges.data?.response == null){
        showSnackBar(context, 'Failed to Fetch Charges', Colors.red);
        setState(() {
          isFetchingCharges = false;
        });
        return;
      }

      if(transactionCharges.data?.responseCode == '00'){
        showDialog(
          context: context,
          builder: (context) => ConfirmTransferDialog(
            // dialogDescription: "Please confirm you are making a QR Payment Transfer",
            dialogDescription: "Please confirm you are making a QR Payment Transfer",
            amount: '$debitAccountCurrency ${_amountController.text}',
            recipientAccount: widget.merchantId!,
            sourceAccount: debitAccountNumber,
            charges: '$debitAccountCurrency ${transactionCharges.data?.chargeAmount.toString()}',
            onCancel: () {
              // Handle cancel
              Navigator.pop(context);
            },
            onConfirm: () {
              // Handle confirmation
              final resolvedTransferType =
                  (widget.transferType?.toLowerCase() == 'dynamic') ? 'P2MD' : 'P2M';
              Navigator.push(context, MaterialPageRoute(builder: (context) => PinInputQRCodeTransactionScreen(
                transferType: resolvedTransferType,
                transactionReference: referenceGenerator.generateUniqueReference(true),
                debitAccount: debitIban,
                debitPhoneNumber: phone,
                beneficiaryAccount: widget.merchantId ?? 'MerchantID',
                beneficiaryName: widget.merchantName ?? 'MerchantName',
                currency: debitAccountCurrency,
                transactionAmount: _amountController.text,
                narration: beneficiaryNarration.text,
                beneficiaryBankCode: widget.acquirerId ?? 'AcquireID',
                isFavorite: false,
              )));
            },
          ),
        );
      }else{
        showSnackBar(context, 'Failed to Fetch Charges', Colors.red);
        setState(() {
          isFetchingCharges = false;
        });
      }
    } catch(error, stack){
      LoggerService.reportUnexpectedError(error, stack);
      showSnackBar(context, 'Failed to Fetch Charges.$error', Colors.red);
      setState(() {
        isFetchingCharges = false;
      });
    }finally{
      setState(() {
        isFetchingCharges = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final authProvider = Provider.of<SessionProvider>(context).user;
    final accounts = authProvider?.accounts;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () {
            Navigator.push(context, MaterialPageRoute(builder: (context) => const DashboardScreen()));
          },
        ),
        title: Text(AppLocalizations.of(context)!.payUsingQrCode,),
        centerTitle: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 130,
              child: Consumer<BalanceProvider>(
                builder: (context, balanceProvider, child) {
                  return PageView(
                    controller: _pageControllerAccountCard,
                    onPageChanged: (index) {
                      final account = balanceProvider.accounts[index]; // Get account from provider
                      _onPageAccountCardChanged(index, account.accountNumber, account.currency);
                    },
                    children: balanceProvider.accounts.asMap().entries.map<Widget>((entry) {
                      int index = entry.key;
                      var account = entry.value;
                      final double currentBalance =
                          balanceProvider.accountBalances[account.accountNumber]?.currentBalance ?? 0.0;
                      final double netBalance =
                          balanceProvider.accountBalances[account.accountNumber]?.netBalance ?? 0.0;
                      final double availableBalance =
                          balanceProvider.accountBalances[account.accountNumber]?.availableBalance ?? 0.0;
                      String accountType;
                      if(account.accountType=='S'){
                        accountType = 'Saving Account';
                      }else if(account.accountType=='C'){
                        accountType = 'Current Account';
                      }else if(account.accountType=='D'){
                        accountType = 'Term Deposit Account';
                      }else{
                        accountType = account.accountType;
                      }
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            _currentAccountCardIndex = index;
                            _currentAccountCardIndexAccountNumber = account.accountNumber;
                            _currentAccountCardIndexCurrency = account.currency;
                          });
                        },
                        child: _buildAccountCardDetail(
                          accountType,
                          account.currency,
                          account.accountNumber,
                          availableBalance,
                          isDarkMode,
                          _currentAccountCardIndex == index,
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
            ),
            const SizedBox(height: 18,),
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.red.shade50, // light red background
                borderRadius: BorderRadius.circular(20), // rounded edges
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Section title
                  Text(
                    AppLocalizations.of(context)!.merchantDetails,
                    style: TextStyle(
                      color: Colors.red.shade900,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Merchant name row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                      AppLocalizations.of(context)!.merchantName,
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                      Text(
                        widget.merchantName ?? ':::',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                        softWrap: false,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Merchant ID row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        AppLocalizations.of(context)!.merchantId2345678,
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                      Text(
                        widget.merchantId ?? ':::',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                        softWrap: false,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const SizedBox(height: 10),
             Text(AppLocalizations.of(context)!.howMuchWouldYouLikeToTransfer),
            //TODO -- NEW ------------------------
            const SizedBox(height: 8),
            _buildTextInputFieldGrayAmountMain("Enter Amount", "eg 1000.00", _amountController, maxLines: 1),
            const SizedBox(height: 14),
             Center(
              child: Text(
                AppLocalizations.of(context)!.theMinimumTransferAmountIs01,
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 40, // Fixed height for the chip row
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: quickAmounts.map((amount) {
                    final isSelected = selectedAmount == amount;
                    return Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: ChoiceChip(
                        label: Text(
                          '\$${amount.toStringAsFixed(0)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: isSelected ? Colors.white : Colors.grey.shade600,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        selected: isSelected,
                        onSelected: (selected) {
                          setState(() {
                            _amountController.text = amount.toStringAsFixed(2);
                          });
                          // ✅ Call API immediately when quick amount is chosen
                          //_callExchangeRatesApi(amount.toStringAsFixed(2));
                        },
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                          side: BorderSide(
                            color: isSelected ? Colors.red.shade900 : Colors.grey.shade200,
                            width: 2,
                          ),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        showCheckmark: false,
                        selectedColor: Colors.red.shade900,
                        backgroundColor: Colors.grey[200],
                        elevation: 2,
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
            //TODO -- NEW ------------------------
            const SizedBox(height: 7),
            Text(AppLocalizations.of(context)!.accountFrom, style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 8),
            _buildTextInputDropDownFieldRed(accounts),
            const SizedBox(height: 7),
            _buildInputField(AppLocalizations.of(context)!.narration, "Eg. Reason"),
            const SizedBox(height: 7),
            const SizedBox(height: 30),
            // Transfer Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  //TODO
                  if(widget.acquirerId == '' || widget.acquirerId!.isEmpty){
                    showSnackBar(context, 'Invalid QR Code format, Please try again later', Colors.red);
                    return;
                  }
                  if(widget.merchantId == '' || widget.merchantId!.isEmpty){
                    showSnackBar(context, 'Invalid QR Code format, Please try again later', Colors.red);
                    return;
                  }
                  if(debitIban == '' || debitIban.isEmpty){
                    showSnackBar(context, 'Invalid Debit IBAN / Account Number, Please select debit account', Colors.red);
                    return;
                  }
                  if(debitAccountCurrency == '' || debitAccountCurrency.isEmpty){
                    showSnackBar(context, 'Invalid Debit IBAN / Account Number, Please select debit account', Colors.red);
                    return;
                  }
                  if(_amountController.text == '' || _amountController.text.isEmpty){
                    showSnackBar(context, 'Invalid Amount Entry, Please enter correct debit amount', Colors.red);
                    return;
                  }
                  if(beneficiaryNarration.text == '' || beneficiaryNarration.text.isEmpty){
                    beneficiaryNarration.text = 'P2M SPS Payment';
                  }
                  String amountStr = _amountController.text;
                  double? amount = double.tryParse(amountStr);
                  if (amount != null) {
                    print(amount); // 123.45
                    _fetchCharges(authProvider!.phoneNumber, amount);
                  } else {
                    showSnackBar(context, 'Invalid Amount Entry, Please enter correct debit amount', Colors.red);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade900,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: isFetchingCharges ?
                const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
                    :
                const Text(
                  "PAY",
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }


  Widget _buildInputField(String label, String hint, {int maxLines = 1}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey)),
        const SizedBox(height: 8),
        TextField(
          controller: beneficiaryNarration,
          maxLines: maxLines,
          decoration: InputDecoration(
            hintText: hint,
            filled: true,
            fillColor: Colors.grey.shade100,
            border: OutlineInputBorder(
              borderSide: BorderSide.none,
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTextInputFieldGrayAmountMain(String label, String hint,TextEditingController controller, {int maxLines = 1}){
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade100, // Light red background
        borderRadius: BorderRadius.circular(8), // Rounded corners
      ),
      child: Stack(
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          const SizedBox(height: 8),
          TextField(
            controller: controller,
            maxLines: maxLines,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              hintText: hint,
              filled: true,
              fillColor: Colors.grey.shade100,
              border: OutlineInputBorder(
                borderSide: BorderSide.none,
                borderRadius: BorderRadius.circular(8),
              ),
              prefixIcon: Icon(
                Icons.attach_money,
                color: Colors.red.shade900,
              ),
              suffixIcon: _amountController.text.isNotEmpty
                  ? IconButton(
                icon: Icon(
                  Icons.clear,
                  color: Colors.red.shade900,
                ),
                onPressed: () {
                  _amountController.clear();
                },
              ) : null,
            ),
            onSubmitted: (value) {
              print('INPUT VALUE AMOUNT ===== : $value');
              if (value.isNotEmpty) {
                //_callExchangeRatesApi(value);
              }
            },
          ),
          Positioned(
            left: 10, // Aligning with the inner curve
            right: 10, // Aligning with the inner curve
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

  Widget _buildTextInputDropDownFieldRed(List<Account>? accounts){
    return Container(
      decoration: BoxDecoration(
        color: Colors.red.shade50, // Light red background
        borderRadius: BorderRadius.circular(8), // Rounded corners
      ),
      child: Stack(
        children: [
          DropdownButtonFormField<String>(
            value: accounts?.any((a) => a.accountNumber == selectedAccount) == true
                ? selectedAccount
                : null,  // Avoid invalid value error
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.red.shade50,
              border: OutlineInputBorder(
                borderSide: BorderSide.none,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            hint: Text(AppLocalizations.of(context)!.selectAnAccount, style: TextStyle(fontSize: 12),),
            dropdownColor: Colors.white,
            icon: const Icon(Icons.arrow_drop_down),
            items: accounts?.map<DropdownMenuItem<String>>((account) {
              String maskedAccount = "A/C #${account.accountNumber}";
              // String maskedAccount = "A/C #${account.accountNumber.substring(0, 4)}****${account.accountNumber.substring(account.accountNumber.length - 4)}";
              return DropdownMenuItem<String>(
                value: account.accountNumber,
                child: Text(maskedAccount, style: TextStyle(fontSize: 12),),
              );
            }).toList(),
            onChanged: (String? newValue) {
              setState(() {
                selectedAccount = newValue;
                debitAccountNumber = newValue!;
                debitIban = accounts?.firstWhere((account) => account.accountNumber == newValue).iban ?? '';
                debitAccountCurrency = accounts?.firstWhere((account) => account.accountNumber == newValue).currency ?? '';
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

  Widget _buildAccountCardDetail(String accountTitle, String currency, String account, double balance, bool isDarkMode, bool isActiveCard) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8),
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: isActiveCard ? Colors.red.shade900 : Colors.grey.shade300,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28, // Adjust radius as needed
            backgroundColor: Colors.white,
            child: Icon(
              Icons.account_balance_wallet,
              size: 40,
              color: isActiveCard ? Colors.red.shade900 : Colors.grey.shade300,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  accountTitle,
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  'A/C # $account',
                  style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                RichText(
                  //textAlign: TextAlign.center,
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: AppLocalizations.of(context)!.actualBalance,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      TextSpan(
                        text: hideBalance == false ? "$currency ${NumberFormat("#,##0.00").format(balance)}" : "**** ****",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16, // Larger font for balance
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

}