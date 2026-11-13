import 'package:material_ui/material_ui.dart';
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
import 'package:_50cents/features/payments/presentation/widgets/payment_ui.dart';

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
    final record = recordState.asData?.value;

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
                'Payment details',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                ),
              ),
              SizedBox(height: 1),
              Text(
                'Everything about this payment',
                style: TextStyle(color: AppColors.textMuted, fontSize: 11.5, fontWeight: FontWeight.w500),
              ),
            ],
          ),
          actions: [
            if (record != null)
              PaymentAppBarAction(
                icon: Icons.edit_rounded,
                tooltip: 'Update payment',
                onPressed: () => _handleUpdate(record),
              ),
            const SizedBox(width: 16),
          ],
        ),
        body: SafeArea(
          child: RefreshIndicator(
            color: AppColors.neonBlue,
            backgroundColor: AppColors.surface,
            onRefresh: () async {
              ref.invalidate(paymentRecordProvider(widget.recordId));
              try {
                await ref.read(paymentRecordProvider(widget.recordId).future);
              } catch (_) {
                // Errors surface through the provider's error state below.
              }
            },
            child: recordState.when(
              loading: () => const Center(child: CircularProgressIndicator(color: AppColors.neonBlue, strokeWidth: 2)),
              error: (error, _) => ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 60, 20, 28),
                children: [
                  _ErrorPanel(
                    message: apiErrorMessage(error),
                    onRetry: () => ref.invalidate(paymentRecordProvider(widget.recordId)),
                  ),
                ],
              ),
              data: (record) => _DetailsBody(record: record),
            ),
          ),
        ),
        bottomNavigationBar: record == null
            ? null
            : _ActionBar(record: record, onDelete: _handleDelete, onUpdate: () => _handleUpdate(record)),
      ),
    );
  }

  Future<void> _handleDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        icon: const PaymentIconBadge(
          icon: Icons.delete_outline_rounded,
          size: 52,
          radius: 16,
          color: AppColors.expense,
        ),
        title: const Text(
          'Delete this payment?',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.textPrimary, fontSize: 17, fontWeight: FontWeight.w700),
        ),
        content: const Text(
          'The record will be removed from your history permanently. Your bank balance will not be changed.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.textMuted, fontSize: 12.5, height: 1.5),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textPrimary,
                    side: const BorderSide(color: AppColors.border),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  child: const Text('Keep it'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.expense,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                  child: const Text('Delete'),
                ),
              ),
            ],
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
          content: Row(
            children: [
              const Icon(Icons.error_outline_rounded, color: AppColors.expense, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(apiErrorMessage(error), style: const TextStyle(color: AppColors.textPrimary, fontSize: 13)),
              ),
            ],
          ),
        ),
      );
    }
  }

  void _handleUpdate(PaymentRecord record) {
    showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _UpdateSheet(record: record),
    ).then((saved) {
      if (saved == true && context.mounted) {
        ref.invalidate(paymentRecordProvider(widget.recordId));
      }
    });
  }
}

// ---------------------------------------------------------------------------
// Read view
// ---------------------------------------------------------------------------

class _DetailsBody extends StatelessWidget {
  const _DetailsBody({required this.record});

  final PaymentRecord record;

