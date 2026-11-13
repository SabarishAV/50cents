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
import 'package:_50cents/features/payments/presentation/widgets/contact_picker_sheet.dart';
import 'package:_50cents/features/payments/presentation/widgets/payment_ui.dart';

enum PayTarget { phone, upi }

/// Opens the UPI redirect sheet.
///
/// Pass [phone] to pre-fill the payee in phone mode (e.g. after picking a
/// contact). Returns `true` when a UPI app was launched.
Future<bool> showPaySheet(BuildContext context, {required PayTarget target, UpiPayment? scanned, String? phone}) async {
  final launched = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) => _PaySheet(target: target, scanned: scanned, phone: phone),
  );
  return launched ?? false;
}

class _PaySheet extends ConsumerStatefulWidget {
  const _PaySheet({required this.target, this.scanned, this.phone});

  final PayTarget target;
  final UpiPayment? scanned;
  final String? phone;

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

  /// Contact name auto-filled into the payee name field. Tracks what we
  /// prefilled so a later lookup replaces or clears it only while the user
  /// has not typed their own text.
  String? _autoFilledContactName;

  /// Contact name detected for the entered phone number / phone-based VPA.
  /// Shown in the chip above; editing the payee name field never changes it —
  /// it only follows the entered number.
  String? _detectedContactName;

  bool get _isPhone => widget.target == PayTarget.phone;
  bool get _isScanned => widget.target == PayTarget.upi && widget.scanned != null;

  double? get _enteredAmount {
    final text = _amountController.text.trim().replaceAll(',', '');
    final value = double.tryParse(text);
    return value == null || value <= 0 ? null : value;
  }

