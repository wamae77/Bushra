import 'package:flutter/material.dart';
import '../bill-payment/page-home-bill-payment-main.dart';
import '../home/page-home-statements.dart';
import '../home/fund-transfers/page-home-transfer-v2-main.dart';
import '../l10n/app_localizations.dart';
import '../loans/page-home-loans.dart';
import '../models/account-card-model.dart';
import '../more-services/page-home-more-services.dart';
import 'dialog-error.dart';

class AccountCard extends StatefulWidget {
  final AccountCardModel card;
  final bool isActiveCard;

  const AccountCard({
    required Key key,
    required this.card,
    required this.isActiveCard
  }) : super(key: key);

  @override
  State<AccountCard> createState() => _AccountCardState();
}

class _AccountCardState extends State<AccountCard> {
  bool _balanceVisible = false;

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

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context).size;
    return Material(
      elevation: 1,
      shadowColor: Colors.grey.shade300,
      color: widget.isActiveCard ? Colors.red.shade800 : Colors.grey.shade400,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      child: Stack(
        children: <Widget>[
          Container(
            width: media.width - 40,
            padding: EdgeInsets.only(left: 22, right: 20, top: 2, bottom: 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    Text(
                      widget.card.accountStatus == 'ACTIVE' ? widget.card.accountType : 'Your account is currently',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: widget.card.accountStatus == 'ACTIVE' ? 15 : 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(width: 40), // Added spacing between account type and status
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(
                        color: widget.card.accountStatus == 'ACTIVE'
                            ? Colors.green.shade200
                            : Colors.red.shade200,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        widget.card.accountStatus,
                        style: TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.normal,
                          fontSize: 10,
                        ),
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const StatementScreen()),),
                      icon: Icon(Icons.arrow_forward_sharp),
                      color: Colors.white,
                    ),
                  ],
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    Text(
                      widget.card.accountStatus == 'ACTIVE' ? widget.card.accountNumber : 'Inactive',
                      style: Theme
                          .of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(
                        color: Colors.white,
                        fontSize: 16,
                        // fontWeight: FontWeight.bold,
                      ),
                    ),
                  ]
                ),
                // Conditional rendering based on some condition
                widget.card.accountStatus == 'ACTIVE' ?
                Row(
                  // Changed to Row to place eye icon next to balance
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _balanceVisible = !_balanceVisible;
                        });
                      },
                      child: _balanceVisible ?
                        Text(
                        widget.card.accountBalance,
                        style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                          :
                        Text('*******', style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2.0,),
                      ),
                    ),
                    IconButton(
                      padding: EdgeInsets.zero,
                      constraints: BoxConstraints(),
                      icon: Icon(_balanceVisible ? Icons.visibility : Icons.visibility_off,
                        color: Colors.white,
                        size: 20,
                      ),
                      onPressed: () {
                        setState(() {
                          _balanceVisible = !_balanceVisible;
                        });
                      },
                    ),
                  ],
                ) // Show this widget if the condition is true
                  :
                RichText(
                  textAlign: TextAlign.left,
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: 'To activate your bank account, \nplease ',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.normal,
                          fontSize: 10,
                        ),
                      ),
                      TextSpan(
                        text: 'contact the bank',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(vertical: true ? 4.0 : 2.0, horizontal: 2.0,),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      const spacing = 8.0;
                      const totalSpacing = spacing * 3;
                      final iconSize = (constraints.maxWidth - totalSpacing) / 4;
                      return Wrap(
                        spacing: spacing,
                        runSpacing: spacing,
                        children: [
                          _buildServiceIcon(
                            icon: Icons.swap_horiz,
                            label: AppLocalizations.of(context)!.fundTransfer,
                            isActive: widget.isActiveCard,
                            onTap: () {
                              if (widget.card.accountStatus == 'ACTIVE') {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (context) => const FundsTransferMainScreen()),
                                );
                              } else {
                                showErrorDialog(context, 'Oops!', 'You can not use account until activated', onRetry);
                              }
                            },
                            width: iconSize,
                          ),
                          _buildServiceIcon(
                            icon: Icons.receipt_long,
                            label: AppLocalizations.of(context)!.paybill,
                            isActive: widget.isActiveCard,
                            onTap: () {
                              if (widget.card.accountStatus == 'ACTIVE') {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (context) => const PayBillMainScreen()),
                                );
                              } else {
                                showErrorDialog(context, 'Oops!', 'You can not use account until activated', onRetry);
                              }
                            },
                            width: iconSize,
                          ),
                          _buildServiceIcon(
                            icon: Icons.monetization_on,
                            label: AppLocalizations.of(context)!.loans,
                            isActive: widget.isActiveCard,
                            onTap: () {
                              if (widget.card.accountStatus == 'ACTIVE') {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (context) => const LoansScreen()),
                                );
                              } else {
                                showErrorDialog(context, 'Oops!', 'You can not use account until activated', onRetry);
                              }
                            },
                            width: iconSize,
                          ),
                          _buildServiceIcon(
                            icon: Icons.grid_view,
                            label: AppLocalizations.of(context)!.moreServices,
                            isActive: widget.isActiveCard,
                            onTap: () {
                              if (widget.card.accountStatus == 'ACTIVE') {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (context) => const MoreServicesScreen()),
                                );
                              } else {
                                showErrorDialog(context, 'Oops!', 'You can not use account until activated', onRetry);
                              }
                            },
                            width: iconSize,
                          ),
                        ],
                      );
                    },
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

Widget _buildServiceIcon({
  required IconData icon,
  required String label,
  required bool isActive,
  required VoidCallback onTap,
  required double width,
}) {
  return SizedBox(
    width: width,
    child: GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: isActive ? Colors.red.shade900 : Colors.grey.shade500,
            child: Icon(
              icon,
              color: isActive ? Colors.white : Colors.grey.shade200,
              size: 18,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: isActive ? Colors.white : Colors.grey.shade200,
              fontSize: 10,
            ),
          ),
        ],
      ),
    ),
  );
}