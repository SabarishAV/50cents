import 'package:material_ui/material_ui.dart';

import 'package:_50cents/core/theme/app_colors.dart';

/// ---------------------------------------------------------------------------
/// Formatting helpers
/// ---------------------------------------------------------------------------

const List<String> _monthsShort = <String>[
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

String monthName(int month, {bool short = true}) {
  final index = (month - 1).clamp(0, 11);
  if (short) return _monthsShort[index];
  const long = <String>[
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
  return long[index];
}

/// Adds Indian digit grouping (`1234567` -> `12,34,567`).
String _groupIndian(String digits) {
  if (digits.length <= 3) return digits;

  final head = digits.substring(0, digits.length - 3);
  final tail = digits.substring(digits.length - 3);
  final groups = <String>[];

  var index = head.length;
  while (index > 2) {
    groups.insert(0, head.substring(index - 2, index));
    index -= 2;
  }
  if (index > 0) groups.insert(0, head.substring(0, index));

  return '${groups.join(',')},$tail';
}

/// Formats a rupee amount with Indian grouping, e.g. `₹12,34,567` or `₹499.50`.
String formatInr(num amount, {bool showPaise = false}) {
  final value = amount.toDouble();
  final absolute = value.abs();
  final paise = showPaise || absolute % 1 != 0;
  final fixed = absolute.toStringAsFixed(paise ? 2 : 0);
  final parts = fixed.split('.');
  final decimals = parts.length > 1 ? '.${parts[1]}' : '';
  final sign = value < 0 ? '−' : '';
  return '$sign₹${_groupIndian(parts.first)}$decimals';
}

/// `12 Nov 2026`
String formatDateShort(DateTime date) {
  final local = date.toLocal();
  return '${local.day} ${_monthsShort[local.month - 1]} ${local.year}';
}

/// `12 Nov 2026 · 4:30 PM`
String formatDateTime(DateTime date) => '${formatDateShort(date)} · ${formatTime(date)}';

/// `4:30 PM`
String formatTime(DateTime date) {
  final local = date.toLocal();
  final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
  final minute = local.minute.toString().padLeft(2, '0');
  final period = local.hour < 12 ? 'AM' : 'PM';
  return '$hour:$minute $period';
}

/// `Today`, `Yesterday` or `12 Nov 2026`.
String relativeDayLabel(DateTime date) {
  final local = date.toLocal();
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(local.year, local.month, local.day);
  final difference = today.difference(day).inDays;

  if (difference == 0) return 'Today';
  if (difference == 1) return 'Yesterday';
  return formatDateShort(local);
}

/// `Sep 2026 – Nov 2026`, collapsing equal months and years.
String formatMonthRange(int fromYear, int fromMonth, int toYear, int toMonth) {
  final from = '${monthName(fromMonth)} $fromYear';
  final to = '${monthName(toMonth)} $toYear';

  if (fromYear == toYear && fromMonth == toMonth) return to;
  if (fromYear == toYear) return '${monthName(fromMonth)} – $to';
  return '$from – $to';
}

/// Best-effort initials for a payee label.
String paymentInitials(String label) {
  final parts = label.trim().split(RegExp(r'[\s._-]+')).where((part) => part.isNotEmpty).toList(growable: false);
  if (parts.isEmpty) return '?';

  String firstLetter(String value) => value.substring(0, 1).toUpperCase();
  if (parts.length == 1) return firstLetter(parts.first);
  return '${firstLetter(parts.first)}${firstLetter(parts[1])}';
}

/// Icon representing the payment medium stored on a record.
IconData paymentMediumIcon(String medium) {
  final value = medium.trim().toUpperCase();
  if (value.contains('UPI')) return Icons.bolt_rounded;
  // Payments are recorded by the UPI app's name when we know it (see
  // upi_apps.dart); give those a wallet icon instead of the generic fallback.
  if (value.contains('PHONEPE') ||
      value.contains('PHONE PE') ||
      value.contains('PAYTM') ||
      value.contains('BHIM') ||
      value.contains('CRED') ||
      value.contains('NAVI') ||
      value.contains('SLICE') ||
      value.contains('MOBIKWIK') ||
      value.contains('FREECHARGE') ||
      value.contains('SUPERMONEY') ||
      value.contains('JUPITER') ||
      value.contains('INDMONEY')) {
    return Icons.account_balance_wallet_rounded;
  }
  if (value.contains('CARD')) return Icons.credit_card_rounded;
  if (value.contains('GOOGLE') || value.contains('WALLET')) return Icons.wallet_rounded;
  if (value.contains('AMAZON') || value.contains('STORE')) return Icons.shopping_bag_rounded;
  if (value.contains('BANK') || value.contains('NEFT') || value.contains('IMPS') || value.contains('RTGS')) {
    return Icons.account_balance_rounded;
  }
  if (value.contains('CASH')) return Icons.payments_rounded;
  return Icons.receipt_long_rounded;
}

/// Icon for a category name/code, used to make records easier to scan.
IconData paymentCategoryIcon({String code = '', String name = ''}) {
  final value = '$code $name'.toLowerCase();
  bool has(List<String> keywords) => keywords.any(value.contains);

  if (has(<String>['food', 'restaurant', 'cafe', 'dining', 'grocer', 'swiggy', 'zomato'])) {
    return Icons.restaurant_rounded;
  }
  if (has(<String>['travel', 'transport', 'cab', 'fuel', 'flight', 'train', 'uber'])) {
    return Icons.directions_car_rounded;
  }
  if (has(<String>['shop', 'cloth', 'fashion', 'amazon', 'flipkart', 'retail'])) {
    return Icons.shopping_bag_rounded;
  }
  if (has(<String>['bill', 'utility', 'electric', 'water', 'recharge', 'rent'])) {
    return Icons.receipt_rounded;
  }
  if (has(<String>['entertain', 'movie', 'music', 'game', 'subscription', 'ott'])) {
    return Icons.movie_rounded;
  }
  if (has(<String>['health', 'medical', 'doctor', 'pharma', 'gym', 'fitness'])) {
    return Icons.favorite_rounded;
  }
  if (has(<String>['education', 'school', 'college', 'course', 'book'])) {
    return Icons.school_rounded;
  }
  if (has(<String>['salary', 'income', 'refund', 'cashback', 'credit'])) {
    return Icons.savings_rounded;
  }
  if (has(<String>['transfer', 'friend', 'family', 'personal', 'send'])) {
    return Icons.swap_horiz_rounded;
  }
  return Icons.sell_rounded;
}

/// ---------------------------------------------------------------------------
/// Shared building blocks
/// ---------------------------------------------------------------------------

/// Frosted sheet surface with the app's rounded top, hairline border and a
/// soft neon hint along the top edge.
class PaymentSheetShell extends StatelessWidget {
  const PaymentSheetShell({super.key, required this.child, this.height});

  final Widget child;
  final double? height;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.45), blurRadius: 40, offset: const Offset(0, -12)),
        ],
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        child: Stack(
          children: [
            Positioned(
              top: -90,
              left: -40,
              right: -40,
              height: 180,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      colors: [AppColors.neonBlue.withValues(alpha: 0.12), Colors.transparent],
                      stops: const [0.0, 1.0],
                    ),
                  ),
                ),
              ),
            ),
            child,
          ],
        ),
      ),
    );
  }
}

