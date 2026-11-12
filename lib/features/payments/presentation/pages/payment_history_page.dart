import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:_50cents/core/theme/app_colors.dart';
import 'package:_50cents/core/widgets/neon_background.dart';
import 'package:_50cents/core/widgets/neon_button.dart';
import 'package:_50cents/features/payments/data/models/payment_record.dart';
import 'package:_50cents/features/payments/data/payment_repository.dart';

const List<String> _transactionTypes = <String>['ALL', 'DEBIT', 'CREDIT'];

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
  bool _onlyThisMonth = true;
  String _transactionType = 'ALL';
  int _pageNumber = 1;

  PaymentRecordsQuery get _query => PaymentRecordsQuery(
    year: _fromYear,
    month: _fromMonth,
    toYear: _toYear,
    toMonth: _toMonth,
    onlyThisMonth: _onlyThisMonth,
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
            'Payment records',
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
                if (recordsState.hasValue) ...[
                  _SummaryCard(records: recordsState.value!.data, transactionType: _transactionType),
                  const SizedBox(height: 16),
                ],
                _FilterBar(
                  transactionType: _transactionType,
                  onlyThisMonth: _onlyThisMonth,
                  fromYear: _fromYear,
                  fromMonth: _fromMonth,
                  toYear: _toYear,
                  toMonth: _toMonth,
                  onTransactionTypeChanged: _setTransactionType,
                  onOnlyThisMonthChanged: _setOnlyThisMonth,
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
                  data: (page) =>
                      page.data.isEmpty ? const _EmptyPaymentsState() : _RecordsList(page: page, onLoadMore: _loadMore),
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

  void _setOnlyThisMonth(bool value) {
    setState(() {
      _onlyThisMonth = value;
      if (value) {
        final now = DateTime.now();
        _fromYear = now.year;
        _fromMonth = now.month;
        _toYear = now.year;
        _toMonth = now.month;
      }
      _pageNumber = 1;
    });
  }

  void _handleMonthChange(int key, bool isTo) {
    setState(() {
      if (isTo) {
        _toYear = key ~/ 12;
        _toMonth = key % 12;
      } else {
        _fromYear = key ~/ 12;
        _fromMonth = key % 12;
      }
      _pageNumber = 1;
    });
  }

  void _loadMore() {
    setState(() => _pageNumber += 1);
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.records, required this.transactionType});

  final List<PaymentRecord> records;
  final String transactionType;

  @override
  Widget build(BuildContext context) {
    final isCreditOnly = transactionType.trim().toUpperCase() == 'CREDIT';
    final spent = records.fold<double>(0, (sum, record) => sum + (record.isCredit ? 0 : record.amount));
    final received = records.fold<double>(0, (sum, record) => sum + (record.isCredit ? record.amount : 0));
    final total = isCreditOnly ? received : spent;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.neonBlue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(13),
              border: Border.all(color: AppColors.neonBlue.withValues(alpha: 0.24)),
            ),
            child: Icon(Icons.currency_rupee_rounded, color: AppColors.neonBlue, size: 21),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isCreditOnly ? 'Total received' : 'Total spent',
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.4,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  _formatAmount(total),
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${records.length} payment${records.length == 1 ? '' : 's'}',
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.transactionType,
    required this.onlyThisMonth,
    required this.fromYear,
    required this.fromMonth,
    required this.toYear,
    required this.toMonth,
    required this.onTransactionTypeChanged,
    required this.onOnlyThisMonthChanged,
    required this.onMonthChanged,
  });

  final String transactionType;
  final bool onlyThisMonth;
  final int fromYear;
  final int fromMonth;
  final int toYear;
  final int toMonth;

  final ValueChanged<String> onTransactionTypeChanged;
  final ValueChanged<bool> onOnlyThisMonthChanged;
  final void Function(int, bool) onMonthChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
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
            children: [
              for (final type in _transactionTypes) ...[
                if (type != _transactionTypes.first) const SizedBox(width: 8),
                Expanded(
                  child: _TypeChip(
                    label: type == 'ALL'
                        ? 'All'
                        : type == 'DEBIT'
                        ? 'Debits'
                        : 'Credits',
                    selected: transactionType.trim().toUpperCase() == type,
                    onTap: () => onTransactionTypeChanged(type),
                  ),
                ),
              ],
            ],
          ),
          if (!onlyThisMonth) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _MonthField(
                    label: 'From',
                    year: fromYear,
                    month: fromMonth,
                    isTo: false,
                    onChanged: onMonthChanged,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _MonthField(label: 'To', year: toYear, month: toMonth, isTo: true, onChanged: onMonthChanged),
                ),
              ],
            ),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'This month',
                  style: TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
              Switch(value: onlyThisMonth, onChanged: onOnlyThisMonthChanged, activeThumbColor: AppColors.neonBlue),
            ],
          ),
        ],
      ),
    );
  }
}

class _TypeChip extends StatelessWidget {
  const _TypeChip({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.neonBlue.withValues(alpha: 0.12) : AppColors.background.withValues(alpha: 0.55),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: selected ? AppColors.neonBlue.withValues(alpha: 0.55) : AppColors.border),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 11),
            alignment: Alignment.center,
            child: Text(
              label,
              style: TextStyle(
                color: selected ? AppColors.neonBlueBright : AppColors.textMuted,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MonthField extends StatelessWidget {
  const _MonthField({
    required this.label,
    required this.year,
    required this.month,
    required this.isTo,
    required this.onChanged,
  });

  final String label;
  final int year;
  final int month;
  final bool isTo;
  final void Function(int, bool) onChanged;

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

  int get _value => year * 12 + month;

  List<DropdownMenuItem<int>> get _items {
    final now = DateTime.now();
    final years = List<int>.generate(8, (index) => now.year - 5 + index);
    return <DropdownMenuItem<int>>[
      for (final yearValue in years)
        for (final monthValue in List<int>.generate(12, (index) => index + 1))
          DropdownMenuItem<int>(
            value: yearValue * 12 + monthValue,
            child: Text('${_monthNames[monthValue - 1]} $yearValue'),
          ),
    ];
  }

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
        DropdownButtonHideUnderline(
          child: DropdownButton<int>(
            value: _value,
            isExpanded: true,
            items: _items,
            onChanged: (key) {
              if (key != null) {
                onChanged(key, isTo);
              }
            },
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w600),
            dropdownColor: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.textMuted, size: 18),
          ),
        ),
      ],
    );
  }
}

class _RecordsList extends StatelessWidget {
  const _RecordsList({required this.page, required this.onLoadMore});

  final PaymentRecordsPage page;
  final VoidCallback onLoadMore;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final record in page.data) _PaymentRecordTile(record: record),
        if (page.hasNext) _LoadMore(onPressed: onLoadMore),
      ],
    );
  }
}

class _PaymentRecordTile extends StatelessWidget {
  const _PaymentRecordTile({required this.record});

  final PaymentRecord record;

  @override
  Widget build(BuildContext context) {
    final isCredit = record.isCredit;

    return Container(
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
                      style: const TextStyle(color: AppColors.textPrimary, fontSize: 14.5, fontWeight: FontWeight.w700),
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
            'Try adjusting your filters, or make a new payment.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textMuted, fontSize: 12.5, height: 1.45),
          ),
          const SizedBox(height: 18),
          NeonButton(
            label: 'Make a payment',
            icon: Icons.qr_code_scanner_rounded,
            onPressed: () => context.push('/scan'),
            height: 46,
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
