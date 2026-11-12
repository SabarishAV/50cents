import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:_50cents/core/theme/app_colors.dart';
import 'package:_50cents/core/theme/app_inputs.dart';
import 'package:_50cents/core/widgets/neon_background.dart';
import 'package:_50cents/core/widgets/neon_button.dart';
import 'package:_50cents/features/payments/data/contact_lookup.dart';
import 'package:_50cents/features/payments/data/models/payment_category.dart';
import 'package:_50cents/features/payments/data/models/payment_record.dart';
import 'package:_50cents/features/payments/data/models/update_payment_record_request.dart';
import 'package:_50cents/features/payments/data/payment_repository.dart';
import 'package:_50cents/features/payments/presentation/widgets/contact_picker_sheet.dart';

/// Elaborated details for a single payment record (`GET /payment-records/:id`).
///
/// Provides delete (`DELETE`) and update (`PATCH`) actions on the same path.
class PaymentRecordDetailPage extends ConsumerStatefulWidget {
  const PaymentRecordDetailPage({super.key, required this.recordId});

  final String recordId;

  @override
  ConsumerState<PaymentRecordDetailPage> createState() => _PaymentRecordDetailPageState();
}

class _PaymentRecordDetailPageState extends ConsumerState<PaymentRecordDetailPage> {
  @override
  Widget build(BuildContext context) {
    final recordState = ref.watch(paymentRecordProvider(widget.recordId));

    return NeonBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary, size: 24),
            onPressed: () => context.pop(),
          ),
          title: const Text(
            'Payment details',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 19,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
            ),
          ),
        ),
        body: SafeArea(
          child: RefreshIndicator(
            color: AppColors.neonBlue,
            backgroundColor: AppColors.surface,
            onRefresh: () async {
              ref.invalidate(paymentRecordProvider(widget.recordId));
              await ref.read(paymentRecordProvider(widget.recordId).future);
            },
            child: recordState.when(
              loading: () => const Center(child: CircularProgressIndicator(color: AppColors.neonBlue, strokeWidth: 2)),
              error: (error, _) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline_rounded, color: AppColors.expense, size: 40),
                    const SizedBox(height: 12),
                    Text(
                      'Could not load payment',
                      style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      apiErrorMessage(error),
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.textMuted, fontSize: 12.5),
                    ),
                    const SizedBox(height: 18),
                    NeonButton(
                      label: 'Retry',
                      icon: Icons.refresh_rounded,
                      onPressed: () async {
                        ref.invalidate(paymentRecordProvider(widget.recordId));
                        await ref.read(paymentRecordProvider(widget.recordId).future);
                      },
                      height: 46,
                    ),
                  ],
                ),
              ),
              data: (record) => _DetailsBody(record: record, onDelete: _handleDelete, onUpdate: _handleUpdate),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Delete payment?', style: TextStyle(color: AppColors.textPrimary)),
        content: const Text(
          'This payment record will be removed permanently.',
          style: TextStyle(color: AppColors.textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete', style: TextStyle(color: AppColors.expense)),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    try {
      await ref.read(paymentRepositoryProvider).deletePaymentRecord(widget.recordId);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(apiErrorMessage(error), style: const TextStyle(color: AppColors.textPrimary)),
          backgroundColor: AppColors.expense,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _handleUpdate(PaymentRecord record) {
    showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _UpdateSheet(record: record),
    ).then((saved) {
      if (saved == true && context.mounted) {
        ref.invalidate(paymentRecordProvider(widget.recordId));
      }
    });
  }
}

class _DetailsBody extends StatelessWidget {
  const _DetailsBody({required this.record, required this.onDelete, required this.onUpdate});

  final PaymentRecord record;
  final VoidCallback onDelete;
  final void Function(PaymentRecord) onUpdate;

