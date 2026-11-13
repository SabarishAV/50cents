import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:_50cents/core/theme/app_colors.dart';
import 'package:_50cents/core/widgets/neon_background.dart';
import 'package:_50cents/core/widgets/neon_button.dart';
import 'package:_50cents/features/payments/data/models/payment_record.dart';
import 'package:_50cents/features/payments/data/models/payment_summary.dart';
import 'package:_50cents/features/payments/data/payment_repository.dart';
import 'package:_50cents/features/payments/presentation/widgets/payment_ui.dart';

const List<String> _transactionTypes = <String>['ALL', 'DEBIT', 'CREDIT'];

enum _FilterMode { thisMonth, last3Months, last6Months, custom }

/// Packs a year and month into a single comparable value.
int _monthKey(int year, int month) => year * 12 + month - 1;

int _keyYear(int key) => key ~/ 12;

int _keyMonth(int key) => key % 12 + 1;

extension on _FilterMode {
  String get label => switch (this) {
    _FilterMode.thisMonth => 'This month',
    _FilterMode.last3Months => 'Last 3 months',
    _FilterMode.last6Months => 'Last 6 months',
    _FilterMode.custom => 'Custom range',
  };
}

class _FilterSelection {
  const _FilterSelection({
    required this.mode,
    required this.transactionType,
    required this.fromYear,
    required this.fromMonth,
    required this.toYear,
    required this.toMonth,
  });

