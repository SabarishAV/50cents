import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:_50cents/core/theme/app_colors.dart';
import 'package:_50cents/core/theme/app_inputs.dart';
import 'package:_50cents/core/widgets/neon_button.dart';
import 'package:_50cents/features/payments/data/upi_payment.dart';

enum PayTarget { phone, upi }

/// Opens the UPI redirect sheet.
///
/// Returns `true` when a UPI app was launched.
Future<bool> showPaySheet(BuildContext context, {required PayTarget target, UpiPayment? scanned}) async {
  final launched = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) => _PaySheet(target: target, scanned: scanned),
  );
  return launched ?? false;
}

class _PaySheet extends StatefulWidget {
  const _PaySheet({required this.target, this.scanned});

  final PayTarget target;
  final UpiPayment? scanned;

  @override
  State<_PaySheet> createState() => _PaySheetState();
}

class _PaySheetState extends State<_PaySheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _payeeController;
  late final TextEditingController _amountController;
  bool _launching = false;
  String? _error;

  bool get _isPhone => widget.target == PayTarget.phone;
  bool get _isScanned => widget.target == PayTarget.upi && widget.scanned != null;

  @override
  void initState() {
    super.initState();
    final scanned = widget.scanned;
    _payeeController = TextEditingController(text: scanned?.payeeVpa ?? '');
    _amountController = TextEditingController(text: scanned?.amount ?? '');
  }

  @override
  void dispose() {
    _payeeController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  String get _title {
    if (_isPhone) return 'Send to phone number';
    if (_isScanned) return 'Pay via scanned QR';
    return 'Send to UPI ID';
  }

  String get _subtitle {
    if (_isPhone) return 'Enter a phone number linked to UPI.';
    if (_isScanned) return 'Review the payee, add an amount and continue in your UPI app.';
    return 'Enter the UPI ID (VPA) you want to pay.';
  }

  IconData get _icon {
    if (_isPhone) return Icons.phone_android_rounded;
    if (_isScanned) return Icons.qr_code_scanner_rounded;
    return Icons.alternate_email_rounded;
  }

  Future<void> _openUpiApp() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();

    final amountText = _amountController.text.trim().replaceAll(',', '');
    final amount = amountText.isEmpty ? null : double.parse(amountText).toStringAsFixed(2);
    final rawPayee = _payeeController.text.trim();

    final UpiPayment payment;
    if (_isPhone) {
      payment = phonePayment(rawPayee);
    } else {
      payment = UpiPayment(
        payeeVpa: rawPayee,
        payeeName: widget.scanned?.payeeName,
        note: widget.scanned?.note ?? 'Paid via 50cents',
      );
    }

    setState(() {
      _launching = true;
      _error = null;
    });

    final launched = await launchUpiApp(payment.toUri(amountOverride: amount));
    if (!mounted) return;

    if (launched) {
      Navigator.of(context).pop(true);
      return;
    }

    setState(() {
      _launching = false;
      _error = 'No UPI app found on this device. Install a UPI app and try again.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(22, 12, 22, 24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Center(
                    child: Container(
                      width: 42,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(4)),
                    ),
                  ),
                  Row(
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: AppColors.neonBlue.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.neonBlue.withValues(alpha: 0.3)),
                        ),
                        child: Icon(_icon, color: AppColors.neonBlue, size: 22),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _title,
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _subtitle,
                              style: const TextStyle(color: AppColors.textMuted, fontSize: 12, height: 1.35),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (_isScanned && widget.scanned?.payeeName != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.background.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.storefront_outlined, color: AppColors.textMuted, size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              widget.scanned!.payeeName!,
                              style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
                            ),
                          ),
                          const Icon(Icons.verified_rounded, color: AppColors.income, size: 16),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 22),
                  TextFormField(
                    controller: _payeeController,
                    keyboardType: _isPhone ? TextInputType.phone : TextInputType.emailAddress,
                    inputFormatters: _isPhone ? [FilteringTextInputFormatter.allow(RegExp(r'[0-9 ]'))] : null,
                    style: const TextStyle(color: AppColors.textPrimary),
                    decoration: appInputDecoration(
                      _isPhone ? 'Phone number' : 'UPI ID',
                      _isPhone ? Icons.phone_outlined : Icons.alternate_email_rounded,
                      hint: _isPhone ? '98765 43210' : 'name@bank',
                    ),
                    onChanged: (_) {
                      if (_error != null) setState(() => _error = null);
                    },
                    validator: (value) {
                      final text = value?.trim() ?? '';
                      if (text.isEmpty) {
                        return _isPhone ? 'Please enter a phone number' : 'Please enter a UPI ID';
                      }
                      if (_isPhone) {
                        final digits = text.replaceAll(RegExp(r'[^0-9]'), '');
                        if (digits.length < 10 || digits.length > 13) {
                          return 'Enter a valid phone number';
                        }
                      } else if (!RegExp(r'^[a-zA-Z0-9._-]{2,}@[a-zA-Z]{2,}$').hasMatch(text)) {
                        return 'Enter a valid UPI ID (like name@bank)';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _amountController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                    style: const TextStyle(color: AppColors.textPrimary),
                    decoration: appInputDecoration('Amount (optional)', Icons.currency_rupee_rounded, hint: '0.00'),
                    onChanged: (_) {
                      if (_error != null) setState(() => _error = null);
                    },
                    validator: (value) {
                      final text = value?.trim().replaceAll(',', '') ?? '';
                      if (text.isEmpty) return null;
                      final amount = double.tryParse(text);
                      if (amount == null || amount <= 0) {
                        return 'Enter a valid amount';
                      }
                      return null;
                    },
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.expense.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.expense.withValues(alpha: 0.35)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline_rounded, color: AppColors.expense, size: 17),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _error!,
                              style: const TextStyle(color: AppColors.expense, fontSize: 12, height: 1.35),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  NeonButton(
                    label: 'Open UPI app',
                    icon: Icons.open_in_new_rounded,
                    loading: _launching,
                    onPressed: _launching ? null : _openUpiApp,
                  ),
                  const SizedBox(height: 14),
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.lock_outline_rounded, size: 13, color: AppColors.textMuted),
                      SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          '50cents never handles your money. Payment is completed in your UPI app.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.textMuted, fontSize: 11, height: 1.4),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
