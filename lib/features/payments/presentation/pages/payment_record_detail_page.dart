import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:_50cents/core/theme/app_colors.dart';
import 'package:_50cents/core/theme/app_inputs.dart';
import 'package:_50cents/core/widgets/neon_background.dart';
import 'package:_50cents/core/widgets/neon_button.dart';
import 'package:_50cents/features/payments/data/models/payment_record.dart';
import 'package:_50cents/features/payments/data/models/update_payment_record_request.dart';
import 'package:_50cents/features/payments/data/payment_repository.dart';

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
  late final TextEditingController _transactionTypeController;
  late final TextEditingController _categoryController;

  bool _submitting = false;
  bool _updateBankBalance = false;

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
    _transactionTypeController = TextEditingController(text: r.transactionType);
    _categoryController = TextEditingController(text: r.category.name);
    _updateBankBalance = r.bankUpdated;
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    _recipientNameController.dispose();
    _recipientIdentifierController.dispose();
    _paymentMediumController.dispose();
    _transactionTypeController.dispose();
    _categoryController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();

    setState(() => _submitting = true);

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
              transactionType: _transactionTypeController.text.trim().isNotEmpty
                  ? _transactionTypeController.text.trim()
                  : null,
              recipientName: _recipientNameController.text.trim().isNotEmpty
                  ? _recipientNameController.text.trim()
                  : null,
              recipientIdentifier: _recipientIdentifierController.text.trim().isNotEmpty
                  ? _recipientIdentifierController.text.trim()
                  : null,
              note: _noteController.text.trim().isNotEmpty ? _noteController.text.trim() : null,
              category: _categoryController.text.trim().isNotEmpty ? _categoryController.text.trim() : null,
              updateBankBalance: _updateBankBalance,
            ),
          );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(apiErrorMessage(error), style: const TextStyle(color: AppColors.textPrimary)),
          backgroundColor: AppColors.expense,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
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
                  const Text(
                    'Update payment',
                    style: TextStyle(color: AppColors.textPrimary, fontSize: 17, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Edit the fields you want to change and save.',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 12, height: 1.35),
                  ),
                  const SizedBox(height: 22),
                  _InputField(
                    controller: _amountController,
                    label: 'Amount',
                    icon: Icons.currency_rupee_rounded,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9\.]'))],
                    validator: (value) {
                      final text = value?.trim().replaceAll(',', '') ?? '';
                      if (text.isEmpty) return 'Please enter an amount';
                      final amount = double.tryParse(text);
                      if (amount == null || amount <= 0) return 'Enter a valid amount';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  _InputField(
                    controller: _recipientNameController,
                    label: 'Payee name',
                    icon: Icons.person_outline_rounded,
                  ),
                  const SizedBox(height: 16),
                  _InputField(
                    controller: _recipientIdentifierController,
                    label: 'Identifier (UPI ID / phone)',
                    icon: Icons.alternate_email_rounded,
                  ),
                  const SizedBox(height: 16),
                  _InputField(
                    controller: _paymentMediumController,
                    label: 'Payment medium',
                    icon: Icons.payment_rounded,
                  ),
                  const SizedBox(height: 16),
                  _InputField(
                    controller: _transactionTypeController,
                    label: 'Type',
                    icon: Icons.swap_horiz_rounded,
                    validator: (value) {
                      final text = value?.trim().toUpperCase() ?? '';
                      if (text.isEmpty) return 'Please enter a type';
                      if (!_types.contains(text)) return 'Use DEBIT or CREDIT';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  _InputField(controller: _categoryController, label: 'Category', icon: Icons.category_outlined),
                  const SizedBox(height: 16),
                  _InputField(controller: _noteController, label: 'Note', icon: Icons.notes_rounded, maxLines: 2),
                  const SizedBox(height: 16),
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
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final String? Function(String?)? validator;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      maxLines: maxLines,
      style: const TextStyle(color: AppColors.textPrimary),
      decoration: appInputDecoration(label, icon),
      validator: validator,
    );
  }
}