  final _FilterMode mode;
  final String transactionType;
  final int fromYear;
  final int fromMonth;
  final int toYear;
  final int toMonth;
}

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

  PaymentSummaryQuery get _summaryQuery => PaymentSummaryQuery(
    year: _fromYear,
    month: _fromMonth,
    toYear: _toYear,
    toMonth: _toMonth,
    onlyThisMonth: _filterMode == _FilterMode.thisMonth,
  );

  bool get _hasActiveFilters => _filterMode != _FilterMode.thisMonth || _transactionType != 'ALL';

  @override
  Widget build(BuildContext context) {
    final recordsState = ref.watch(paymentRecordsProvider(_query));
    final summaryState = ref.watch(paymentSummaryProvider(_summaryQuery));

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
                'Payment history',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                ),
              ),
              SizedBox(height: 1),
              Text(
                'Every rupee, accounted for',
                style: TextStyle(color: AppColors.textMuted, fontSize: 11.5, fontWeight: FontWeight.w500),
              ),
            ],
          ),
          actions: [
            PaymentAppBarAction(
              icon: Icons.qr_code_scanner_rounded,
              tooltip: 'Scan a UPI QR',
              onPressed: () => context.push('/scan'),
            ),
            const SizedBox(width: 16),
          ],
        ),
        body: SafeArea(
          child: RefreshIndicator(
            color: AppColors.neonBlue,
            backgroundColor: AppColors.surface,
            onRefresh: () async {
              ref.invalidate(paymentRecordsProvider(_query));
              ref.invalidate(paymentSummaryProvider(_summaryQuery));
              try {
                await ref.read(paymentRecordsProvider(_query).future);
              } catch (_) {
                // Errors surface through the provider's error state below.
              }
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              children: [
                _FilterToolbar(
                  transactionType: _transactionType,
                  filterMode: _filterMode,
                  fromYear: _fromYear,
                  fromMonth: _fromMonth,
                  toYear: _toYear,
                  toMonth: _toMonth,
                  onTransactionTypeChanged: _setTransactionType,
                  onOpenFilters: _openFilters,
                  onReset: _hasActiveFilters ? _resetFilters : null,
                ),
                const SizedBox(height: 18),
                recordsState.when(
                  loading: () => const _HistoryLoading(),
                  error: (error, _) => _StatePanel(
                    icon: Icons.cloud_off_rounded,
                    title: 'Could not load payments',
                    message: apiErrorMessage(error),
                    actionLabel: 'Try again',
                    onAction: () => ref.invalidate(paymentRecordsProvider(_query)),
                  ),
                  data: (page) => page.data.isEmpty
                      ? _StatePanel(
                          icon: Icons.receipt_long_rounded,
                          title: 'No payments here',
                          message: 'Nothing matches these filters yet. Try a wider date range or a different type.',
                          actionLabel: _hasActiveFilters ? 'Reset filters' : null,
                          onAction: _hasActiveFilters ? _resetFilters : null,
                        )
                      : _HistoryContent(
                          page: page,
                          summary: summaryState,
                          onLoadMore: _loadMore,
                          onRecordChanged: () {
                            ref.invalidate(paymentRecordsProvider(_query));
                            ref.invalidate(paymentSummaryProvider(_summaryQuery));
                          },
                          onRetrySummary: () => ref.invalidate(paymentSummaryProvider(_summaryQuery)),
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
    if (type == _transactionType) return;
    setState(() {
      _transactionType = type;
      _pageNumber = 1;
    });
  }

  void _resetFilters() {
    final now = DateTime.now();
    setState(() {
      _filterMode = _FilterMode.thisMonth;
      _transactionType = 'ALL';
      _fromYear = now.year;
      _fromMonth = now.month;
      _toYear = now.year;
      _toMonth = now.month;
      _pageNumber = 1;
    });
  }

  Future<void> _openFilters() async {
    final result = await showModalBottomSheet<_FilterSelection>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _FilterSheet(
        selection: _FilterSelection(
          mode: _filterMode,
          transactionType: _transactionType,
          fromYear: _fromYear,
          fromMonth: _fromMonth,
          toYear: _toYear,
          toMonth: _toMonth,
        ),
      ),
    );

    if (result == null || !mounted) return;

    setState(() {
      _filterMode = result.mode;
      _transactionType = result.transactionType;
      _fromYear = result.fromYear;
      _fromMonth = result.fromMonth;
      _toYear = result.toYear;
      _toMonth = result.toMonth;
      _pageNumber = 1;
    });
  }

  void _loadMore() {
    setState(() => _pageNumber += 1);
  }
}

// ---------------------------------------------------------------------------
// Filters
// ---------------------------------------------------------------------------

class _FilterToolbar extends StatelessWidget {
  const _FilterToolbar({
    required this.transactionType,
    required this.filterMode,
    required this.fromYear,
    required this.fromMonth,
    required this.toYear,
    required this.toMonth,
    required this.onTransactionTypeChanged,
    required this.onOpenFilters,
    this.onReset,
  });

  final String transactionType;
  final _FilterMode filterMode;
  final int fromYear;
  final int fromMonth;
  final int toYear;
  final int toMonth;
  final ValueChanged<String> onTransactionTypeChanged;
  final VoidCallback onOpenFilters;
  final VoidCallback? onReset;

  @override
  Widget build(BuildContext context) {
    final selectedType = _transactionTypes.contains(transactionType.trim().toUpperCase())
        ? transactionType.trim().toUpperCase()
        : 'ALL';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PaymentSegmentedControl<String>(
          selected: selectedType,
          onChanged: onTransactionTypeChanged,
          options: const <PaymentSegmentOption<String>>[
            PaymentSegmentOption<String>(value: 'ALL', label: 'All', icon: Icons.auto_awesome_mosaic_rounded),
            PaymentSegmentOption<String>(value: 'DEBIT', label: 'Sent', icon: Icons.north_east_rounded),
            PaymentSegmentOption<String>(value: 'CREDIT', label: 'Received', icon: Icons.south_west_rounded),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onOpenFilters,
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    height: 56,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: filterMode == _FilterMode.custom
                            ? AppColors.neonBlue.withValues(alpha: 0.4)
                            : AppColors.border,
                      ),
                    ),
                    child: Row(
                      children: [
                        PaymentIconBadge(
                          icon: Icons.tune_rounded,
                          size: 34,
                          radius: 10,
                          color: filterMode == _FilterMode.custom ? AppColors.neonBlue : AppColors.textMuted,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                filterMode.label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                formatMonthRange(fromYear, fromMonth, toYear, toMonth),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: AppColors.textMuted, fontSize: 10.5),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.textMuted, size: 20),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            if (onReset != null) ...[
              const SizedBox(width: 10),
              Material(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
                child: InkWell(
                  onTap: onReset,
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: const Icon(Icons.filter_alt_off_rounded, color: AppColors.textMuted, size: 20),
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

class _FilterSheet extends StatefulWidget {
  const _FilterSheet({required this.selection});

  final _FilterSelection selection;

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late String _transactionType;
  late _FilterMode _mode;
  late int _fromYear;
  late int _fromMonth;
  late int _toYear;
  late int _toMonth;

  @override
  void initState() {
    super.initState();
    final selection = widget.selection;
    _transactionType = selection.transactionType;
    _mode = selection.mode;
    _fromYear = selection.fromYear;
    _fromMonth = selection.fromMonth;
    _toYear = selection.toYear;
    _toMonth = selection.toMonth;
  }

  void _applyPreset(_FilterMode mode) {
    final now = DateTime.now();
    var fromMonth = now.month;
    var fromYear = now.year;

    if (mode == _FilterMode.last3Months || mode == _FilterMode.last6Months) {
      final monthsBack = mode == _FilterMode.last3Months ? 2 : 5;
      fromMonth -= monthsBack;
      while (fromMonth <= 0) {
        fromMonth += 12;
        fromYear -= 1;
      }
    }

    setState(() {
      _mode = mode;
      if (mode == _FilterMode.custom) return;
      _fromYear = fromYear;
      _fromMonth = fromMonth;
      _toYear = now.year;
      _toMonth = now.month;
    });
  }

  Future<void> _pickMonth({required bool isFrom}) async {
    final now = DateTime.now();
    final currentKey = _monthKey(now.year, now.month);
    final fromKey = _monthKey(_fromYear, _fromMonth);
    final toKey = _monthKey(_toYear, _toMonth);

    // The start can never be after the end, and neither can reach the future.
    final maxKey = isFrom ? (toKey < currentKey ? toKey : currentKey) : currentKey;
    final minKey = isFrom ? _monthKey(2000, 1) : (fromKey > maxKey ? maxKey : fromKey);

    final key = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _MonthPickerSheet(
        year: isFrom ? _fromYear : _toYear,
        month: isFrom ? _fromMonth : _toMonth,
        title: isFrom ? 'Start month' : 'End month',
        minKey: minKey,
        maxKey: maxKey,
      ),
    );
    if (key == null || !mounted) return;

    final year = _keyYear(key);
    final month = _keyMonth(key);

    setState(() {
      _mode = _FilterMode.custom;
      if (isFrom) {
        _fromYear = year;
        _fromMonth = month;
      } else {
        _toYear = year;
        _toMonth = month;
      }
    });
  }

  bool get _isRangeValid => _monthKey(_fromYear, _fromMonth) <= _monthKey(_toYear, _toMonth);

  void _apply() {
    if (!_isRangeValid) return;
    Navigator.of(context).pop(
      _FilterSelection(
        mode: _mode,
        transactionType: _transactionType,
        fromYear: _fromYear,
        fromMonth: _fromMonth,
        toYear: _toYear,
        toMonth: _toMonth,
      ),
    );
  }

  void _reset() {
    final now = DateTime.now();
    setState(() {
      _transactionType = 'ALL';
      _mode = _FilterMode.thisMonth;
      _fromYear = now.year;
      _fromMonth = now.month;
      _toYear = now.year;
      _toMonth = now.month;
    });
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final height = (media.size.height - media.viewInsets.bottom) * 0.88;

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
                  const PaymentIconBadge(icon: Icons.tune_rounded, size: 42, radius: 13),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Filter payments',
                          style: TextStyle(color: AppColors.textPrimary, fontSize: 17, fontWeight: FontWeight.w700),
                        ),
                        SizedBox(height: 2),
                        Text('Narrow down what you see', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
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
            const SizedBox(height: 18),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(22, 0, 22, 22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const PaymentSectionLabel(label: 'Transaction type'),
                    const SizedBox(height: 10),
                    PaymentSegmentedControl<String>(
                      selected: _transactionType,
                      onChanged: (value) => setState(() => _transactionType = value),
                      options: const <PaymentSegmentOption<String>>[
                        PaymentSegmentOption<String>(
                          value: 'ALL',
                          label: 'All',
                          icon: Icons.auto_awesome_mosaic_rounded,
                        ),
                        PaymentSegmentOption<String>(value: 'DEBIT', label: 'Sent', icon: Icons.north_east_rounded),
                        PaymentSegmentOption<String>(
                          value: 'CREDIT',
                          label: 'Received',
                          icon: Icons.south_west_rounded,
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),
                    const PaymentSectionLabel(label: 'Period'),
                    const SizedBox(height: 10),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        const gap = 8.0;
                        final optionWidth = (constraints.maxWidth - gap) / 2 - 0.5;
                        return Wrap(
                          spacing: gap,
                          runSpacing: gap,
                          children: [
                            for (final mode in _FilterMode.values)
                              SizedBox(
                                width: optionWidth,
                                child: _PresetOption(
                                  mode: mode,
                                  selected: _mode == mode,
                                  onTap: () => _applyPreset(mode),
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: _MonthField(
                            label: 'From',
                            year: _fromYear,
                            month: _fromMonth,
                            onTap: () => _pickMonth(isFrom: true),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _MonthField(
                            label: 'To',
                            year: _toYear,
                            month: _toMonth,
                            onTap: () => _pickMonth(isFrom: false),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: (_isRangeValid ? AppColors.background : AppColors.expense).withValues(alpha: 0.45),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: _isRangeValid ? AppColors.border : AppColors.expense.withValues(alpha: 0.5),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            _isRangeValid ? Icons.info_outline_rounded : Icons.error_outline_rounded,
                            color: _isRangeValid ? AppColors.neonBlue : AppColors.expense,
                            size: 16,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _isRangeValid
                                  ? 'Showing payments from ${formatMonthRange(_fromYear, _fromMonth, _toYear, _toMonth)}.'
                                  : 'The "from" month must be earlier than or equal to the "to" month.',
                              style: TextStyle(
                                color: _isRangeValid ? AppColors.textMuted : AppColors.expense,
                                fontSize: 11.5,
                                height: 1.45,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(22, 14, 22, 14),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: AppColors.border)),
                color: AppColors.surface,
              ),
              child: SafeArea(
                top: false,
                child: Row(
                  children: [
                    TextButton(
                      onPressed: _reset,
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.textMuted,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                      ),
                      child: const Text('Reset'),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: NeonButton(
                        label: 'Apply filters',
                        icon: Icons.check_rounded,
                        onPressed: _isRangeValid ? _apply : null,
                        height: 50,
                      ),
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

class _PresetOption extends StatelessWidget {
  const _PresetOption({required this.mode, required this.selected, required this.onTap});

  final _FilterMode mode;
  final bool selected;
  final VoidCallback onTap;

  IconData get _icon => switch (mode) {
    _FilterMode.thisMonth => Icons.calendar_today_rounded,
    _FilterMode.last3Months => Icons.date_range_rounded,
    _FilterMode.last6Months => Icons.calendar_view_month_rounded,
    _FilterMode.custom => Icons.tune_rounded,
  };

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: selected ? AppColors.neonBlue.withValues(alpha: 0.13) : AppColors.background.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: selected ? AppColors.neonBlue.withValues(alpha: 0.55) : AppColors.border),
          ),
          child: Row(
            children: [
              Icon(_icon, size: 15, color: selected ? AppColors.neonBlueBright : AppColors.textMuted),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  mode.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: selected ? AppColors.neonBlueBright : AppColors.textPrimary,
                    fontSize: 12,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                  ),
                ),
              ),
              if (selected) ...[
                const SizedBox(width: 4),
                const Icon(Icons.check_circle_rounded, color: AppColors.neonBlue, size: 15),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _MonthField extends StatelessWidget {
  const _MonthField({required this.label, required this.year, required this.month, required this.onTap});

  final String label;
  final int year;
  final int month;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textMuted,
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
          ),
        ),
        const SizedBox(height: 7),
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              height: 50,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: AppColors.background.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_month_rounded, color: AppColors.neonBlue, size: 17),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      '${monthName(month)} $year',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: AppColors.textPrimary, fontSize: 12.5, fontWeight: FontWeight.w600),
                    ),
                  ),
                  const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.textMuted, size: 18),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _MonthPickerSheet extends StatefulWidget {
  const _MonthPickerSheet({
    required this.year,
    required this.month,
    required this.title,
    required this.minKey,
    required this.maxKey,
  });

  final int year;
  final int month;
  final String title;
  final int minKey;
  final int maxKey;

  @override
  State<_MonthPickerSheet> createState() => _MonthPickerSheetState();
}

class _MonthPickerSheetState extends State<_MonthPickerSheet> {
  late int _year;
  late int _month;

  int get _minYear => _keyYear(widget.minKey);
  int get _maxYear => _keyYear(widget.maxKey);

  @override
  void initState() {
    super.initState();
    _year = widget.year.clamp(_minYear, _maxYear);
    _month = widget.month;

    // Snap a stale selection into the allowed range.
    final key = _monthKey(_year, _month);
    if (key < widget.minKey) {
      _month = _keyMonth(widget.minKey);
    } else if (key > widget.maxKey) {
      _month = _keyMonth(widget.maxKey);
    }
  }

  bool _canSelect(int month) {
    final key = _monthKey(_year, month);
    return key >= widget.minKey && key <= widget.maxKey;
  }

  void _changeYear(int delta) {
    final year = _year + delta;
    if (year < _minYear || year > _maxYear) return;

    setState(() {
      _year = year;
      final key = _monthKey(_year, _month);
      if (key < widget.minKey) {
        _month = _keyMonth(widget.minKey);
      } else if (key > widget.maxKey) {
        _month = _keyMonth(widget.maxKey);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final canGoBack = _year > _minYear;
    final canGoForward = _year < _maxYear;
    final minLabel = '${monthName(_keyMonth(widget.minKey))} $_minYear';
    final maxLabel = '${monthName(_keyMonth(widget.maxKey))} $_maxYear';

    return PaymentSheetShell(
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 0, 22, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const PaymentSheetHandle(),
              Row(
                children: [
                  Text(
                    widget.title,
                    style: const TextStyle(color: AppColors.textPrimary, fontSize: 17, fontWeight: FontWeight.w700),
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded, color: AppColors.textMuted, size: 20),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                widget.minKey == widget.maxKey ? 'Only $minLabel is available.' : '$minLabel – $maxLabel',
                style: const TextStyle(color: AppColors.textMuted, fontSize: 11.5),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.background.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    IconButton(
                      tooltip: 'Previous year',
                      onPressed: canGoBack ? () => _changeYear(-1) : null,
                      icon: Icon(
                        Icons.chevron_left_rounded,
                        color: canGoBack ? AppColors.neonBlue : AppColors.textMuted.withValues(alpha: 0.3),
                        size: 24,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        '$_year',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Next year',
                      onPressed: canGoForward ? () => _changeYear(1) : null,
                      icon: Icon(
                        Icons.chevron_right_rounded,
                        color: canGoForward ? AppColors.neonBlue : AppColors.textMuted.withValues(alpha: 0.3),
                        size: 24,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 4,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 1.55,
                children: [
                  for (final m in List<int>.generate(12, (index) => index + 1))
                    _MonthChip(
                      name: monthName(m),
                      selected: m == _month,
                      enabled: _canSelect(m),
                      onTap: () => setState(() => _month = m),
                    ),
                ],
              ),
              const SizedBox(height: 18),
              NeonButton(
                label: 'Use ${monthName(_month)} $_year',
                icon: Icons.calendar_month_rounded,
                height: 50,
                onPressed: _canSelect(_month) ? () => Navigator.of(context).pop(_monthKey(_year, _month)) : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MonthChip extends StatelessWidget {
  const _MonthChip({required this.name, required this.selected, required this.enabled, required this.onTap});

  final String name;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(11),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? AppColors.neonBlue : AppColors.background.withValues(alpha: enabled ? 0.5 : 0.2),
            borderRadius: BorderRadius.circular(11),
            border: Border.all(
              color: selected
                  ? AppColors.neonBlue
                  : enabled
                  ? AppColors.border
                  : AppColors.border.withValues(alpha: 0.4),
            ),
          ),
          child: Text(
            name,
            style: TextStyle(
              color: selected
                  ? Colors.black
                  : enabled
                  ? AppColors.textPrimary
                  : AppColors.textMuted.withValues(alpha: 0.35),
              fontSize: 12.5,
              fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Results
// ---------------------------------------------------------------------------

class _HistoryContent extends StatelessWidget {
  const _HistoryContent({
    required this.page,
    required this.summary,
    required this.onLoadMore,
    required this.onRetrySummary,
    this.onRecordChanged,
  });

  final PaymentRecordsPage page;
  final AsyncValue<PaymentSummary> summary;
  final VoidCallback onLoadMore;
  final VoidCallback onRetrySummary;
  final VoidCallback? onRecordChanged;

  @override
  Widget build(BuildContext context) {
    final records = page.data;

    final groups = <DateTime, List<PaymentRecord>>{};
    for (final record in records) {
      final local = record.paidAt.toLocal();
      final day = DateTime(local.year, local.month, local.day);
      groups.putIfAbsent(day, () => <PaymentRecord>[]).add(record);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SummaryCard(summary: summary, totalCount: page.totalElements, records: records, onRetry: onRetrySummary),
        const SizedBox(height: 22),
        Row(
          children: [
            const Text(
              'Transactions',
              style: TextStyle(color: AppColors.textPrimary, fontSize: 15, fontWeight: FontWeight.w700),
            ),
            const Spacer(),
            Text(
              '${page.totalElements} total',
              style: const TextStyle(color: AppColors.textMuted, fontSize: 11.5, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        const SizedBox(height: 12),
        for (final entry in groups.entries) ...[
          _DayHeader(date: entry.key, records: entry.value),
          const SizedBox(height: 8),
          for (final record in entry.value)
            Padding(
              padding: const EdgeInsets.only(bottom: 9),
              child: _PaymentRecordTile(record: record, onRecordChanged: onRecordChanged),
            ),
          const SizedBox(height: 4),
        ],
        if (page.hasNext) _LoadMoreButton(onPressed: onLoadMore),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.summary, required this.totalCount, required this.records, required this.onRetry});

  final AsyncValue<PaymentSummary> summary;
  final int totalCount;
  final List<PaymentRecord> records;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final data = summary.asData?.value;
    final loading = summary.isLoading && data == null;
    final failed = summary.hasError && data == null;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.neonBlue.withValues(alpha: 0.17),
            AppColors.surface,
            Color.lerp(AppColors.surface, AppColors.neonBlueDeep, 0.05)!,
          ],
          stops: const [0.0, 0.55, 1.0],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.neonBlue.withValues(alpha: 0.2)),
        boxShadow: [BoxShadow(color: AppColors.neonBlue.withValues(alpha: 0.07), blurRadius: 32, spreadRadius: 1)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const PaymentPill(label: 'Period summary', icon: Icons.auto_graph_rounded),
              const Spacer(),
              Text(
                '$totalCount payment${totalCount == 1 ? '' : 's'}',
                style: const TextStyle(color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _SummaryValue(
                  label: 'Money out',
                  amount: data?.totalDebit,
                  loading: loading,
                  color: AppColors.textPrimary,
                ),
              ),
              Container(
                width: 1,
                height: 54,
                margin: const EdgeInsets.symmetric(horizontal: 16),
                color: AppColors.border,
              ),
              Expanded(
                child: _SummaryValue(
                  label: 'Money in',
                  amount: data?.totalCredit,
                  loading: loading,
                  color: AppColors.income,
                ),
              ),
            ],
          ),
          if (failed) ...[
            const SizedBox(height: 14),
            Material(
              color: AppColors.expense.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                onTap: onRetry,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.expense.withValues(alpha: 0.25)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline_rounded, color: AppColors.expense, size: 15),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Could not load totals.',
                          style: TextStyle(color: AppColors.textPrimary, fontSize: 11.5, fontWeight: FontWeight.w600),
                        ),
                      ),
                      Text(
                        'Retry',
                        style: TextStyle(color: AppColors.neonBlueBright, fontSize: 11.5, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
          if (data != null) ...[const SizedBox(height: 14), _NetRow(net: data.net)],
          const SizedBox(height: 18),
          _ActivityBars(records: records),
        ],
      ),
    );
  }
}

class _SummaryValue extends StatelessWidget {
  const _SummaryValue({required this.label, required this.amount, required this.loading, required this.color});

  final String label;
  final double? amount;
  final bool loading;
  final Color color;

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
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 6),
        if (loading)
          Container(
            width: 96,
            height: 24,
            decoration: BoxDecoration(
              color: AppColors.textMuted.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(7),
            ),
          )
        else
          Align(
            alignment: Alignment.centerLeft,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                amount == null ? '—' : formatInr(amount!),
                style: TextStyle(
                  color: amount == null ? AppColors.textMuted : color,
                  fontSize: 25,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.8,
                  height: 1.05,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _NetRow extends StatelessWidget {
  const _NetRow({required this.net});

  final double net;

  @override
  Widget build(BuildContext context) {
    final color = net < 0 ? AppColors.expense : AppColors.income;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Row(
        children: [
          Icon(net < 0 ? Icons.trending_down_rounded : Icons.trending_up_rounded, color: color, size: 16),
          const SizedBox(width: 8),
          const Text(
            'Net for this period',
            style: TextStyle(color: AppColors.textMuted, fontSize: 11.5, fontWeight: FontWeight.w600),
          ),
          const Spacer(),
          Text(
            '${net < 0 ? '−' : '+'}${formatInr(net.abs())}',
            style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: -0.2),
          ),
        ],
      ),
    );
  }
}

class _ActivityBars extends StatelessWidget {
  const _ActivityBars({required this.records});

  final List<PaymentRecord> records;

  static const List<String> _weekdayLetters = <String>['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  @override
  Widget build(BuildContext context) {
    if (records.isEmpty) return const SizedBox.shrink();

    DateTime latest = records.first.paidAt.toLocal();
    for (final record in records) {
      final local = record.paidAt.toLocal();
      if (local.isAfter(latest)) latest = local;
    }

    final days = List<DateTime>.generate(7, (index) {
      final offset = 6 - index;
      return DateTime(latest.year, latest.month, latest.day - offset);
    });

    final totals = <DateTime, double>{};
    for (final record in records) {
      if (record.isCredit) continue;
      final local = record.paidAt.toLocal();
      final day = DateTime(local.year, local.month, local.day);
      totals[day] = (totals[day] ?? 0) + record.amount;
    }

    final maxValue = totals.values.fold<double>(0, (max, value) => value > max ? value : max);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (var index = 0; index < days.length; index++) ...[
          if (index > 0) const SizedBox(width: 7),
          Expanded(
            child: Column(
              children: [
                Container(
                  height: 4 + (maxValue == 0 ? 0 : (totals[days[index]] ?? 0) / maxValue * 30),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: index == days.length - 1
                          ? <Color>[AppColors.neonBlueBright, AppColors.neonBlue]
                          : <Color>[
                              AppColors.neonBlue.withValues(alpha: 0.45),
                              AppColors.neonBlueDeep.withValues(alpha: 0.2),
                            ],
                    ),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _weekdayLetters[days[index].weekday - 1],
                  style: TextStyle(
                    color: index == days.length - 1 ? AppColors.neonBlueBright : AppColors.textMuted,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _DayHeader extends StatelessWidget {
  const _DayHeader({required this.date, required this.records});

  final DateTime date;
  final List<PaymentRecord> records;

  @override
  Widget build(BuildContext context) {
    var net = 0.0;
    for (final record in records) {
      net += record.isCredit ? record.amount : -record.amount;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        children: [
          Text(
            relativeDayLabel(date),
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 12, fontWeight: FontWeight.w700),
          ),
          const SizedBox(width: 7),
          Container(
            width: 3,
            height: 3,
            decoration: const BoxDecoration(color: AppColors.textMuted, shape: BoxShape.circle),
          ),
          const SizedBox(width: 7),
          Text(
            '${records.length} ${records.length == 1 ? 'payment' : 'payments'}',
            style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
          ),
          const Spacer(),
          if (net != 0)
            Text(
              '${net > 0 ? '+' : '−'}${formatInr(net.abs())}',
              style: TextStyle(
                color: net > 0 ? AppColors.income : AppColors.textMuted,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
        ],
      ),
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
    final accent = isCredit ? AppColors.income : AppColors.neonBlue;
    final note = record.note?.trim();

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () async {
          final deleted = await context.push<bool>('/payment-records/${record.id}');
          if (deleted == true && context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Row(
                  children: [
                    Icon(Icons.check_circle_rounded, color: AppColors.income, size: 18),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text('Payment deleted.', style: TextStyle(color: AppColors.textPrimary, fontSize: 13)),
                    ),
                  ],
                ),
              ),
            );
            onRecordChanged?.call();
          }
        },
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.surface, Color.lerp(AppColors.surface, accent, 0.035)!],
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.border),
          ),
          padding: const EdgeInsets.fromLTRB(13, 13, 14, 13),
          child: Row(
            children: [
              _RecordLeading(record: record, accent: accent),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      record.payeeLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(paymentMediumIcon(record.paymentMedium), size: 12, color: AppColors.textMuted),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            record.paymentMedium,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (record.bankUpdated) ...[
                          const SizedBox(width: 6),
                          const Icon(Icons.cloud_done_rounded, color: AppColors.income, size: 12),
                        ],
                      ],
                    ),
                    if (note != null && note.isNotEmpty) ...[
                      const SizedBox(height: 5),
                      Text(
                        note,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: AppColors.textMuted, fontSize: 11.5, height: 1.3),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${isCredit ? '+' : '−'}${formatInr(record.amount)}',
                    style: TextStyle(
                      color: isCredit ? AppColors.income : AppColors.textPrimary,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    formatTime(record.paidAt),
                    style: const TextStyle(color: AppColors.textMuted, fontSize: 10.5, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecordLeading extends StatelessWidget {
  const _RecordLeading({required this.record, required this.accent});

  final PaymentRecord record;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final hasCategory = record.category.code.isNotEmpty || record.category.name.trim().isNotEmpty;
    final badgeIcon = hasCategory
        ? paymentCategoryIcon(code: record.category.code, name: record.category.name)
        : paymentMediumIcon(record.paymentMedium);

    return SizedBox(
      width: 46,
      height: 46,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          PaymentAvatar(label: record.payeeLabel, size: 44),
          Positioned(
            right: -1,
            bottom: -1,
            child: Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: AppColors.surface,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.border),
              ),
              child: Icon(badgeIcon, color: accent, size: 11),
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadMoreButton extends StatelessWidget {
  const _LoadMoreButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: SizedBox(
        height: 50,
        child: OutlinedButton.icon(
          onPressed: onPressed,
          icon: const Icon(Icons.expand_more_rounded, size: 19),
          label: const Text('Load more payments'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.neonBlueBright,
            backgroundColor: AppColors.surface,
            side: BorderSide(color: AppColors.neonBlue.withValues(alpha: 0.3)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          ),
        ),
      ),
    );
  }
}

class _HistoryLoading extends StatelessWidget {
  const _HistoryLoading();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _Skeleton(height: 168, radius: 22),
        const SizedBox(height: 22),
        Row(
          children: [
            const _Skeleton(width: 108, height: 14, radius: 6),
            const Spacer(),
            const _Skeleton(width: 62, height: 12, radius: 6),
          ],
        ),
        const SizedBox(height: 12),
        for (var index = 0; index < 4; index++) ...[const _Skeleton(height: 74, radius: 18), const SizedBox(height: 9)],
        const SizedBox(height: 8),
        const Center(
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.neonBlue),
          ),
        ),
      ],
    );
  }
}

class _Skeleton extends StatelessWidget {
  const _Skeleton({this.width, required this.height, this.radius = 10});

  final double? width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.surface, Color.lerp(AppColors.surface, AppColors.neonBlue, 0.06)!],
        ),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: AppColors.border),
      ),
    );
  }
}

class _StatePanel extends StatelessWidget {
  const _StatePanel({required this.icon, required this.title, required this.message, this.actionLabel, this.onAction});

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

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
          PaymentIconBadge(icon: icon, size: 64, radius: 20),
          const SizedBox(height: 18),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 7),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textMuted, fontSize: 12.5, height: 1.5),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 20),
            SizedBox(
              width: 172,
              child: NeonButton(label: actionLabel!, icon: Icons.refresh_rounded, onPressed: onAction, height: 46),
            ),
          ],
        ],
      ),
    );
  }
}