/// Small grab handle used at the top of every payment sheet.
class PaymentSheetHandle extends StatelessWidget {
  const PaymentSheetHandle({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 44,
        height: 4,
        margin: const EdgeInsets.only(top: 10, bottom: 16),
        decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(4)),
      ),
    );
  }
}

/// Rounded icon container used for headers and list leading icons.
class PaymentIconBadge extends StatelessWidget {
  const PaymentIconBadge({
    super.key,
    required this.icon,
    this.size = 44,
    this.radius = 14,
    this.color = AppColors.neonBlue,
    this.filled = false,
  });

  final IconData icon;
  final double size;
  final double radius;
  final Color color;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: filled
              ? <Color>[color, Color.lerp(color, Colors.black, 0.32)!]
              : <Color>[color.withValues(alpha: 0.16), color.withValues(alpha: 0.05)],
        ),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: color.withValues(alpha: filled ? 0.55 : 0.26)),
        boxShadow: filled
            ? [BoxShadow(color: color.withValues(alpha: 0.28), blurRadius: 18, offset: const Offset(0, 6))]
            : null,
      ),
      child: Icon(icon, color: filled ? Colors.black : color, size: size * 0.46),
    );
  }
}

/// Deterministic gradient avatar for payees and contacts.
class PaymentAvatar extends StatelessWidget {
  const PaymentAvatar({super.key, required this.label, this.size = 44, this.square = false, this.icon});

  final String label;
  final double size;
  final bool square;
  final IconData? icon;

