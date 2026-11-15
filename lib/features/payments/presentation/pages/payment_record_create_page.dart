import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:_50cents/core/theme/app_colors.dart';
import 'package:_50cents/core/theme/app_inputs.dart';
import 'package:_50cents/core/widgets/neon_background.dart';
import 'package:_50cents/core/widgets/neon_button.dart';
import 'package:_50cents/features/payments/data/contact_lookup.dart';
import 'package:_50cents/features/payments/data/models/create_payment_record_request.dart';
import 'package:_50cents/features/payments/data/models/payment_category.dart';
import 'package:_50cents/features/payments/data/payment_repository.dart';
import 'package:_50cents/features/payments/presentation/widgets/contact_picker_sheet.dart';
import 'package:_50cents/features/payments/presentation/widgets/payment_ui.dart';

/// One manually chosen payment medium.
class _MediumOption {
  const _MediumOption({required this.value, required this.icon});

  final String value;
  final IconData icon;
}

const String _otherMedium = 'Other';

const List<_MediumOption> _mediumOptions = <_MediumOption>[
  _MediumOption(value: 'Cash', icon: Icons.payments_rounded),
  _MediumOption(value: 'UPI', icon: Icons.bolt_rounded),
  _MediumOption(value: 'Card', icon: Icons.credit_card_rounded),
  _MediumOption(value: 'Bank transfer', icon: Icons.account_balance_rounded),
  _MediumOption(value: 'Wallet', icon: Icons.account_balance_wallet_rounded),
  _MediumOption(value: _otherMedium, icon: Icons.more_horiz_rounded),
];

/// Creates a payment record for something that happened outside the app.
///
/// Unlike the pay sheet (which needs the backend to stamp "now"), this screen
/// requires the user to choose the exact date and time of the payment.
class PaymentRecordCreatePage extends ConsumerStatefulWidget {
  const PaymentRecordCreatePage({super.key});

  @override
  ConsumerState<PaymentRecordCreatePage> createState() => _PaymentRecordCreatePageState();
}