  @override
  Widget build(BuildContext context) {
    final note = record.note?.trim();

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
      children: [
        _DetailHero(record: record),
        const SizedBox(height: 16),
        _InfoCard(
          title: 'Payee',
          icon: Icons.person_search_rounded,
          rows: [
            _DetailRow(label: 'Name', value: record.payeeLabel),
            if (record.recipientIdentifier != null && record.recipientIdentifier!.trim().isNotEmpty)
              _DetailRow(
                label: 'Identifier',
                value: record.recipientIdentifier!.trim(),
                copyValue: record.recipientIdentifier!.trim(),
                copyLabel: 'Identifier',
              ),
            _DetailRow(label: 'Channel', value: record.paymentMedium, icon: paymentMediumIcon(record.paymentMedium)),
          ],
        ),
        const SizedBox(height: 14),
        _InfoCard(
          title: 'Transaction',
          icon: Icons.receipt_long_rounded,
          rows: [
            _DetailRow(
              label: 'Type',
              value: record.isCredit ? 'Credit' : 'Debit',
              valueColor: record.isCredit ? AppColors.income : AppColors.textPrimary,
            ),
            _DetailRow(label: 'Date', value: formatDateShort(record.paidAt)),
            _DetailRow(label: 'Time', value: formatTime(record.paidAt)),
            _DetailRow(
              label: 'Category',
              value: record.category.name.trim().isEmpty ? 'Uncategorized' : record.category.name,
              icon: paymentCategoryIcon(code: record.category.code, name: record.category.name),
            ),
            _DetailRow(
              label: 'Bank sync',
              value: record.bankUpdated ? 'Balance updated' : 'Not tracked',
              valueColor: record.bankUpdated ? AppColors.income : AppColors.textMuted,
              icon: record.bankUpdated ? Icons.cloud_done_rounded : Icons.cloud_off_rounded,
              iconColor: record.bankUpdated ? AppColors.income : AppColors.textMuted,
            ),
          ],
        ),
        if (note != null && note.isNotEmpty) ...[const SizedBox(height: 14), _NoteCard(note: note)],
      ],
    );
  }
}

class _DetailHero extends StatelessWidget {
  const _DetailHero({required this.record});

  final PaymentRecord record;

  @override
  Widget build(BuildContext context) {
    final isCredit = record.isCredit;
    final accent = isCredit ? AppColors.income : AppColors.neonBlue;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [accent.withValues(alpha: 0.2), AppColors.surface, Color.lerp(AppColors.surface, accent, 0.05)!],
          stops: const [0.0, 0.5, 1.0],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: accent.withValues(alpha: 0.24)),
        boxShadow: [BoxShadow(color: accent.withValues(alpha: 0.09), blurRadius: 36, spreadRadius: 1)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              PaymentPill(
                label: isCredit ? 'Money received' : 'Money sent',
                icon: isCredit ? Icons.south_west_rounded : Icons.north_east_rounded,
                color: accent,
              ),
              const Spacer(),
              PaymentPill(
                label: record.paymentMedium,
                icon: paymentMediumIcon(record.paymentMedium),
                color: AppColors.textMuted,
              ),
            ],
          ),
          const SizedBox(height: 22),
          Text(
            isCredit ? 'Amount received' : 'Amount paid',
            style: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerLeft,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                formatInr(record.amount, showPaise: record.amount % 1 != 0),
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 38,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1.4,
                  height: 1.05,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.schedule_rounded, color: AppColors.textMuted, size: 13),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  formatDateTime(record.paidAt),
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 11.5, fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Divider(height: 1, color: accent.withValues(alpha: 0.16)),
          const SizedBox(height: 16),
          Row(
            children: [
              PaymentAvatar(label: record.payeeLabel, size: 44),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Received from',
                      style: TextStyle(color: AppColors.textMuted, fontSize: 10.5, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      record.payeeLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: AppColors.textPrimary, fontSize: 14.5, fontWeight: FontWeight.w700),
                    ),
                    if (record.recipientIdentifier != null && record.recipientIdentifier!.trim().isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          record.recipientIdentifier!.trim(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: AppColors.textMuted, fontSize: 11.5),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.title, required this.icon, required this.rows});

  final String title;
  final IconData icon;
  final List<Widget> rows;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.textMuted, size: 16),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...rows,
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
    this.valueColor,
    this.copyValue,
    this.copyLabel,
    this.icon,
    this.iconColor,
  });

  final String label;
  final String value;
  final Color? valueColor;
  final String? copyValue;
  final String? copyLabel;
  final IconData? icon;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final content = Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, color: iconColor ?? AppColors.textMuted, size: 15),
            const SizedBox(width: 8),
          ],
          Text(
            label,
            style: const TextStyle(color: AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.w500),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: valueColor ?? AppColors.textPrimary,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            ),
          ),
          if (copyValue != null) ...[
            const SizedBox(width: 8),
            Icon(Icons.copy_rounded, color: AppColors.textMuted, size: 13),
          ],
        ],
      ),
    );

    if (copyValue == null) return content;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () {
          Clipboard.setData(ClipboardData(text: copyValue!));
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle_rounded, color: AppColors.income, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '${copyLabel ?? 'Value'} copied.',
                      style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
        child: content,
      ),
    );
  }
}