  @override
  void initState() {
    super.initState();
    final scanned = widget.scanned;
    _payeeController = TextEditingController(text: scanned?.payeeVpa ?? widget.phone ?? '');
    _payeeNameController = TextEditingController(text: scanned?.payeeName ?? '');
    _amountController = TextEditingController(text: scanned?.amount ?? '');
    _noteController = TextEditingController(text: scanned?.note ?? '');

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_predictionRecipient.trim().isNotEmpty) _schedulePrediction();
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
    if (_isPhone) return 'Send to a phone number';
    if (_isScanned) return 'Pay via scanned QR';
    return 'Send to a UPI ID';
  }

  String get _subtitle {
    if (_isPhone) return 'Enter a phone number linked to UPI.';
    if (_isScanned) return 'Review the payee, add an amount and continue in your UPI app.';
    return 'Enter the UPI ID (VPA) you want to pay.';
  }

  IconData get _icon {
    if (_isPhone) return Icons.phone_android_rounded;
    if (_isScanned) return Icons.qr_code_2_rounded;
    return Icons.alternate_email_rounded;
  }

  /// The recipient name detected from the scanned QR or the device contacts.
  ///
  /// Display-only: editing the payee name field never changes it. It only
  /// follows the scanned QR or the entered phone number / phone-based VPA.
  String? get _detectedPayeeName {
    if (_isScanned) {
      final fromQr = widget.scanned?.payeeName?.trim();
      if (fromQr != null && fromQr.isNotEmpty) return fromQr;
    }
    return _detectedContactName;
  }

  /// Icon showing where the detected name came from.
  IconData get _detectedPayeeIcon {
    final fromQr = _isScanned ? widget.scanned?.payeeName?.trim() : null;
    return (fromQr != null && fromQr.isNotEmpty) ? Icons.qr_code_2_rounded : Icons.contacts_rounded;
  }

  /// Recipient string sent to the category-prediction API: the typed payee
  /// name, else the detected contact/QR name, else the raw identifier.
  String get _predictionRecipient {
    final typedName = _payeeNameController.text.trim();
    if (typedName.isNotEmpty) return typedName;

    final detected = _detectedPayeeName;
    if (detected != null && detected.isNotEmpty) return detected;

    final rawPayee = _payeeController.text.trim();
    if (_isPhone) return rawPayee.replaceAll(RegExp(r'[^0-9]'), '');

    return rawPayee;
  }

  /// Opens the contact picker and fills the phone field with the chosen
  /// contact's number (digits only).
  Future<void> _pickContact() async {
    final number = await showContactPicker(context);
    if (!mounted || number == null) return;

    setState(() {
      _payeeController.text = number;
      _error = null;
    });
    _schedulePrediction();
    _scheduleContactLookup();
  }

  /// Looks up the saved contact name after the phone number stops changing.
  void _scheduleContactLookup() {
    _contactDebounce?.cancel();
    final requestId = ++_contactRequest;
    final phone = _contactPhoneFromPayee();

    if (phone == null) {
      final autoName = _autoFilledContactName;
      final shouldClearField = autoName != null && _payeeNameController.text.trim() == autoName;
      final hadDetected = _detectedContactName != null;
      if (mounted && (_lookingUpContact || shouldClearField || hadDetected)) {
        setState(() {
          _lookingUpContact = false;
          _detectedContactName = null;
          if (shouldClearField) {
            _payeeNameController.clear();
            _autoFilledContactName = null;
          }
        });
        if (shouldClearField || hadDetected) _schedulePrediction();
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
      // The detected name shown in the chip follows the entered number only;
      // user edits to the payee name field never touch it.
      _detectedContactName = name;

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
    final recipient = _predictionRecipient.trim();
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
    // UPI apps display this as the transaction note (`tn` in the intent).
    // An empty note is omitted entirely — no default text is injected.
    final note = _noteController.text.trim();
    final upiNote = note.isEmpty ? null : note;
    final upiPayeeName = _payeeNameController.text.trim();

    // The record stores who was paid: the identifier (UPI ID or phone
    // number) plus the optional payee name from the field above.
    final recipientIdentifier = _isPhone ? rawPayee.replaceAll(RegExp(r'[^0-9]'), '') : rawPayee;

    final UpiPayment payment;
    if (_isPhone) {
      payment = phonePayment(rawPayee, note: upiNote, payeeName: upiPayeeName);
    } else {
      payment = UpiPayment(payeeVpa: rawPayee, payeeName: upiPayeeName.isEmpty ? null : upiPayeeName, note: upiNote);
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
              // Optional: nothing is sent when the user entered no name.
              recipientName: upiPayeeName.isEmpty ? null : upiPayeeName,
              // The UPI ID (or phone number) the payment was sent to.
              recipientIdentifier: recipientIdentifier,
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

  void _setQuickAmount(int amount) {
    setState(() {
      _amountController.text = amount.toString();
      _amountController.selection = TextSelection.collapsed(offset: _amountController.text.length);
      _error = null;
    });
  }

  void _toggleBankBalance() {
    setState(() => _updateBankBalance = !_updateBankBalance);
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final height = (media.size.height - media.viewInsets.bottom) * 0.93;
    final categories = ref.watch(categoriesProvider);
    final amount = _enteredAmount;

    return Padding(
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: PaymentSheetShell(
        height: height,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const PaymentSheetHandle(),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 0, 14, 0),
              child: Row(
                children: [
                  PaymentIconBadge(icon: _icon, size: 44, radius: 14),
                  const SizedBox(width: 12),
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
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(_subtitle, style: const TextStyle(color: AppColors.textMuted, fontSize: 12, height: 1.35)),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded, color: AppColors.textMuted, size: 20),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: SingleChildScrollView(
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(22, 2, 22, 12),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_isScanned)
                        _ScannedPayeeCard(scanned: widget.scanned!)
                      else ...[
                        TextFormField(
                          controller: _payeeController,
                          keyboardType: _isPhone ? TextInputType.phone : TextInputType.emailAddress,
                          inputFormatters: _isPhone ? [FilteringTextInputFormatter.digitsOnly] : null,
                          style: const TextStyle(color: AppColors.textPrimary),
                          decoration: appInputDecoration(
                            _isPhone ? 'Phone number' : 'UPI ID',
                            _isPhone ? Icons.phone_outlined : Icons.alternate_email_rounded,
                            hint: _isPhone ? '9876543210' : 'name@bank',
                            suffixIcon: _isPhone
                                ? IconButton(
                                    tooltip: 'Choose from contacts',
                                    onPressed: _pickContact,
                                    icon: const Icon(Icons.contacts_rounded, color: AppColors.neonBlue, size: 20),
                                  )
                                : null,
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
                        const SizedBox(height: 12),
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
                        if (!_isScanned && _detectedPayeeName != null) ...[
                          const SizedBox(height: 8),
                          _DetectedPayeeChip(name: _detectedPayeeName!, icon: _detectedPayeeIcon),
                        ],
                      ],
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          const PaymentSectionLabel(label: 'Amount'),
                          const Spacer(),
                          if (amount != null)
                            Text(
                              'Paying with UPI',
                              style: TextStyle(
                                color: AppColors.textMuted.withValues(alpha: 0.85),
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: _amountController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.8,
                        ),
                        decoration: appInputDecoration(
                          'Amount',
                          Icons.currency_rupee_rounded,
                          hint: '0.00',
                        ).copyWith(contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14)),
                        onChanged: (_) {
                          setState(() {
                            if (_error != null) _error = null;
                          });
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
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          for (final quick in const <int>[100, 500, 1000, 2000]) ...[
                            Expanded(
                              child: _QuickAmountChip(amount: quick, onTap: () => _setQuickAmount(quick)),
                            ),
                            if (quick != 2000) const SizedBox(width: 8),
                          ],
                        ],
                      ),
                      const SizedBox(height: 20),
                      const PaymentSectionLabel(label: 'Details'),
                      const SizedBox(height: 10),
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
                      const SizedBox(height: 12),
                      _buildCategorySection(categories),
                      const SizedBox(height: 12),
                      _BankBalanceToggle(selected: _updateBankBalance, onTap: _toggleBankBalance),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(22, 12, 22, 12),
              decoration: const BoxDecoration(
                color: AppColors.surface,
                border: Border(top: BorderSide(color: AppColors.border)),
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_error != null) ...[_ErrorBanner(message: _error!), const SizedBox(height: 10)],
                    NeonButton(
                      label: amount == null ? 'Pay with UPI' : 'Pay ${formatInr(amount)}',
                      icon: Icons.bolt_rounded,
                      loading: _submitting,
                      onPressed: _submitting ? null : _pay,
                      height: 52,
                    ),
                    const SizedBox(height: 10),
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.lock_outline_rounded, size: 12, color: AppColors.textMuted),
                        SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            'Saved to your records first, then completed in your UPI app.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: AppColors.textMuted, fontSize: 10.5, height: 1.4),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
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
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
                        child: Row(
                          children: [
                            Icon(
                              paymentCategoryIcon(code: category.code, name: category.name),
                              color: AppColors.neonBlue,
                              size: 15,
                            ),
                            const SizedBox(width: 8),
                            Expanded(child: Text(category.name, maxLines: 1, overflow: TextOverflow.ellipsis)),
                          ],
                        ),
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
            if (_autoSuggestedName != null || _predicting) ...[
              const SizedBox(height: 9),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    _predicting ? Icons.sync_rounded : Icons.auto_awesome_rounded,
                    color: AppColors.neonBlue,
                    size: 14,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _predicting
                          ? 'Predicting the best category...'
                          : 'Auto-suggested from the payee. Tap the field to change it.',
                      style: const TextStyle(color: AppColors.textMuted, fontSize: 10.5, height: 1.4),
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

class _ScannedPayeeCard extends StatelessWidget {
  const _ScannedPayeeCard({required this.scanned});

  final UpiPayment scanned;

  @override
  Widget build(BuildContext context) {
    final name = scanned.payeeName?.trim();
    final label = (name == null || name.isEmpty) ? scanned.payeeVpa : name;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.neonBlue.withValues(alpha: 0.16), AppColors.surface],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.neonBlue.withValues(alpha: 0.26)),
      ),
      child: Row(
        children: [
          PaymentAvatar(label: label, size: 46),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.textPrimary, fontSize: 14.5, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    const Icon(Icons.alternate_email_rounded, color: AppColors.textMuted, size: 12),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        scanned.payeeVpa,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: AppColors.textMuted, fontSize: 11.5),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          const PaymentPill(label: 'Scanned', icon: Icons.qr_code_2_rounded, fontSize: 9.5),
        ],
      ),
    );
  }
}

class _DetectedPayeeChip extends StatelessWidget {
  const _DetectedPayeeChip({required this.name, required this.icon});

  final String name;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.neonBlue.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: AppColors.neonBlue.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.neonBlueBright, size: 14),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: AppColors.neonBlueBright, fontSize: 11, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 8),
          const Text(
            'FROM CONTACTS',
            style: TextStyle(
              color: AppColors.textMuted,
              fontSize: 8.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickAmountChip extends StatelessWidget {
  const _QuickAmountChip({required this.amount, required this.onTap});

  final int amount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: AppColors.background.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.border),
          ),
          child: Text(
            '₹$amount',
            style: const TextStyle(color: AppColors.textMuted, fontSize: 11.5, fontWeight: FontWeight.w700),
          ),
        ),
      ),
    );
  }
}