class _PaymentRecordCreatePageState extends ConsumerState<PaymentRecordCreatePage> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _recipientNameController = TextEditingController();
  final _identifierController = TextEditingController();
  final _noteController = TextEditingController();
  final _otherMediumController = TextEditingController();

  String _transactionType = 'DEBIT';
  String? _selectedMedium;
  String? _selectedCategoryCode;
  DateTime? _paidDate;
  TimeOfDay? _paidTime;

  bool _updateBankBalance = false;
  bool _submitting = false;
  String? _submitError;
  String? _paidAtError;
  String? _mediumError;

  Timer? _predictDebounce;
  int _predictRequest = 0;
  bool _predicting = false;
  bool _categoryManuallyChanged = false;
  String? _autoSuggestedName;

  Timer? _contactDebounce;
  int _contactRequest = 0;
  bool _lookingUpContact = false;

  /// Contact name auto-filled into the name field. Tracks what we prefilled so
  /// a later lookup only replaces or clears it while the user has not typed
  /// their own text.
  String? _autoFilledContactName;

  /// Contact name detected for the entered phone number / phone-based UPI ID.
  /// Shown in the chip and kept stable when the user edits the name field — it
  /// only follows the identifier.
  String? _detectedContactName;

  bool get _isCredit => _transactionType == 'CREDIT';

  double? get _enteredAmount {
    final text = _amountController.text.trim().replaceAll(',', '');
    final value = double.tryParse(text);
    return value == null || value <= 0 ? null : value;
  }

  DateTime? get _paidAt {
    final date = _paidDate;
    final time = _paidTime;
    if (date == null || time == null) return null;
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  /// The medium string sent to the API. "Other" is optional: when the user
  /// does not type a custom medium we still send `Other`.
  String? get _resolvedMedium {
    final medium = _selectedMedium;
    if (medium == null) return null;
    if (medium != _otherMedium) return medium;

    final custom = _otherMediumController.text.trim();
    return custom.isEmpty ? _otherMedium : custom;
  }

  /// The phone number to look up in the contact book, if the entered
  /// identifier is a phone number or a phone-based UPI ID such as
  /// `9876543210@ybl`.
  String? get _contactPhone {
    final raw = _identifierController.text.trim();
    if (raw.isEmpty) return null;

    if (raw.contains('@')) {
      final localPart = raw.split('@').first;
      final digits = localPart.replaceAll(RegExp(r'[^0-9]'), '');
      if (digits.length == 10 && digits == localPart) return digits;
      return null;
    }

    final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length >= 10 && digits.length <= 13) return digits;
    return null;
  }

  /// Recipient string sent to the category-prediction API: the typed name,
  /// else the detected contact name, else the raw identifier.
  String get _predictionRecipient {
    final typedName = _recipientNameController.text.trim();
    if (typedName.isNotEmpty) return typedName;

    final detected = _detectedContactName;
    if (detected != null && detected.isNotEmpty) return detected;

    return _identifierController.text.trim();
  }

  @override
  void dispose() {
    _predictDebounce?.cancel();
    _contactDebounce?.cancel();
    _amountController.dispose();
    _recipientNameController.dispose();
    _identifierController.dispose();
    _noteController.dispose();
    _otherMediumController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final current = _paidDate == null ? today : DateTime(_paidDate!.year, _paidDate!.month, _paidDate!.day);

    final picked = await showDatePicker(
      context: context,
      initialDate: current.isAfter(today) ? today : current,
      firstDate: DateTime(2000),
      lastDate: today,
      helpText: 'When did this payment happen?',
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(datePickerTheme: _datePickerTheme()),
        child: child!,
      ),
    );
    if (picked == null || !mounted) return;

    setState(() {
      _paidDate = picked;
      _paidAtError = null;
      _submitError = null;
    });
    _validatePaidAt(showWhenMissing: false);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _paidTime ?? TimeOfDay.now(),
      helpText: 'What time did it happen?',
      // Force a 12-hour clock with AM/PM on every device. The app is locked to
      // `en_GB` (for `dd/mm/yyyy` dates), whose raw time format is 24-hour, so
      // `alwaysUse24HourFormat: false` is not enough: the picker falls back to
      // the `en_GB` format. Overriding just this dialog to `en_US` gives the
      // `h:mm a` format (e.g. `4:30 PM`) and an AM/PM selector.
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: false),
        child: Localizations.override(
          context: context,
          locale: const Locale('en', 'US'),
          child: Theme(
            data: Theme.of(context).copyWith(timePickerTheme: _timePickerTheme()),
            child: child!,
          ),
        ),
      ),
    );
    if (picked == null || !mounted) return;

    setState(() {
      _paidTime = picked;
      _paidAtError = null;
      _submitError = null;
    });
    _validatePaidAt(showWhenMissing: false);
  }

  void _useNow() {
    final now = DateTime.now();
    setState(() {
      _paidDate = DateTime(now.year, now.month, now.day);
      _paidTime = TimeOfDay(hour: now.hour, minute: now.minute);
      _paidAtError = null;
      _submitError = null;
    });
  }

  void _useYesterday() {
    final now = DateTime.now();
    final yesterday = now.subtract(const Duration(days: 1));
    setState(() {
      _paidDate = DateTime(yesterday.year, yesterday.month, yesterday.day);
      _paidTime = TimeOfDay(hour: now.hour, minute: now.minute);
      _paidAtError = null;
      _submitError = null;
    });
  }

  /// Keeps the "paid at" hint in sync. The missing-date error is only shown
  /// after a save attempt, so the blank form does not start out red.
  void _validatePaidAt({required bool showWhenMissing}) {
    final paidAt = _paidAt;
    final String? error;

    if (paidAt == null) {
      error = showWhenMissing ? 'Choose the date and time this payment happened.' : null;
    } else if (paidAt.isAfter(DateTime.now())) {
      error = "The payment time can't be in the future.";
    } else {
      error = null;
    }

    if (error == _paidAtError) return;
    setState(() => _paidAtError = error);
  }

  Future<void> _pickContact() async {
    final number = await showContactPicker(context);
    if (!mounted || number == null) return;

    setState(() {
      _identifierController.text = number;
      _submitError = null;
    });
    _scheduleContactLookup();
    _schedulePrediction();
  }

  /// Looks up the saved contact name after the identifier stops changing.
  void _scheduleContactLookup() {
    _contactDebounce?.cancel();
    final requestId = ++_contactRequest;
    final phone = _contactPhone;

    if (phone == null) {
      final autoName = _autoFilledContactName;
      final shouldClearField = autoName != null && _recipientNameController.text.trim() == autoName;
      final hadDetected = _detectedContactName != null;
      if (mounted && (_lookingUpContact || shouldClearField || hadDetected)) {
        setState(() {
          _lookingUpContact = false;
          _detectedContactName = null;
          if (shouldClearField) {
            _recipientNameController.clear();
            _autoFilledContactName = null;
          }
        });
        if (shouldClearField || hadDetected) _schedulePrediction();
      }
      return;
    }

    _contactDebounce = Timer(const Duration(milliseconds: 350), () => _lookupContactName(phone, requestId));
  }

  Future<void> _lookupContactName(String phone, int requestId) async {
    if (mounted) setState(() => _lookingUpContact = true);

    final found = await ContactNameLookup.nameForPhone(phone);
    if (!mounted || requestId != _contactRequest) return;

    final trimmed = found?.trim();
    final name = (trimmed == null || trimmed.isEmpty) ? null : trimmed;
    final current = _recipientNameController.text.trim();
    var nameChanged = false;

    setState(() {
      _lookingUpContact = false;
      // The detected name shown in the chip follows the entered identifier
      // only; user edits to the name field never touch it.
      _detectedContactName = name;

      if (name == null) {
        if (current.isNotEmpty && current == _autoFilledContactName) {
          _recipientNameController.clear();
          _autoFilledContactName = null;
          nameChanged = true;
        }
        return;
      }

      if (current.isEmpty || current == _autoFilledContactName) {
        _recipientNameController.text = name;
        _autoFilledContactName = name;
        nameChanged = true;
      }
    });

    if (nameChanged) _schedulePrediction();
  }

  /// Rebuilds the category prediction after a short pause so we don't call the
  /// API on every keystroke.
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
          .predictCategory(recipient: recipient, transactionType: _transactionType, note: note.isEmpty ? null : note);
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
      // Category prediction is a convenience; the payment can still be saved.
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

  Future<void> _submit() async {
    if (_submitting) return;
    FocusScope.of(context).unfocus();

    final formValid = _formKey.currentState?.validate() ?? false;
    _validatePaidAt(showWhenMissing: true);

    final medium = _resolvedMedium;
    // Only flag the case where no medium was picked at all. A blank "Other"
    // field is fine and falls back to "Other".
    final mediumError = _selectedMedium == null ? 'Choose how this payment was made.' : null;
    if (mediumError != _mediumError) {
      setState(() => _mediumError = mediumError);
    }

    final paidAt = _paidAt;
    final amount = _enteredAmount;
    if (!formValid ||
        _paidAtError != null ||
        mediumError != null ||
        paidAt == null ||
        amount == null ||
        medium == null) {
      return;
    }

    setState(() {
      _submitting = true;
      _submitError = null;
    });

    final recipientName = _recipientNameController.text.trim();
    final identifier = _identifierController.text.trim();
    final note = _noteController.text.trim();

    try {
      await ref
          .read(paymentRepositoryProvider)
          .createPaymentRecord(
            CreatePaymentRecordRequest(
              amount: amount,
              recipientName: recipientName.isEmpty ? null : recipientName,
              recipientIdentifier: identifier.isEmpty ? null : identifier,
              note: note.isEmpty ? null : note,
              paymentMedium: medium,
              transactionType: _transactionType,
              category: _selectedCategoryCode,
              updateBankBalance: _updateBankBalance,
              paidAt: paidAt,
            ),
          );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _submitError = apiErrorMessage(error);
      });
      return;
    }

    if (!mounted) return;

    // The entry point now lives on the home page, so refresh every history
    // and summary query for the next time those screens are opened.
    ref.invalidate(paymentRecordsProvider);
    ref.invalidate(paymentSummaryProvider);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: AppColors.income, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Payment recorded for ${formatDateTime(paidAt)}.',
                style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
    context.pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final amount = _enteredAmount;

    return NeonBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          leadingWidth: 64,
          leading: Padding(
            padding: const EdgeInsets.only(left: 16),
            child: PaymentAppBarAction(icon: Icons.arrow_back_rounded, tooltip: 'Back', onPressed: () => context.pop()),
          ),
          titleSpacing: 12,
          title: const Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Record a payment',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                ),
              ),
              SizedBox(height: 1),
              Text(
                'Log an off-app payment',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: AppColors.textMuted, fontSize: 11.5, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: Form(
                key: _formKey,
                child: ListView(
                  keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                  children: [
                    _IntroCard(isCredit: _isCredit),
                    const SizedBox(height: 22),
                    const PaymentSectionLabel(label: 'Direction'),
                    const SizedBox(height: 10),
                    PaymentSegmentedControl<String>(
                      selected: _transactionType,
                      onChanged: (value) {
                        setState(() {
                          _transactionType = value;
                          _submitError = null;
                        });
                        _schedulePrediction();
                      },
                      options: const <PaymentSegmentOption<String>>[
                        PaymentSegmentOption<String>(
                          value: 'DEBIT',
                          label: 'Money sent',
                          icon: Icons.north_east_rounded,
                        ),
                        PaymentSegmentOption<String>(
                          value: 'CREDIT',
                          label: 'Money received',
                          icon: Icons.south_west_rounded,
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),
                    const PaymentSectionLabel(label: 'Amount'),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _amountController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}'))],
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.8,
                      ),
                      decoration: appInputDecoration('Amount', Icons.currency_rupee_rounded, hint: '0.00').copyWith(
                        // Match the 26px input text so the placeholder does not
                        // look like a tiny label next to a big number.
                        hintStyle: TextStyle(
                          color: AppColors.textMuted.withValues(alpha: 0.45),
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                      onChanged: (_) {
                        setState(() {
                          if (_submitError != null) _submitError = null;
                        });
                      },
                      validator: (value) {
                        final text = value?.trim().replaceAll(',', '') ?? '';
                        if (text.isEmpty) return 'Please enter an amount';
                        final parsed = double.tryParse(text);
                        if (parsed == null || parsed <= 0) return 'Enter a valid amount';
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
                    const SizedBox(height: 22),
                    PaymentSectionLabel(
                      label: 'Paid at',
                      trailing: const PaymentPill(label: 'Required', icon: Icons.priority_high_rounded, fontSize: 9.5),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          flex: 1,
                          child: _DateTimeField(
                            label: 'Date',
                            value: _paidDate == null ? 'Select date' : formatDateDmy(_paidDate!),
                            icon: Icons.calendar_today_rounded,
                            hasValue: _paidDate != null,
                            hasError: _paidAtError != null,
                            onTap: _pickDate,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 1,
                          child: _DateTimeField(
                            label: 'Time',
                            value: _paidTime == null ? 'Select time' : _timeLabel(_paidTime!),
                            icon: Icons.schedule_rounded,
                            hasValue: _paidTime != null,
                            hasError: _paidAtError != null,
                            onTap: _pickTime,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _QuickDateTimeChip(label: 'Now', icon: Icons.bolt_rounded, onTap: _useNow),
                        _QuickDateTimeChip(label: 'Yesterday', icon: Icons.history_rounded, onTap: _useYesterday),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _HintLine(
                      message: _paidAtError ?? 'Required — the record keeps the exact date and time you choose.',
                      isError: _paidAtError != null,
                    ),
                    const SizedBox(height: 22),
                    const PaymentSectionLabel(label: 'Paid with'),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final option in _mediumOptions)
                          _MediumChip(
                            option: option,
                            selected: _selectedMedium == option.value,
                            onTap: () {
                              setState(() {
                                _selectedMedium = option.value;
                                _mediumError = null;
                                _submitError = null;
                              });
                            },
                          ),
                      ],
                    ),
                    if (_selectedMedium == _otherMedium) ...[
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _otherMediumController,
                        textCapitalization: TextCapitalization.words,
                        style: const TextStyle(color: AppColors.textPrimary),
                        decoration: appInputDecoration(
                          'How was it paid? (optional)',
                          Icons.edit_rounded,
                          hint: 'Cheque, PhonePe, Paytm… defaults to Other',
                        ),
                        onChanged: (_) {
                          setState(() {
                            _mediumError = null;
                            _submitError = null;
                          });
                        },
                      ),
                    ],
                    if (_mediumError != null) ...[
                      const SizedBox(height: 9),
                      _HintLine(message: _mediumError!, isError: true),
                    ],
                    const SizedBox(height: 22),
                    PaymentSectionLabel(
                      label: _isCredit ? 'Received from' : 'Paid to',
                      trailing: const Text(
                        'Name required',
                        style: TextStyle(color: AppColors.textMuted, fontSize: 10, fontWeight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _identifierController,
                      textInputAction: TextInputAction.next,
                      style: const TextStyle(color: AppColors.textPrimary),
                      decoration: appInputDecoration(
                        'UPI ID, phone or account',
                        Icons.alternate_email_rounded,
                        hint: 'name@bank or 9876543210',
                        suffixIcon: IconButton(
                          tooltip: 'Choose from contacts',
                          onPressed: _pickContact,
                          icon: const Icon(Icons.contacts_rounded, color: AppColors.neonBlue, size: 20),
                        ),
                      ),
                      onChanged: (_) {
                        _clearSubmitError();
                        _scheduleContactLookup();
                        _schedulePrediction();
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _recipientNameController,
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.next,
                      maxLength: 255,
                      style: const TextStyle(color: AppColors.textPrimary),
                      decoration: appInputDecoration(
                        _isCredit ? 'Payer name' : 'Payee name',
                        Icons.person_outline_rounded,
                        hint: _isCredit ? 'Who sent the money?' : 'Who did you pay?',
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
                      ).copyWith(counterText: ''),
                      onChanged: (_) {
                        // Typing a name means the user took over from the
                        // contact auto-fill; keep their text from now on.
                        _autoFilledContactName = null;
                        _clearSubmitError();
                        _schedulePrediction();
                      },
                      validator: (value) {
                        if ((value?.trim() ?? '').isEmpty) {
                          return _isCredit ? 'Please enter who sent the money' : 'Please enter who you paid';
                        }
                        return null;
                      },
                    ),
                    if (_detectedContactName != null) ...[
                      const SizedBox(height: 8),
                      _DetectedContactChip(name: _detectedContactName!),
                    ],
                    const SizedBox(height: 22),
                    PaymentSectionLabel(
                      label: 'Organise',
                      trailing: const Text(
                        'Optional',
                        style: TextStyle(color: AppColors.textMuted, fontSize: 10, fontWeight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(height: 10),
                    _buildCategoryField(ref.watch(categoriesProvider)),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _noteController,
                      minLines: 1,
                      maxLines: 3,
                      maxLength: 2048,
                      textCapitalization: TextCapitalization.sentences,
                      style: const TextStyle(color: AppColors.textPrimary),
                      decoration: appInputDecoration(
                        'Note (optional)',
                        Icons.notes_rounded,
                        hint: 'What was this payment for?',
                      ).copyWith(counterText: ''),
                      onChanged: (_) {
                        _clearSubmitError();
                        _schedulePrediction();
                      },
                    ),
                    const SizedBox(height: 12),
                    _BankBalanceCard(
                      selected: _updateBankBalance,
                      onTap: () => setState(() => _updateBankBalance = !_updateBankBalance),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
          ),
        ),
        bottomNavigationBar: Container(
          decoration: const BoxDecoration(
            color: AppColors.surface,
            border: Border(top: BorderSide(color: AppColors.border)),
          ),
          child: SafeArea(
            top: false,
            child: Center(
              // Wrap the bar around its content. A plain Center would expand
              // to the full screen height inside Scaffold's bottom slot and
              // hide the form behind it.
              heightFactor: 1,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_submitError != null) ...[_ErrorBanner(message: _submitError!), const SizedBox(height: 10)],
                      NeonButton(
                        label: amount == null ? 'Save payment' : 'Save ${formatInr(amount)}',
                        icon: Icons.check_rounded,
                        loading: _submitting,
                        onPressed: _submitting ? null : _submit,
                        height: 52,
                      ),
                      const SizedBox(height: 9),
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.offline_bolt_rounded, size: 12, color: AppColors.textMuted),
                          SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              'Saved to your payment history straight away.',
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
            ),
          ),
        ),
      ),
    );
  }

  void _setQuickAmount(int amount) {
    setState(() {
      _amountController.text = amount.toString();
      _amountController.selection = TextSelection.collapsed(offset: _amountController.text.length);
      _submitError = null;
    });
  }

  void _clearSubmitError() {
    if (_submitError != null) setState(() => _submitError = null);
  }

  Widget _buildCategoryField(AsyncValue<List<PaymentCategory>> categories) {
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
                  value: _selectedCategoryCode ?? '',
                  isExpanded: true,
                  isDense: true,
                  dropdownColor: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.textMuted),
                  style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
                  items: [
                    const DropdownMenuItem<String>(
                      value: '',
                      child: Text('No category', style: TextStyle(color: AppColors.textMuted)),
                    ),
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
                      _selectedCategoryCode = value == null || value.isEmpty ? null : value;
                      _categoryManuallyChanged = true;
                      _autoSuggestedName = null;
                      _submitError = null;
                    });
                  },
                ),
              ),
            ),
            if (_autoSuggestedName != null || _predicting) ...[
              const SizedBox(height: 9),
              _HintLine(
                message: _predicting
                    ? 'Predicting the best category…'
                    : 'Auto-suggested from ${_isCredit ? 'the payer' : 'the payee'}. Tap the field to change it.',
                isError: false,
                icon: _predicting ? Icons.sync_rounded : Icons.auto_awesome_rounded,
              ),
            ],
          ],
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Page pieces
// ---------------------------------------------------------------------------

