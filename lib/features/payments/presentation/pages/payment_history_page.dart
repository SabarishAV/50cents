import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:_50cents/core/theme/app_colors.dart';
import 'package:_50cents/core/theme/app_inputs.dart';
import 'package:_50cents/core/widgets/neon_background.dart';
import 'package:_50cents/core/widgets/neon_button.dart';
import 'package:_50cents/features/payments/data/models/payment_record.dart';
import 'package:_50cents/features/payments/data/payment_repository.dart';

const List<String> _transactionTypes = <String>['ALL', 'DEBIT', 'CREDIT'];

enum _FilterMode { thisMonth, last3Months, last6Months }

/// Payment history screen backed by `GET /payment-records`.
class PaymentHistoryPage extends ConsumerStatefulWidget {
  const PaymentHistoryPage({super.key});

  @override
  ConsumerState<PaymentHistoryPage> createState() => _PaymentHistoryPageState();
}

class _PaymentHistoryPageState extends ConsumerState<PaymentHistoryPage> {
  static const int _pageSize = 15;

  int _fromYear = DateTime.now().year;
  int _fromMonth = DateTime.now().month;
  int _toYear = DateTime.now().year;
  int _toMonth = DateTime.now().month;
  _FilterMode _filterMode = _FilterMode.thisMonth;
  String _transactionType = 'ALL';
  int _pageNumber = 1;

  PaymentRecordsQuery get _query => PaymentRecordsQuery(
    year: _fromYear,
    month: _fromMonth,
    toYear: _toYear,
    toMonth: _toMonth,
    onlyThisMonth: _filterMode == _FilterMode.thisMonth,
    transactionType: _transactionType == 'ALL' ? null : _transactionType,
    pageNumber: _pageNumber,
    pageSize: _pageSize,
  );

