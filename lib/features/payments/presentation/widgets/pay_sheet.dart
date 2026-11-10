import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:_50cents/core/theme/app_colors.dart';
import 'package:_50cents/core/theme/app_inputs.dart';
import 'package:_50cents/core/widgets/neon_button.dart';
import 'package:_50cents/features/payments/data/contact_lookup.dart';
import 'package:_50cents/features/payments/data/models/create_payment_record_request.dart';
import 'package:_50cents/features/payments/data/models/payment_category.dart';
import 'package:_50cents/features/payments/data/payment_repository.dart';
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

class _PaySheet extends ConsumerStatefulWidget {
  const _PaySheet({required this.target, this.scanned});

  final PayTarget target;
  final UpiPayment? scanned;

  @override
  ConsumerState<_PaySheet> createState() => _PaySheetState();
}

class _PaySheetState extends ConsumerState<_PaySheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _payeeController;
  late final TextEditingController _payeeNameController;
  late final TextEditingController _amountController;
  late final TextEditingController _noteController;

  bool _submitting = false;
  bool _updateBankBalance = false;
  String? _error;

  String? _selectedCategoryCode;
  String? _autoSuggestedName;
  bool _categoryManuallyChanged = false;
  bool _predicting = false;

  Timer? _predictDebounce;
  int _predictRequest = 0;

  Timer? _contactDebounce;
  int _contactRequest = 0;
  bool _lookingUpContact = false;
  String? _autoFilledContactName;

  bool get _isPhone => widget.target == PayTarget.phone;
  bool get _isScanned => widget.target == PayTarget.upi && widget.scanned != null;

  @override
  void initState() {
    super.initState();
    final scanned = widget.scanned;
    _payeeController = TextEditingController(text: scanned?.payeeVpa ?? '');
    _payeeNameController = TextEditingController(text: scanned?.payeeName ?? '');
    _amountController = TextEditingController(text: scanned?.amount ?? '');
    _noteController = TextEditingController(text: scanned?.note ?? '');

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_recipientName.trim().isNotEmpty) _schedulePrediction();
      if (_payeeController.text.trim().isNotEmpty) _scheduleContactLookup();
    });
  }

  @override
  void dispose() {
    _predictDebounce?.cancel();
    _contactDebounce?.cancel();
    _payeeController.dispose();
    _payeeNameController.dispose();
    _amountController.dispose();
    _noteController.dispose();
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

  /// Name sent to the payment-record and category-prediction APIs.
  String get _recipientName {
    final typedName = _payeeNameController.text.trim();
    if (typedName.isNotEmpty) return typedName;

    final rawPayee = _payeeController.text.trim();

    if (_isPhone) {
      final digits = rawPayee.replaceAll(RegExp(r'[^0-9]'), '');
      return digits.isEmpty ? '' : 'Mobile $digits';
    }

    return rawPayee;
  }

  /// Looks up the saved contact name after the phone number stops changing.
  void _scheduleContactLookup() {
    _contactDebounce?.cancel();
    final requestId = ++_contactRequest;
    final phone = _contactPhoneFromPayee();

    if (phone == null) {
      final autoName = _autoFilledContactName;
      final shouldClear = autoName != null && _payeeNameController.text.trim() == autoName;
      if (mounted && (_lookingUpContact || shouldClear)) {
        setState(() {
          _lookingUpContact = false;
          if (shouldClear) {
            _payeeNameController.clear();
            _autoFilledContactName = null;
          }
        });
        if (shouldClear) _schedulePrediction();
      }
      return;
    }

    _contactDebounce = Timer(const Duration(milliseconds: 350), () => _lookupContactName(phone, requestId));
  }

  /// Returns the phone number to look up. In phone mode this is the entered
  /// number; in UPI mode it is the local part of a phone-based VPA such as
  /// `9876543210@ybl`.
  String? _contactPhoneFromPayee() {
    final rawPayee = _payeeController.text.trim();

    if (_isPhone) {
      final digits = rawPayee.replaceAll(RegExp(r'[^0-9]'), '');
      if (digits.length >= 10 && digits.length <= 13) return digits;
      return null;
    }

    final localPart = rawPayee.split('@').first;
    final digits = localPart.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length == 10 && digits == localPart) return digits;
    return null;
  }

  Future<void> _lookupContactName(String phone, int requestId) async {
    if (mounted) setState(() => _lookingUpContact = true);

    final name = await ContactNameLookup.nameForPhone(phone);
    if (!mounted || requestId != _contactRequest) return;

    final current = _payeeNameController.text.trim();
    var nameChanged = false;

    setState(() {
      _lookingUpContact = false;

      if (name == null) {
        if (current.isNotEmpty && current == _autoFilledContactName) {
          _payeeNameController.clear();
          _autoFilledContactName = null;
          nameChanged = true;
        }
        return;
      }

      if (current.isEmpty || current == _autoFilledContactName) {
        _payeeNameController.text = name;
        _autoFilledContactName = name;
        nameChanged = true;
      }
    });

    if (nameChanged) _schedulePrediction();
  }

  /// Rebuilds the prediction after a short pause so we don't call the API on
  /// every keystroke.
  void _schedulePrediction() {
    _predictDebounce?.cancel();
    final requestId = ++_predictRequest;
    _predictDebounce = Timer(const Duration(milliseconds: 500), () => _predictCategory(requestId));
  }

  Future<void> _predictCategory(int requestId) async {
    final recipient = _recipientName.trim();
    if (recipient.isEmpty) {
      if (mounted && _predicting) setState(() => _predicting = false);
      return;
    }

    final note = _noteController.text.trim();
    if (mounted) setState(() => _predicting = true);

    try {
      final predicted = await ref
          .read(paymentRepositoryProvider)
          .predictCategory(recipient: recipient, note: note.isEmpty ? null : note);
      final categories = await ref.read(categoriesProvider.future);
      if (!mounted || requestId != _predictRequest) return;

      final match = _findCategory(categories, predicted);

      setState(() {
        _predicting = false;
        if (_categoryManuallyChanged) return;

        if (match != null) {
          _selectedCategoryCode = match.code;
          _autoSuggestedName = match.name;
        } else if (_autoSuggestedName != null) {
          _selectedCategoryCode = null;
          _autoSuggestedName = null;
        }
      });
    } catch (_) {
      // Category prediction is a convenience; payments can still be recorded.
      if (mounted && requestId == _predictRequest) {
        setState(() => _predicting = false);
      }
    }
  }

  PaymentCategory? _findCategory(List<PaymentCategory> categories, List<String> rawValues) {
    for (final rawValue in rawValues) {
      final value = rawValue.trim().toLowerCase();
      if (value.isEmpty) continue;

      for (final category in categories) {
        if (category.code.toLowerCase() == value || category.name.toLowerCase() == value) {
          return category;
        }
      }
    }
    return null;
  }

  Future<void> _pay() async {
    if (_submitting) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();

    final amountText = _amountController.text.trim().replaceAll(',', '');
    final amount = double.parse(amountText);
    final rawPayee = _payeeController.text.trim();
    final note = _noteController.text.trim();
    // UPI apps display this as the transaction note (`tn` in the intent).
    final noteForUpi = note.isEmpty ? 'Paid via 50cents' : note;
    final upiPayeeName = _payeeNameController.text.trim();

    final UpiPayment payment;
    if (_isPhone) {
      payment = phonePayment(rawPayee, note: noteForUpi, payeeName: upiPayeeName);
    } else {
      payment = UpiPayment(payeeVpa: rawPayee, payeeName: upiPayeeName.isEmpty ? null : upiPayeeName, note: noteForUpi);
    }

    final intent = payment.toUri(amountOverride: amount.toStringAsFixed(2));

    setState(() {
      _submitting = true;
      _error = null;
    });

    // Avoid saving a record when there is no app that can complete the payment.
    if (!await canLaunchUpiApp(intent)) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = 'No UPI app found on this device. Install a UPI app and try again.';
      });
      return;
    }

    try {
      await ref
          .read(paymentRepositoryProvider)
          .createPaymentRecord(
            CreatePaymentRecordRequest(
              amount: amount,
              recipientName: _recipientName,
              note: note,
              // The actual UPI app is picked in the system chooser, so the
              // payment medium is recorded as UPI.
              paymentMedium: 'UPI',
              transactionType: 'DEBIT',
              category: _selectedCategoryCode,
              updateBankBalance: _updateBankBalance,
            ),
          );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = apiErrorMessage(error);
      });
      return;
    }

    if (!mounted) return;

    final launched = await launchUpiApp(intent);
    if (!mounted) return;

    if (launched) {
      Navigator.of(context).pop(true);
      return;
    }

    setState(() {
      _submitting = false;
      _error = 'Payment was saved, but no UPI app could be opened. Install a UPI app and try again.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final categories = ref.watch(categoriesProvider);

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
                  if (_payeeNameController.text.trim().isNotEmpty) ...[
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
                          Icon(
                            _isPhone ? Icons.person_outline_rounded : Icons.storefront_outlined,
                            color: AppColors.textMuted,
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _payeeNameController.text.trim(),
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
                      _schedulePrediction();
                      _scheduleContactLookup();
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
                    controller: _payeeNameController,
                    maxLength: 255,
                    textInputAction: TextInputAction.next,
                    textCapitalization: TextCapitalization.words,
                    style: const TextStyle(color: AppColors.textPrimary),
                    decoration:
                        appInputDecoration(
                          _isPhone ? 'Payee name' : 'Payee name (optional)',
                          Icons.person_outline_rounded,
                          hint: _isPhone ? 'From your contacts' : 'Name shown in your UPI app',
                        ).copyWith(
                          counterText: '',
                          suffixIcon: _lookingUpContact
                              ? const Padding(
                                  padding: EdgeInsets.only(right: 14),
                                  child: SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 1.6, color: AppColors.neonBlue),
                                  ),
                                )
                              : null,
                        ),
                    onChanged: (_) {
                      _autoFilledContactName = null;
                      setState(() {
                        if (_error != null) _error = null;
                      });
                      _schedulePrediction();
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _amountController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                    style: const TextStyle(color: AppColors.textPrimary),
                    decoration: appInputDecoration('Amount', Icons.currency_rupee_rounded, hint: '0.00'),
                    onChanged: (_) {
                      if (_error != null) setState(() => _error = null);
                    },
                    validator: (value) {
                      final text = value?.trim().replaceAll(',', '') ?? '';
                      if (text.isEmpty) return 'Please enter an amount';
                      final amount = double.tryParse(text);
                      if (amount == null || amount <= 0) {
                        return 'Enter a valid amount';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _noteController,
                    minLines: 1,
                    maxLines: 2,
                    maxLength: 2048,
                    textInputAction: TextInputAction.done,
                    textCapitalization: TextCapitalization.sentences,
                    style: const TextStyle(color: AppColors.textPrimary),
                    decoration: appInputDecoration(
                      'Note (optional)',
                      Icons.notes_rounded,
                      hint: 'What is this payment for?',
                    ).copyWith(counterText: ''),
                    onChanged: (_) {
                      if (_error != null) setState(() => _error = null);
                      _schedulePrediction();
                    },
                  ),
                  const SizedBox(height: 16),
                  _buildCategorySection(categories),
                  const SizedBox(height: 14),
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.background.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: CheckboxListTile(
                      value: _updateBankBalance,
                      onChanged: (value) => setState(() => _updateBankBalance = value ?? false),
                      dense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 6),
                      controlAffinity: ListTileControlAffinity.leading,
                      activeColor: AppColors.neonBlue,
                      checkColor: Colors.black,
                      title: const Text(
                        'Update bank balance',
                        style: TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                      subtitle: const Text(
                        'Add this payment to your tracked bank balance.',
                        style: TextStyle(color: AppColors.textMuted, fontSize: 11.5, height: 1.35),
                      ),
                    ),
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
                    label: 'Pay',
                    icon: Icons.currency_rupee_rounded,
                    loading: _submitting,
                    onPressed: _submitting ? null : _pay,
                  ),
                  const SizedBox(height: 14),
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.lock_outline_rounded, size: 13, color: AppColors.textMuted),
                      SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          'Your payment is saved to your records first, then completed in your UPI app.',
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

  Widget _buildCategorySection(AsyncValue<List<PaymentCategory>> categories) {
    return categories.when(
      loading: () => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        decoration: BoxDecoration(
          color: AppColors.background.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: const Row(
          children: [
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 1.6, color: AppColors.neonBlue),
            ),
            SizedBox(width: 10),
            Text('Loading categories...', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
          ],
        ),
      ),
      error: (error, stackTrace) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.background.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            const Icon(Icons.category_outlined, color: AppColors.textMuted, size: 18),
            const SizedBox(width: 8),
            const Expanded(
              child: Text("Couldn't load categories.", style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
            ),
            TextButton(
              onPressed: () => ref.invalidate(categoriesProvider),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.neonBlue,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text('Retry', style: TextStyle(fontSize: 12)),
            ),
          ],
        ),
      ),
      data: (list) {
        if (list.isEmpty) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.background.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: const Row(
              children: [
                Icon(Icons.category_outlined, color: AppColors.textMuted, size: 18),
                SizedBox(width: 8),
                Text('No categories available', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
              ],
            ),
          );
        }

        PaymentCategory? selected;
        for (final category in list) {
          if (category.code == _selectedCategoryCode) {
            selected = category;
            break;
          }
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            InputDecorator(
              decoration: appInputDecoration('Category', Icons.category_outlined).copyWith(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
                suffixIcon: _predicting
                    ? const Padding(
                        padding: EdgeInsets.all(14),
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 1.6, color: AppColors.neonBlue),
                        ),
                      )
                    : null,
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: selected?.code,
                  isExpanded: true,
                  isDense: true,
                  dropdownColor: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.textMuted),
                  hint: const Text('Select category', style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
                  style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
                  items: [
                    for (final category in list)
                      DropdownMenuItem<String>(
                        value: category.code,
                        child: Text(category.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                      ),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _selectedCategoryCode = value;
                      _categoryManuallyChanged = true;
                      _autoSuggestedName = null;
                    });
                  },
                ),
              ),
            ),
            if (_autoSuggestedName != null) ...[
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.auto_awesome_rounded, color: AppColors.neonBlue, size: 13),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      'AI suggested: $_autoSuggestedName. You can change it.',
                      style: const TextStyle(color: AppColors.textMuted, fontSize: 11, height: 1.35),
                    ),
                  ),
                ],
              ),
            ],
          ],
        );
      },
    );
  }
}