class _NoteCard extends StatelessWidget {
  const _NoteCard({required this.note});

  final String note;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PaymentIconBadge(icon: Icons.sticky_note_2_rounded, size: 34, radius: 10),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Note',
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 4),
                Text(note, style: const TextStyle(color: AppColors.textPrimary, fontSize: 12.5, height: 1.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionBar extends StatelessWidget {
  const _ActionBar({required this.record, required this.onDelete, required this.onUpdate});

  final PaymentRecord record;
  final VoidCallback onDelete;
  final VoidCallback onUpdate;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
          child: Row(
            children: [
              Expanded(
                child: NeonButton(label: 'Update payment', icon: Icons.edit_rounded, onPressed: onUpdate, height: 50),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 54,
                height: 50,
                child: OutlinedButton(
                  onPressed: onDelete,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.expense,
                    backgroundColor: AppColors.expense.withValues(alpha: 0.07),
                    side: BorderSide(color: AppColors.expense.withValues(alpha: 0.4)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    padding: EdgeInsets.zero,
                  ),
                  child: const Icon(Icons.delete_outline_rounded, size: 21),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorPanel extends StatelessWidget {
  const _ErrorPanel({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 30, 24, 28),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          const PaymentIconBadge(icon: Icons.cloud_off_rounded, size: 62, radius: 20, color: AppColors.expense),
          const SizedBox(height: 18),
          const Text(
            'Could not load this payment',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 7),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textMuted, fontSize: 12.5, height: 1.5),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: 168,
            child: NeonButton(label: 'Try again', icon: Icons.refresh_rounded, onPressed: onRetry, height: 46),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Edit sheet
// ---------------------------------------------------------------------------

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
    final record = widget.record;
    _amountController = TextEditingController(text: record.amount.toStringAsFixed(2));
    _noteController = TextEditingController(text: record.note ?? '');
    _recipientNameController = TextEditingController(text: record.recipientName);
    _recipientIdentifierController = TextEditingController(text: record.recipientIdentifier ?? '');
    _paymentMediumController = TextEditingController(text: record.paymentMedium);
    _selectedCategoryCode = record.category.code.isNotEmpty ? record.category.code : null;
    final type = record.transactionType.trim().toUpperCase();
    _selectedType = _types.contains(type) ? type : 'DEBIT';
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
            Expanded(
              child: Text('Loading categories...', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
            ),
          ],
        ),
      ),
      error: (error, _) => Container(
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

        return InputDecorator(
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
              hint: const Text('Select a category', style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
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
              onChanged: (value) => setState(() => _selectedCategoryCode = value),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final height = (media.size.height - media.viewInsets.bottom) * 0.92;
    final categories = ref.watch(categoriesProvider);
    final selectedType = _types.contains(_selectedType) ? _selectedType! : 'DEBIT';

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
                  const PaymentIconBadge(icon: Icons.edit_note_rounded, size: 42, radius: 13),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Update payment',
                          style: TextStyle(color: AppColors.textPrimary, fontSize: 17, fontWeight: FontWeight.w700),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Fix a detail without losing the record',
                          style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                        ),
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
                padding: const EdgeInsets.fromLTRB(22, 2, 22, 10),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const PaymentSectionLabel(label: 'Amount'),
                      const SizedBox(height: 10),
                      _InputField(
                        controller: _amountController,
                        label: 'Amount',
                        icon: Icons.currency_rupee_rounded,
                        style: const TextStyle(color: AppColors.textPrimary, fontSize: 22, fontWeight: FontWeight.w700),
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
                      const SizedBox(height: 22),
                      const PaymentSectionLabel(label: 'Payee'),
                      const SizedBox(height: 10),
                      _InputField(
                        controller: _recipientNameController,
                        label: 'Payee name',
                        icon: Icons.person_outline_rounded,
                      ),
                      const SizedBox(height: 12),
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
                      if (_contactNameForIdentifier != null && _contactNameForIdentifier!.trim().isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            PaymentPill(
                              label: 'Contact · ${_contactNameForIdentifier!.trim()}',
                              icon: Icons.person_rounded,
                              fontSize: 10,
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 12),
                      _InputField(
                        controller: _paymentMediumController,
                        label: 'Payment medium',
                        icon: Icons.payment_rounded,
                      ),
                      const SizedBox(height: 22),
                      const PaymentSectionLabel(label: 'Classification'),
                      const SizedBox(height: 10),
                      PaymentSegmentedControl<String>(
                        selected: selectedType,
                        onChanged: (value) => setState(() => _selectedType = value),
                        options: const <PaymentSegmentOption<String>>[
                          PaymentSegmentOption<String>(value: 'DEBIT', label: 'Debit', icon: Icons.north_east_rounded),
                          PaymentSegmentOption<String>(
                            value: 'CREDIT',
                            label: 'Credit',
                            icon: Icons.south_west_rounded,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _buildCategoryDropdown(categories),
                      const SizedBox(height: 22),
                      const PaymentSectionLabel(label: 'Note'),
                      const SizedBox(height: 10),
                      _InputField(
                        controller: _noteController,
                        label: 'Note (optional)',
                        icon: Icons.notes_rounded,
                        maxLines: 2,
                      ),
                      const SizedBox(height: 14),
                      _BankSyncInfo(updated: widget.record.bankUpdated),
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
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_submitMessage != null) ...[
                      _InlineMessage(message: _submitMessage!, isError: _submitError),
                      const SizedBox(height: 10),
                    ],
                    NeonButton(
                      label: 'Save changes',
                      icon: Icons.check_rounded,
                      loading: _submitting,
                      onPressed: _submitting ? null : _save,
                      height: 52,
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
}

class _BankSyncInfo extends StatelessWidget {
  const _BankSyncInfo({required this.updated});

  final bool updated;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: AppColors.background.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          PaymentIconBadge(
            icon: updated ? Icons.cloud_done_rounded : Icons.cloud_off_rounded,
            size: 36,
            radius: 11,
            color: updated ? AppColors.income : AppColors.textMuted,
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Bank balance',
                  style: TextStyle(color: AppColors.textPrimary, fontSize: 12.5, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  updated
                      ? 'This payment is included in your tracked balance.'
                      : 'This payment is not linked to your bank balance.',
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 10.5, height: 1.4),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          PaymentPill(label: 'Locked', icon: Icons.lock_outline_rounded, color: AppColors.textMuted, fontSize: 9.5),
        ],
      ),
    );
  }
}

class _InlineMessage extends StatelessWidget {
  const _InlineMessage({required this.message, required this.isError});

  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final color = isError ? AppColors.expense : AppColors.income;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.32)),
      ),
      child: Row(
        children: [
          Icon(isError ? Icons.error_outline_rounded : Icons.check_circle_rounded, color: color, size: 17),
          const SizedBox(width: 9),
          Expanded(
            child: Text(message, style: TextStyle(color: color, fontSize: 12, height: 1.4)),
          ),
        ],
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
    this.style,
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
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      maxLines: maxLines,
      style: style ?? const TextStyle(color: AppColors.textPrimary),
      decoration: appInputDecoration(label, icon).copyWith(suffixIcon: suffixIcon, counterText: ''),
      validator: validator,
      onChanged: onChanged,
    );
  }
}