  @override
  Widget build(BuildContext context) {
    final recordsState = ref.watch(paymentRecordsProvider(_query));

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
            'Payment History',
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
              ref.invalidate(paymentRecordsProvider(_query));
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
              children: [
                _FilterBar(
                  transactionType: _transactionType,
                  filterMode: _filterMode,
                  fromYear: _fromYear,
                  fromMonth: _fromMonth,
                  toYear: _toYear,
                  toMonth: _toMonth,
                  onTransactionTypeChanged: _setTransactionType,
                  onFilterModeChanged: _setFilterMode,
                  onMonthChanged: _handleMonthChange,
                ),
                const SizedBox(height: 18),
                recordsState.when(
                  loading: () => const _RecordsState(
                    icon: Icons.receipt_long_rounded,
                    title: 'Loading payments',
                    message: 'Fetching your payment history.',
                  ),
                  error: (error, _) => _RecordsState(
                    icon: Icons.wifi_off_rounded,
                    title: 'Could not load payments',
                    message: apiErrorMessage(error),
                    actionLabel: 'Retry',
                    onAction: () => ref.invalidate(paymentRecordsProvider(_query)),
                  ),
                  data: (page) => page.data.isEmpty
                      ? const _EmptyPaymentsState()
                      : _RecordsList(
                          page: page,
                          onLoadMore: _loadMore,
                          onRecordChanged: () => ref.invalidate(paymentRecordsProvider(_query)),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _setTransactionType(String type) {
    setState(() {
      _transactionType = type;
      _pageNumber = 1;
    });
  }

  void _setFilterMode(_FilterMode mode) {
    setState(() {
      _filterMode = mode;
      _pageNumber = 1;
      final now = DateTime.now();
      switch (mode) {
        case _FilterMode.thisMonth:
          _fromYear = now.year;
          _fromMonth = now.month;
          _toYear = now.year;
          _toMonth = now.month;
        case _FilterMode.last3Months:
          _toYear = now.year;
          _toMonth = now.month;
          var from = now.month - 2;
          var fromYear = now.year;
          while (from <= 0) {
            from += 12;
            fromYear -= 1;
          }
          _fromYear = fromYear;
          _fromMonth = from;
        case _FilterMode.last6Months:
          _toYear = now.year;
          _toMonth = now.month;
          var from = now.month - 5;
          var fromYear = now.year;
          while (from <= 0) {
            from += 12;
            fromYear -= 1;
          }
          _fromYear = fromYear;
          _fromMonth = from;
      }
    });
  }

  void _handleMonthChange(int key, bool isTo) {
    setState(() {
      final decoded = key - 1;
      final year = decoded ~/ 12;
      final month = decoded % 12 + 1;
      if (isTo) {
        _toYear = year;
        _toMonth = month;
      } else {
        _fromYear = year;
        _fromMonth = month;
      }
      _pageNumber = 1;
    });
  }

  void _loadMore() {
    setState(() => _pageNumber += 1);
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.transactionType,
    required this.filterMode,
    required this.fromYear,
    required this.fromMonth,
    required this.toYear,
    required this.toMonth,
    required this.onTransactionTypeChanged,
    required this.onFilterModeChanged,
    required this.onMonthChanged,
  });

  final String transactionType;
  final _FilterMode filterMode;
  final int fromYear;
  final int fromMonth;
  final int toYear;
  final int toMonth;

  final ValueChanged<String> onTransactionTypeChanged;
  final ValueChanged<_FilterMode> onFilterModeChanged;
  final void Function(int, bool) onMonthChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Type',
            style: TextStyle(color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.5),
          ),
          const SizedBox(height: 10),
          Column(
            children: [
              for (final type in _transactionTypes)
                _TypeRow(
                  label: type == 'ALL'
                      ? 'All'
                      : type == 'DEBIT'
                      ? 'Debits'
                      : 'Credits',
                  selected: transactionType.trim().toUpperCase() == type,
                  onTap: () => onTransactionTypeChanged(type),
                ),
            ],
          ),
          const SizedBox(height: 18),
          const Text(
            'Period',
            style: TextStyle(color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.5),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              _FilterRadio(
                label: 'This month',
                value: _FilterMode.thisMonth,
                groupValue: filterMode,
                onChanged: onFilterModeChanged,
              ),
              _FilterRadio(
                label: 'Last 3 months',
                value: _FilterMode.last3Months,
                groupValue: filterMode,
                onChanged: onFilterModeChanged,
              ),
              _FilterRadio(
                label: 'Last 6 months',
                value: _FilterMode.last6Months,
                groupValue: filterMode,
                onChanged: onFilterModeChanged,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _MonthPickerField(
                  label: 'From',
                  year: fromYear,
                  month: fromMonth,
                  onChanged: (key) => onMonthChanged(key, false),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MonthPickerField(
                  label: 'To',
                  year: toYear,
                  month: toMonth,
                  onChanged: (key) => onMonthChanged(key, true),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TypeRow extends StatelessWidget {
  const _TypeRow({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 16),
          decoration: BoxDecoration(
            color: selected ? AppColors.neonBlue.withValues(alpha: 0.12) : null,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: selected ? AppColors.neonBlue.withValues(alpha: 0.55) : AppColors.border),
          ),
          child: Row(
            children: [
              Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected ? AppColors.neonBlue : Colors.transparent,
                  border: Border.all(color: selected ? AppColors.neonBlue : AppColors.textMuted, width: 2),
                ),
                child: selected
                    ? const Center(
                        child: SizedBox(
                          width: 8,
                          height: 8,
                          child: DecoratedBox(
                            decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                          ),
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: selected ? AppColors.neonBlueBright : AppColors.textPrimary,
                    fontSize: 13,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FilterRadio extends StatelessWidget {
  const _FilterRadio({required this.label, required this.value, required this.groupValue, required this.onChanged});

  final String label;
  final _FilterMode value;
  final _FilterMode groupValue;
  final ValueChanged<_FilterMode> onChanged;

  bool get _selected => value == groupValue;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => onChanged(value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: _selected ? AppColors.neonBlue.withValues(alpha: 0.12) : AppColors.background.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _selected ? AppColors.neonBlue.withValues(alpha: 0.6) : AppColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _selected ? AppColors.neonBlue : Colors.transparent,
                border: Border.all(color: _selected ? AppColors.neonBlue : AppColors.textMuted, width: 2),
              ),
              child: _selected
                  ? const Center(
                      child: SizedBox(
                        width: 8,
                        height: 8,
                        child: DecoratedBox(
                          decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                        ),
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: _selected ? AppColors.neonBlueBright : AppColors.textPrimary,
                fontSize: 13,
                fontWeight: _selected ? FontWeight.w700 : FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MonthPickerField extends StatelessWidget {
  const _MonthPickerField({required this.label, required this.year, required this.month, required this.onChanged});

  final String label;
  final int year;
  final int month;
  final ValueChanged<int> onChanged;

  static const List<String> _monthNames = <String>[
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textMuted,
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.4,
          ),
        ),
        const SizedBox(height: 6),
        InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _showMonthPicker(context),
          child: InputDecorator(
            decoration: appInputDecoration('', Icons.calendar_month_rounded),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    '${_monthNames[month - 1]} $year',
                    style: const TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.textMuted, size: 18),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _showMonthPicker(BuildContext context) {
    showDialog<int>(
      context: context,
      builder: (dialogContext) => _MonthPickerDialog(
        year: year,
        month: month,
        onChanged: (key) {
          Navigator.of(dialogContext).pop(key);
          onChanged(key);
        },
      ),
    );
  }
}

class _MonthPickerDialog extends StatefulWidget {
  const _MonthPickerDialog({required this.year, required this.month, required this.onChanged});

  final int year;
  final int month;
  final ValueChanged<int> onChanged;

  @override
  State<_MonthPickerDialog> createState() => _MonthPickerDialogState();
}

class _MonthPickerDialogState extends State<_MonthPickerDialog> {
  late int _year;
  late int _month;

  static const List<String> _monthNames = <String>[
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  @override
  void initState() {
    super.initState();
    _year = widget.year;
    _month = widget.month;
  }

  int get _value => _year * 12 + _month;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surface,
      titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Select month',
            style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w700),
          ),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left_rounded, color: AppColors.neonBlue, size: 24),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () => setState(() => _year -= 1),
              ),
              Text(
                '$_year',
                style: const TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w700),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right_rounded, color: AppColors.neonBlue, size: 24),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () => setState(() => _year += 1),
              ),
            ],
          ),
        ],
      ),
      content: SizedBox(
        width: 320,
        child: GridView.count(
          shrinkWrap: true,
          crossAxisCount: 4,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1.2,
          children: [
            for (final m in List<int>.generate(12, (i) => i + 1))
              _MonthChip(name: _monthNames[m - 1], selected: m == _month, onTap: () => setState(() => _month = m)),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel', style: TextStyle(color: AppColors.textMuted)),
        ),
        TextButton(
          onPressed: () => widget.onChanged(_value),
          child: const Text(
            'OK',
            style: TextStyle(color: AppColors.neonBlue, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}

class _MonthChip extends StatelessWidget {
  const _MonthChip({required this.name, required this.selected, required this.onTap});

  final String name;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.neonBlue : AppColors.background.withValues(alpha: 0.5),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: selected ? AppColors.neonBlue : AppColors.border),
          ),
          child: Text(
            name,
            style: TextStyle(
              color: selected ? Colors.black : AppColors.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class _RecordsList extends StatelessWidget {
  const _RecordsList({required this.page, required this.onLoadMore, this.onRecordChanged});

  final PaymentRecordsPage page;
  final VoidCallback onLoadMore;
  final VoidCallback? onRecordChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final record in page.data)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _PaymentRecordTile(record: record, onRecordChanged: onRecordChanged),
          ),
        if (page.hasNext) _LoadMore(onPressed: onLoadMore),
      ],
    );
  }
}

class _PaymentRecordTile extends StatelessWidget {
  const _PaymentRecordTile({required this.record, this.onRecordChanged});

  final PaymentRecord record;
  final VoidCallback? onRecordChanged;

  @override
  Widget build(BuildContext context) {
    final isCredit = record.isCredit;

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () async {
        final deleted = await context.push<bool>('/payment-records/${record.id}');
        if (deleted == true && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Payment deleted.', style: TextStyle(color: AppColors.textPrimary)),
              backgroundColor: AppColors.income,
              behavior: SnackBarBehavior.floating,
            ),
          );
          onRecordChanged?.call();
        }
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _PaymentRecordIcon(paymentMedium: record.paymentMedium),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        record.payeeLabel,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (record.recipientIdentifier != null && record.recipientIdentifier!.trim().isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          record.recipientIdentifier!.trim(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: AppColors.textMuted, fontSize: 11.5),
                        ),
                      ],
                      if (record.note != null && record.note!.trim().isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          record.note!.trim(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  _formatAmount(record.amount),
                  style: TextStyle(
                    color: isCredit ? AppColors.income : AppColors.expense,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            if (record.category.code.isNotEmpty || record.bankUpdated) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  if (record.category.code.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.neonBlue.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.neonBlue.withValues(alpha: 0.25)),
                      ),
                      child: Text(
                        record.category.name,
                        style: const TextStyle(
                          color: AppColors.neonBlueBright,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                  Text(
                    record.paymentMedium,
                    style: const TextStyle(color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                  Text(
                    _formatDate(record.paidAt),
                    style: const TextStyle(color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                  if (record.bankUpdated)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.income.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.income.withValues(alpha: 0.28)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.cloud_download_rounded, color: AppColors.income, size: 11),
                          const SizedBox(width: 4),
                          const Text(
                            'Bank updated',
                            style: TextStyle(
                              color: AppColors.income,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PaymentRecordIcon extends StatelessWidget {
  const _PaymentRecordIcon({required this.paymentMedium});

  final String paymentMedium;

  IconData get _icon {
    final medium = paymentMedium.trim().toUpperCase();
    if (medium.contains('UPI')) return Icons.currency_rupee_rounded;
    if (medium.contains('CARD')) return Icons.credit_card_rounded;
    if (medium.contains('GOOGLE') || medium.contains('WALLET')) return Icons.wallet_rounded;
    if (medium.contains('AMAZON') || medium.contains('STORE')) return Icons.shopping_bag_rounded;
    if (medium.contains('BANK') || medium.contains('NEFT') || medium.contains('IMPS') || medium.contains('RTGS')) {
      return Icons.account_balance_rounded;
    }
    return Icons.receipt_long_rounded;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: AppColors.neonBlue.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: AppColors.neonBlue.withValues(alpha: 0.24)),
      ),
      child: Icon(_icon, color: AppColors.neonBlue, size: 21),
    );
  }
}

class _RecordsState extends StatelessWidget {
  const _RecordsState({required this.icon, required this.title, this.message, this.actionLabel, this.onAction});

  final IconData icon;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppColors.neonBlue.withValues(alpha: 0.08),
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.neonBlue.withValues(alpha: 0.2)),
            ),
            child: Icon(icon, color: AppColors.neonBlue, size: 28),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w700),
          ),
          if (message != null) ...[
            const SizedBox(height: 6),
            Text(
              message!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textMuted, fontSize: 12.5, height: 1.45),
            ),
          ],
          if (actionLabel != null) ...[
            const SizedBox(height: 18),
            NeonButton(label: actionLabel!, icon: Icons.refresh_rounded, onPressed: onAction, height: 46),
          ],
        ],
      ),
    );
  }
}

class _EmptyPaymentsState extends StatelessWidget {
  const _EmptyPaymentsState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppColors.neonBlue.withValues(alpha: 0.08),
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.neonBlue.withValues(alpha: 0.2)),
            ),
            child: Icon(Icons.receipt_long_rounded, color: AppColors.neonBlue, size: 28),
          ),
          const SizedBox(height: 16),
          const Text(
            'No payments found',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          const Text(
            'Try adjusting your filters.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textMuted, fontSize: 12.5, height: 1.45),
          ),
        ],
      ),
    );
  }
}

class _LoadMore extends StatelessWidget {
  const _LoadMore({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Center(
        child: OutlinedButton.icon(
          onPressed: onPressed,
          icon: const Icon(Icons.arrow_downward_rounded, size: 16, color: AppColors.neonBlue),
          label: const Text(
            'Load more',
            style: TextStyle(color: AppColors.neonBlue, fontSize: 13, fontWeight: FontWeight.w700),
          ),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.neonBlue,
            side: BorderSide(color: AppColors.neonBlue.withValues(alpha: 0.4)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          ),
        ),
      ),
    );
  }
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