class _IntroCard extends StatelessWidget {
  const _IntroCard({required this.isCredit});

  final bool isCredit;

  @override
  Widget build(BuildContext context) {
    final accent = isCredit ? AppColors.income : AppColors.neonBlue;

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [accent.withValues(alpha: 0.18), AppColors.surface, Color.lerp(AppColors.surface, accent, 0.04)!],
          stops: const [0.0, 0.58, 1.0],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: accent.withValues(alpha: 0.22)),
        boxShadow: [BoxShadow(color: accent.withValues(alpha: 0.06), blurRadius: 30, spreadRadius: 1)],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -30,
            bottom: -36,
            child: Icon(Icons.edit_note_rounded, size: 150, color: accent.withValues(alpha: 0.08)),
          ),
          Positioned(
            right: 46,
            top: -44,
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(shape: BoxShape.circle, color: accent.withValues(alpha: 0.07)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const PaymentPill(label: 'Manual entry', icon: Icons.edit_note_rounded),
                    const Spacer(),
                    PaymentPill(
                      label: isCredit ? 'Money in' : 'Money out',
                      icon: isCredit ? Icons.south_west_rounded : Icons.north_east_rounded,
                      color: isCredit ? AppColors.income : AppColors.neonBlue,
                      fontSize: 9.5,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  isCredit ? 'Log money you received' : 'Log money you sent',
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 7),
                const Text(
                  'Add a payment that happened outside 50cents. You choose the date, the time and how it was paid.',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 12.5, height: 1.5),
                ),
              ],
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