class _BankBalanceToggle extends StatelessWidget {
  const _BankBalanceToggle({required this.selected, required this.onTap});

  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.fromLTRB(13, 11, 9, 11),
          decoration: BoxDecoration(
            color: selected ? AppColors.neonBlue.withValues(alpha: 0.08) : AppColors.background.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: selected ? AppColors.neonBlue.withValues(alpha: 0.35) : AppColors.border),
          ),
          child: Row(
            children: [
              PaymentIconBadge(
                icon: Icons.account_balance_wallet_rounded,
                size: 36,
                radius: 11,
                color: selected ? AppColors.neonBlue : AppColors.textMuted,
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Update bank balance',
                      style: TextStyle(color: AppColors.textPrimary, fontSize: 12.5, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Add this payment to your tracked balance.',
                      style: TextStyle(color: AppColors.textMuted.withValues(alpha: 0.9), fontSize: 10.5, height: 1.4),
                    ),
                  ],
                ),
              ),
              Switch(
                value: selected,
                onChanged: (_) => onTap(),
                thumbColor: const WidgetStatePropertyAll<Color>(Colors.black),
                trackColor: WidgetStateProperty.resolveWith<Color>(
                  (states) => states.contains(WidgetState.selected) ? AppColors.neonBlue : AppColors.border,
                ),
                trackOutlineColor: const WidgetStatePropertyAll<Color>(Colors.transparent),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: AppColors.expense.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.expense.withValues(alpha: 0.32)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: AppColors.expense, size: 17),
          const SizedBox(width: 9),
          Expanded(
            child: Text(message, style: const TextStyle(color: AppColors.expense, fontSize: 11.5, height: 1.4)),
          ),
        ],
      ),
    );
  }
}