  @override
  Widget build(BuildContext context) {
    final isCredit = record.isCredit;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      children: [
        _DetailSection(
          title: 'Payee',
          children: [
            _DetailRow(label: 'Name', value: record.payeeLabel),
            if (record.recipientIdentifier != null && record.recipientIdentifier!.trim().isNotEmpty)
              _DetailRow(label: 'Identifier', value: record.recipientIdentifier!.trim()),
          ],
        ),
        const SizedBox(height: 16),
        _DetailSection(
          title: 'Amount',
          children: [
            _DetailRow(
              label: isCredit ? 'Received' : 'Spent',
              value: _formatAmount(record.amount),
              valueColor: isCredit ? AppColors.income : AppColors.expense,
            ),
          ],
        ),
        const SizedBox(height: 16),
        _DetailSection(
          title: 'Details',
          children: [
            _DetailRow(label: 'Medium', value: record.paymentMedium),
            _DetailRow(label: 'Type', value: isCredit ? 'Credit' : 'Debit'),
            _DetailRow(label: 'Date', value: _formatDate(record.paidAt)),
            if (record.category.code.isNotEmpty) _DetailRow(label: 'Category', value: record.category.name),
            if (record.note != null && record.note!.trim().isNotEmpty)
              _DetailRow(label: 'Note', value: record.note!.trim()),
            _DetailRow(
              label: 'Bank updated',
              value: record.bankUpdated ? 'Yes' : 'No',
              valueColor: record.bankUpdated ? AppColors.income : AppColors.textMuted,
            ),
          ],
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: NeonButton(
                label: 'Update',
                icon: Icons.edit_rounded,
                loading: false,
                onPressed: () => onUpdate(record),
                height: 46,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton(
                onPressed: onDelete,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.expense,
                  side: BorderSide(color: AppColors.expense.withValues(alpha: 0.5)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text(
                  'Delete',
                  style: TextStyle(color: AppColors.expense, fontSize: 15, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  String _formatAmount(double amount) {
    final text = amount % 1 == 0 ? amount.toInt().toString() : amount.toStringAsFixed(2);
    return '₹$text';
  }

  String _formatDate(DateTime date) {
    const months = <String>['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final local = date.toLocal();
    final minute = local.minute.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final monthName = months[local.month - 1];
    return '$monthName ${local.day}, ${local.year} at $hour:$minute';
  }
}

class _DetailSection extends StatelessWidget {
  const _DetailSection({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: AppColors.textMuted,
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 8),
        ...children,
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value, this.valueColor});

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 92,
            child: Text(
              label,
              style: const TextStyle(color: AppColors.textMuted, fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(color: valueColor ?? AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

/// Edit sheet for updating a payment record (`PATCH /payment-records/:id`).
class _UpdateSheet extends ConsumerStatefulWidget {
  const _UpdateSheet({required this.record});

  final PaymentRecord record;

  @override
  ConsumerState<_UpdateSheet> createState() => _UpdateSheetState();
}

class _UpdateSheetState extends ConsumerState<_UpdateSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _amountController;
  late final TextEditingController _noteController;
  late final TextEditingController _recipientNameController;
  late final TextEditingController _recipientIdentifierController;
  late final TextEditingController _paymentMediumController;

  bool _submitting = false;
  String? _submitMessage;
  bool _submitError = false;
  String? _selectedCategoryCode;
  String? _selectedType;
  String? _contactNameForIdentifier;

  static const List<String> _types = <String>['DEBIT', 'CREDIT'];

  @override
  void initState() {
    super.initState();
    final r = widget.record;
    _amountController = TextEditingController(text: r.amount.toStringAsFixed(2));
    _noteController = TextEditingController(text: r.note ?? '');
    _recipientNameController = TextEditingController(text: r.recipientName);
    _recipientIdentifierController = TextEditingController(text: r.recipientIdentifier ?? '');
    _paymentMediumController = TextEditingController(text: r.paymentMedium);
    _selectedCategoryCode = r.category.code.isNotEmpty ? r.category.code : null;
    _selectedType = r.transactionType.trim().toUpperCase();
    _lookupIdentifierContactName();
  }

  Future<void> _lookupIdentifierContactName() async {
    final identifier = _recipientIdentifierController.text.trim();
    if (identifier.isEmpty) return;
    final name = await ContactNameLookup.nameForPhone(identifier);
    if (!mounted) return;
    setState(() => _contactNameForIdentifier = name);
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    _recipientNameController.dispose();
    _recipientIdentifierController.dispose();
    _paymentMediumController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();

    setState(() {
      _submitting = true;
      _submitMessage = null;
      _submitError = false;
    });

    try {
      await ref
          .read(paymentRepositoryProvider)
          .updatePaymentRecord(
            widget.record.id,
            UpdatePaymentRecordRequest(
              amount: double.tryParse(_amountController.text.trim().replaceAll(',', '')),
              paymentMedium: _paymentMediumController.text.trim().isNotEmpty
                  ? _paymentMediumController.text.trim()
                  : null,
              transactionType: _selectedType,
              recipientName: _recipientNameController.text.trim().isNotEmpty
                  ? _recipientNameController.text.trim()
                  : null,
              recipientIdentifier: _recipientIdentifierController.text.trim().isNotEmpty
                  ? _recipientIdentifierController.text.trim()
                  : null,
              note: _noteController.text.trim().isNotEmpty ? _noteController.text.trim() : null,
              category: _selectedCategoryCode != null && _selectedCategoryCode!.isNotEmpty
                  ? _selectedCategoryCode
                  : null,
              updateBankBalance: widget.record.bankUpdated,
            ),
          );
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _submitMessage = 'Payment updated.';
        _submitError = false;
      });
      Future.delayed(const Duration(milliseconds: 600), () {
        if (mounted) Navigator.of(context).pop(true);
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _submitMessage = apiErrorMessage(error);
        _submitError = true;
      });
    }
  }

  Widget _buildCategoryDropdown(AsyncValue<List<PaymentCategory>> categories) {
    return categories.when(
      loading: () => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
            Expanded(
              child: Text('Loading categories...', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
            ),
          ],
        ),
      ),
      error: (error, _) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
              child: Text('Could not load categories.', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
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
        PaymentCategory? selected;
        for (final category in list) {
          if (category.code == _selectedCategoryCode) {
            selected = category;
            break;
          }
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InputDecorator(
              decoration: appInputDecoration(
                'Category',
                Icons.category_outlined,
              ).copyWith(contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5)),
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
                  onChanged: (value) => setState(() => _selectedCategoryCode = value),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildTypeDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InputDecorator(
          decoration: appInputDecoration(
            'Type',
            Icons.swap_horiz_rounded,
          ).copyWith(contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5)),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedType,
              isExpanded: true,
              isDense: true,
              dropdownColor: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.textMuted),
              hint: const Text('Select type', style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
              items: [
                for (final type in _types)
                  DropdownMenuItem<String>(
                    value: type,
                    child: Text(type == 'DEBIT' ? 'Debit' : 'Credit', maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
              ],
              onChanged: (value) => setState(() => _selectedType = value),
            ),
          ),
        ),
      ],
    );
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
                  const Text(
                    'Update payment',
                    style: TextStyle(color: AppColors.textPrimary, fontSize: 17, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Edit the fields you want to change and save.',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 12, height: 1.35),
                  ),
                  const SizedBox(height: 18),
                  _InputField(
                    controller: _amountController,
                    label: 'Amount',
                    icon: Icons.currency_rupee_rounded,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}$'))],
                    validator: (value) {
                      final text = value?.trim().replaceAll(',', '') ?? '';
                      if (text.isEmpty) return 'Please enter an amount';
                      final amount = double.tryParse(text);
                      if (amount == null || amount <= 0) return 'Enter a valid amount';
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  _InputField(
                    controller: _recipientNameController,
                    label: 'Payee name',
                    icon: Icons.person_outline_rounded,
                  ),
                  const SizedBox(height: 14),
                  if (_contactNameForIdentifier != null && _contactNameForIdentifier!.trim().isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.neonBlue.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.neonBlue.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.person_outline_rounded, color: AppColors.neonBlue, size: 12),
                          const SizedBox(width: 6),
                          Text(
                            'Contact: $_contactNameForIdentifier',
                            style: const TextStyle(
                              color: AppColors.neonBlueBright,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 8),
                  _InputField(
                    controller: _recipientIdentifierController,
                    label: 'Identifier (UPI ID / phone)',
                    icon: Icons.alternate_email_rounded,
                    suffixIcon: IconButton(
                      tooltip: 'Choose from contacts',
                      onPressed: () async {
                        final number = await showContactPicker(context);
                        if (!mounted || number == null) return;
                        _recipientIdentifierController.text = number;
                        _lookupIdentifierContactName();
                      },
                      icon: const Icon(Icons.contacts_rounded, color: AppColors.neonBlue, size: 20),
                    ),
                    onChanged: (_) => _lookupIdentifierContactName(),
                  ),
                  const SizedBox(height: 14),
                  _InputField(
                    controller: _paymentMediumController,
                    label: 'Payment medium',
                    icon: Icons.payment_rounded,
                  ),
                  const SizedBox(height: 14),
                  _buildTypeDropdown(),
                  const SizedBox(height: 14),
                  _buildCategoryDropdown(categories),
                  const SizedBox(height: 14),
                  _InputField(controller: _noteController, label: 'Note', icon: Icons.notes_rounded, maxLines: 1),
                  const SizedBox(height: 14),
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.background.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: CheckboxListTile(
                      value: widget.record.bankUpdated,
                      onChanged: null,
                      dense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 6),
                      controlAffinity: ListTileControlAffinity.leading,
                      activeColor: AppColors.income,
                      checkColor: Colors.black,
                      title: const Text(
                        'Update bank balance',
                        style: TextStyle(color: AppColors.textMuted, fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                      subtitle: const Text(
                        'Cannot be changed from here.',
                        style: TextStyle(color: AppColors.textMuted, fontSize: 11.5, height: 1.35),
                      ),
                    ),
                  ),
                  if (_submitMessage != null) ...[
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _submitError
                            ? AppColors.expense.withValues(alpha: 0.1)
                            : AppColors.income.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: (_submitError ? AppColors.expense : AppColors.income).withValues(alpha: 0.35),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _submitError ? Icons.error_outline_rounded : Icons.check_circle_rounded,
                            color: _submitError ? AppColors.expense : AppColors.income,
                            size: 17,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _submitMessage!,
                              style: TextStyle(
                                color: _submitError ? AppColors.expense : AppColors.income,
                                fontSize: 12,
                                height: 1.35,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  NeonButton(
                    label: 'Save changes',
                    icon: Icons.save_rounded,
                    loading: _submitting,
                    onPressed: _submitting ? null : _save,
                  ),
                  const SizedBox(height: 14),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _InputField extends StatelessWidget {
  const _InputField({
    required this.controller,
    required this.label,
    required this.icon,
    this.keyboardType,
    this.inputFormatters,
    this.validator,
    this.maxLines = 1,
    this.suffixIcon,
    this.onChanged,
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final String? Function(String?)? validator;
  final int maxLines;
  final Widget? suffixIcon;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      maxLines: maxLines,
      style: const TextStyle(color: AppColors.textPrimary),
      decoration: appInputDecoration(label, icon).copyWith(suffixIcon: suffixIcon),
      validator: validator,
      onChanged: onChanged,
    );
  }
}