class _DateTimeField extends StatelessWidget {
  const _DateTimeField({
    required this.label,
    required this.value,
    required this.icon,
    required this.hasValue,
    required this.hasError,
    required this.onTap,
  });

  final String label;
  final String value;
  final IconData icon;
  final bool hasValue;
  final bool hasError;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = hasError ? AppColors.expense : AppColors.neonBlue;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          height: 64,
          padding: const EdgeInsets.symmetric(horizontal: 11),
          decoration: BoxDecoration(
            color: hasError ? AppColors.expense.withValues(alpha: 0.06) : AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: hasError ? AppColors.expense.withValues(alpha: 0.55) : AppColors.border),
          ),
          child: Row(
            children: [
              PaymentIconBadge(
                icon: icon,
                size: 34,
                radius: 10,
                color: hasValue || hasError ? accent : AppColors.textMuted,
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label.toUpperCase(),
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 8.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: hasValue ? AppColors.textPrimary : AppColors.textMuted,
                        fontSize: 12,
                        fontWeight: hasValue ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.textMuted, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickDateTimeChip extends StatelessWidget {
  const _QuickDateTimeChip({required this.label, required this.icon, required this.onTap});

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.neonBlue.withValues(alpha: 0.07),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.neonBlue.withValues(alpha: 0.24)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: AppColors.neonBlueBright, size: 13),
              const SizedBox(width: 5),
              Text(
                label,
                style: const TextStyle(color: AppColors.neonBlueBright, fontSize: 10.5, fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MediumChip extends StatelessWidget {
  const _MediumChip({required this.option, required this.selected, required this.onTap});

  final _MediumOption option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          decoration: BoxDecoration(
            gradient: selected
                ? LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.neonBlue.withValues(alpha: 0.24),
                      AppColors.neonBlueDeep.withValues(alpha: 0.12),
                    ],
                  )
                : null,
            color: selected ? null : AppColors.background.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: selected ? AppColors.neonBlue.withValues(alpha: 0.55) : AppColors.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(option.icon, size: 15, color: selected ? AppColors.neonBlueBright : AppColors.textMuted),
              const SizedBox(width: 7),
              Text(
                option.value,
                style: TextStyle(
                  color: selected ? AppColors.neonBlueBright : AppColors.textPrimary,
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                ),
              ),
              // Reserve the icon's width even when it is hidden so selecting a
              // chip never shifts the layout.
              const SizedBox(width: 6),
              SizedBox(
                width: 14,
                height: 14,
                child: selected ? const Icon(Icons.check_circle_rounded, color: AppColors.neonBlue, size: 14) : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HintLine extends StatelessWidget {
  const _HintLine({required this.message, required this.isError, this.icon});

  final String message;
  final bool isError;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon ?? (isError ? Icons.error_outline_rounded : Icons.info_outline_rounded),
          color: isError ? AppColors.expense : AppColors.textMuted,
          size: 13,
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            message,
            style: TextStyle(color: isError ? AppColors.expense : AppColors.textMuted, fontSize: 10.5, height: 1.4),
          ),
        ),
      ],
    );
  }
}

class _DetectedContactChip extends StatelessWidget {
  const _DetectedContactChip({required this.name});

  final String name;

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
          const Icon(Icons.contacts_rounded, color: AppColors.neonBlueBright, size: 14),
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

class _BankBalanceCard extends StatelessWidget {
  const _BankBalanceCard({required this.selected, required this.onTap});

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
                      'Include this payment in your tracked balance.',
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

String _timeLabel(TimeOfDay time) {
  final hour = time.hour % 12 == 0 ? 12 : time.hour % 12;
  final minute = time.minute.toString().padLeft(2, '0');
  final period = time.hour < 12 ? 'AM' : 'PM';
  return '$hour:$minute $period';
}

/// Dark, neon-accented date picker.
///
/// Today's cell and the selected year use the `today*` / `year*` properties
/// rather than `day*`: without them the current year inherits the primary
/// colour as both text and background, making it unreadable.
DatePickerThemeData _datePickerTheme() {
  return DatePickerThemeData(
    backgroundColor: AppColors.surface,
    surfaceTintColor: Colors.transparent,
    shadowColor: Colors.black,
    elevation: 0,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    headerBackgroundColor: AppColors.background,
    headerForegroundColor: AppColors.textPrimary,
    headerHeadlineStyle: const TextStyle(color: AppColors.textPrimary, fontSize: 23, fontWeight: FontWeight.w700),
    headerHelpStyle: const TextStyle(color: AppColors.textMuted, fontSize: 12),
    weekdayStyle: const TextStyle(color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.w700),
    dayStyle: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
    dayForegroundColor: WidgetStateProperty.resolveWith<Color>((states) {
      // Days outside the allowed range (future dates) are disabled: fade
      // them right down so they read as untappable.
      if (states.contains(WidgetState.disabled)) {
        return AppColors.textMuted.withValues(alpha: 0.28);
      }
      return states.contains(WidgetState.selected) ? Colors.black : AppColors.textPrimary;
    }),
    dayBackgroundColor: WidgetStateProperty.resolveWith<Color>(
      (states) => states.contains(WidgetState.selected) ? AppColors.neonBlue : Colors.transparent,
    ),
    dayOverlayColor: WidgetStateProperty.resolveWith<Color>(
      (states) =>
          states.contains(WidgetState.hovered) && !states.contains(WidgetState.disabled) ||
              states.contains(WidgetState.pressed)
          ? AppColors.neonBlue.withValues(alpha: 0.12)
          : Colors.transparent,
    ),
    dayShape: WidgetStatePropertyAll<OutlinedBorder>(RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
    todayForegroundColor: WidgetStateProperty.resolveWith<Color>(
      (states) => states.contains(WidgetState.selected) ? Colors.black : AppColors.neonBlue,
    ),
    todayBackgroundColor: WidgetStateProperty.resolveWith<Color>(
      (states) => states.contains(WidgetState.selected) ? AppColors.neonBlue : Colors.transparent,
    ),
    todayBorder: BorderSide(color: AppColors.neonBlue.withValues(alpha: 0.7)),
    yearStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
    yearForegroundColor: WidgetStateProperty.resolveWith<Color>((states) {
      if (states.contains(WidgetState.disabled)) {
        return AppColors.textMuted.withValues(alpha: 0.28);
      }
      return states.contains(WidgetState.selected) ? Colors.black : AppColors.textPrimary;
    }),
    yearBackgroundColor: WidgetStateProperty.resolveWith<Color>(
      (states) => states.contains(WidgetState.selected) ? AppColors.neonBlue : Colors.transparent,
    ),
    yearOverlayColor: WidgetStateProperty.resolveWith<Color>(
      (states) =>
          states.contains(WidgetState.hovered) && !states.contains(WidgetState.disabled) ||
              states.contains(WidgetState.pressed)
          ? AppColors.neonBlue.withValues(alpha: 0.12)
          : Colors.transparent,
    ),
    yearShape: WidgetStatePropertyAll<OutlinedBorder>(RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
    dividerColor: AppColors.border,
    subHeaderForegroundColor: AppColors.textMuted,
    toggleButtonTextStyle: const TextStyle(color: AppColors.neonBlue, fontSize: 12, fontWeight: FontWeight.w700),
    cancelButtonStyle: TextButton.styleFrom(foregroundColor: AppColors.textMuted),
    confirmButtonStyle: TextButton.styleFrom(
      foregroundColor: AppColors.neonBlue,
      textStyle: const TextStyle(fontWeight: FontWeight.w700),
    ),
    inputDecorationTheme: InputDecorationThemeData(
      filled: true,
      fillColor: AppColors.background,
      labelStyle: const TextStyle(color: AppColors.textMuted),
      floatingLabelStyle: const TextStyle(color: AppColors.neonBlue),
      helperStyle: const TextStyle(color: AppColors.textMuted),
      errorStyle: const TextStyle(color: AppColors.expense),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.neonBlue, width: 1.4),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.expense),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.expense, width: 1.4),
      ),
    ),
  );
}

/// Dark, neon-accented time picker.
///
/// Several colours accept a [WidgetStateColor]; using plain colours here made
/// the selected AM/PM label black on a near-black surface (invisible).
TimePickerThemeData _timePickerTheme() {
  return TimePickerThemeData(
    backgroundColor: AppColors.surface,
    elevation: 0,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    helpTextStyle: const TextStyle(color: AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.w600),
    hourMinuteColor: WidgetStateColor.resolveWith(
      (states) =>
          states.contains(WidgetState.selected) ? AppColors.neonBlue.withValues(alpha: 0.18) : AppColors.background,
    ),
    hourMinuteTextColor: WidgetStateColor.resolveWith(
      (states) => states.contains(WidgetState.selected) ? AppColors.neonBlueBright : AppColors.textPrimary,
    ),
    hourMinuteShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    dayPeriodColor: WidgetStateColor.resolveWith(
      (states) => states.contains(WidgetState.selected) ? AppColors.neonBlue : Colors.transparent,
    ),
    dayPeriodTextColor: WidgetStateColor.resolveWith(
      (states) => states.contains(WidgetState.selected) ? Colors.black : AppColors.textMuted,
    ),
    dayPeriodShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    dayPeriodBorderSide: BorderSide(color: AppColors.neonBlue.withValues(alpha: 0.3)),
    dialBackgroundColor: AppColors.background,
    dialHandColor: AppColors.neonBlue,
    dialTextColor: WidgetStateColor.resolveWith(
      (states) => states.contains(WidgetState.selected) ? Colors.black : AppColors.textPrimary,
    ),
    timeSelectorSeparatorColor: const WidgetStatePropertyAll<Color>(AppColors.textMuted),
    entryModeIconColor: AppColors.textMuted,
    cancelButtonStyle: TextButton.styleFrom(foregroundColor: AppColors.textMuted),
    confirmButtonStyle: TextButton.styleFrom(
      foregroundColor: AppColors.neonBlue,
      textStyle: const TextStyle(fontWeight: FontWeight.w700),
    ),
    inputDecorationTheme: InputDecorationThemeData(
      filled: true,
      fillColor: AppColors.background,
      labelStyle: const TextStyle(color: AppColors.textMuted),
      floatingLabelStyle: const TextStyle(color: AppColors.neonBlue),
      helperStyle: const TextStyle(color: AppColors.textMuted),
      errorStyle: const TextStyle(color: AppColors.expense),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.neonBlue, width: 1.4),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.expense),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.expense, width: 1.4),
      ),
    ),
  );
}