  static const List<List<Color>> _gradients = <List<Color>>[
    <Color>[Color(0xFF00B4FF), Color(0xFF0066E6)],
    <Color>[Color(0xFF22D3EE), Color(0xFF0E7490)],
    <Color>[Color(0xFF8B5CF6), Color(0xFF5B21B6)],
    <Color>[Color(0xFF00E5A0), Color(0xFF00875A)],
    <Color>[Color(0xFF60A5FA), Color(0xFF1D4ED8)],
  ];

  @override
  Widget build(BuildContext context) {
    final hash = label.codeUnits.fold<int>(0, (sum, unit) => sum + unit);
    final gradient = _gradients[hash % _gradients.length];

    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: gradient),
        shape: square ? BoxShape.rectangle : BoxShape.circle,
        borderRadius: square ? BorderRadius.circular(size * 0.32) : null,
        boxShadow: [
          BoxShadow(color: gradient.first.withValues(alpha: 0.26), blurRadius: 14, offset: const Offset(0, 4)),
        ],
      ),
      child: icon != null
          ? Icon(icon, color: Colors.black, size: size * 0.44)
          : Text(
              paymentInitials(label),
              style: TextStyle(
                color: Colors.black,
                fontSize: size * 0.34,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.2,
              ),
            ),
    );
  }
}

/// Compact status/category tag.
class PaymentPill extends StatelessWidget {
  const PaymentPill({
    super.key,
    required this.label,
    this.icon,
    this.color = AppColors.neonBlue,
    this.filled = false,
    this.fontSize = 10.5,
  });

  final String label;
  final IconData? icon;
  final Color color;
  final bool filled;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4.5),
      decoration: BoxDecoration(
        color: filled ? color : color.withValues(alpha: 0.11),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: filled ? 0.9 : 0.26)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, color: filled ? Colors.black : color, size: fontSize + 2),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              color: filled ? Colors.black : color,
              fontSize: fontSize,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.25,
            ),
          ),
        ],
      ),
    );
  }
}

/// One option in a [PaymentSegmentedControl].
class PaymentSegmentOption<T> {
  const PaymentSegmentOption({required this.value, required this.label, this.icon});

  final T value;
  final String label;
  final IconData? icon;
}

/// Dark segmented control with a soft neon selection state.
class PaymentSegmentedControl<T> extends StatelessWidget {
  const PaymentSegmentedControl({
    super.key,
    required this.options,
    required this.selected,
    required this.onChanged,
    this.height = 44,
  });

  final List<PaymentSegmentOption<T>> options;
  final T selected;
  final ValueChanged<T> onChanged;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.background.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          for (final option in options)
            Expanded(
              child: _Segment<T>(
                option: option,
                selected: option.value == selected,
                onTap: () => onChanged(option.value),
              ),
            ),
        ],
      ),
    );
  }
}

class _Segment<T> extends StatelessWidget {
  const _Segment({required this.option, required this.selected, required this.onTap});

  final PaymentSegmentOption<T> option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: selected
                ? LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.neonBlue.withValues(alpha: 0.24),
                      AppColors.neonBlueDeep.withValues(alpha: 0.14),
                    ],
                  )
                : null,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: selected ? AppColors.neonBlue.withValues(alpha: 0.45) : Colors.transparent),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (option.icon != null) ...[
                Icon(option.icon, size: 15, color: selected ? AppColors.neonBlueBright : AppColors.textMuted),
                const SizedBox(width: 5),
              ],
              Flexible(
                child: Text(
                  option.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: selected ? AppColors.neonBlueBright : AppColors.textMuted,
                    fontSize: 12.5,
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

/// Section heading used across payment surfaces.
class PaymentSectionLabel extends StatelessWidget {
  const PaymentSectionLabel({super.key, required this.label, this.trailing});

  final String label;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            color: AppColors.textMuted,
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.1,
          ),
        ),
        const Spacer(),
        ?trailing,
      ],
    );
  }
}

/// Rounded icon button used in app bars on transparent backgrounds.
class PaymentAppBarAction extends StatelessWidget {
  const PaymentAppBarAction({super.key, required this.icon, required this.onPressed, this.tooltip});

  final IconData icon;
  final VoidCallback onPressed;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Material(
        color: AppColors.surface.withValues(alpha: 0.85),
        shape: const CircleBorder(side: BorderSide(color: AppColors.border)),
        child: IconButton(
          tooltip: tooltip,
          onPressed: onPressed,
          visualDensity: VisualDensity.compact,
          icon: Icon(icon, color: AppColors.textPrimary, size: 20),
        ),
      ),
    );
  }
}
