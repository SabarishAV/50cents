import 'package:material_ui/material_ui.dart';

import 'package:_50cents/core/theme/app_colors.dart';
import 'package:_50cents/core/widgets/neon_button.dart';
import 'package:_50cents/features/payments/data/upi_apps.dart';
import 'package:_50cents/features/payments/presentation/widgets/payment_ui.dart';

/// What the user chose in the "Pay with" picker.
///
/// A `null` [app] means "let the phone's own chooser decide" (the "Other apps"
/// tile), which is also what we fall back to when no UPI app was detected.
class UpiAppChoice {
  const UpiAppChoice(this.app);

  final UpiApp? app;
}

/// Asks the user which UPI app should handle the payment.
///
/// Shown only once the details are filled in and the user taps *Pay*, so the
/// form itself stays clean. Returns `null` when the sheet is dismissed without
/// choosing, which means the caller should not submit anything.
Future<UpiAppChoice?> showUpiAppPicker(
  BuildContext context, {
  required List<UpiApp> apps,
  String? subtitle,
  String? preselectId,
}) {
  return showModalBottomSheet<UpiAppChoice>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.62),
    builder: (_) => _UpiAppPickerSheet(apps: apps, subtitle: subtitle, preselectId: preselectId),
  );
}

class _UpiAppPickerSheet extends StatefulWidget {
  const _UpiAppPickerSheet({required this.apps, this.subtitle, this.preselectId});

  final List<UpiApp> apps;
  final String? subtitle;
  final String? preselectId;

  @override
  State<_UpiAppPickerSheet> createState() => _UpiAppPickerSheetState();
}

class _UpiAppPickerSheetState extends State<_UpiAppPickerSheet> {
  /// The app the user picked. `null` selects the "Other apps" tile.
  UpiApp? _selected;

  @override
  void initState() {
    super.initState();
    _selected = _initialSelection();
  }

  /// Preselects the app used last time so the common case is a single tap.
  UpiApp? _initialSelection() {
    final apps = widget.apps;
    if (apps.isEmpty) return null;

    final lastId = widget.preselectId;
    if (lastId != null) {
      for (final app in apps) {
        if (app.id == lastId) return app;
      }
    }
    return apps.first;
  }

  void _confirm() => Navigator.of(context).pop(UpiAppChoice(_selected));

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final selected = _selected;
    final buttonLabel = selected == null ? 'Open app chooser' : 'Continue with ${selected.name}';

    return Padding(
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: Container(
        constraints: BoxConstraints(maxHeight: media.size.height * 0.85),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const PaymentSheetHandle(),
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 0, 12, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Pay with',
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.2,
                            ),
                          ),
                          if (widget.subtitle != null) ...[
                            const SizedBox(height: 3),
                            Text(
                              widget.subtitle!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                            ),
                          ],
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
              const SizedBox(height: 12),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(22, 4, 22, 8),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      const spacing = 8.0;
                      final tileWidth = (constraints.maxWidth - spacing * 3) / 4;

                      return Wrap(
                        spacing: spacing,
                        runSpacing: 12,
                        children: [
                          for (final app in widget.apps)
                            _UpiAppPickerTile(
                              app: app,
                              label: app.name,
                              width: tileWidth,
                              selected: _selected?.id == app.id,
                              onTap: () => setState(() => _selected = app),
                            ),
                          // Defer to the phone's own chooser, e.g. for an app
                          // that could not be detected or is not listed here.
                          _UpiAppPickerTile(
                            icon: Icons.apps_rounded,
                            label: 'Other apps',
                            width: tileWidth,
                            selected: _selected == null,
                            onTap: () => setState(() => _selected = null),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 10, 22, 14),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    NeonButton(label: buttonLabel, icon: Icons.bolt_rounded, onPressed: _confirm, height: 52),
                    const SizedBox(height: 8),
                    const Text(
                      'Your payment is saved to your records first, then handed to the app.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.textMuted, fontSize: 10.5, height: 1.4),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One choice in the picker: a real launcher icon when available (Android),
/// an initials avatar otherwise, or a glyph for the "Other apps" tile.
class _UpiAppPickerTile extends StatelessWidget {
  const _UpiAppPickerTile({
    this.app,
    required this.label,
    this.icon,
    required this.selected,
    required this.onTap,
    required this.width,
  });

  final UpiApp? app;
  final String label;
  final IconData? icon;
  final bool selected;
  final VoidCallback onTap;
  final double width;

  @override
  Widget build(BuildContext context) {
    final bytes = app?.icon;

    return SizedBox(
      width: width,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 56,
                height: 56,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned.fill(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 140),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.background.withValues(alpha: 0.65),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: selected ? AppColors.neonBlue : AppColors.border,
                            width: selected ? 1.8 : 1,
                          ),
                          boxShadow: selected
                              ? [
                                  BoxShadow(
                                    color: AppColors.neonBlue.withValues(alpha: 0.35),
                                    blurRadius: 16,
                                    spreadRadius: 1,
                                  ),
                                ]
                              : null,
                        ),
                        child: bytes != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Image.memory(bytes, fit: BoxFit.contain, gaplessPlayback: true),
                              )
                            : icon != null
                            ? Icon(icon, color: selected ? AppColors.neonBlueBright : AppColors.textMuted, size: 24)
                            : PaymentAvatar(label: label, size: 40, square: true),
                      ),
                    ),
                    if (selected)
                      Positioned(
                        right: -3,
                        bottom: -3,
                        child: Container(
                          width: 20,
                          height: 20,
                          decoration: const BoxDecoration(color: AppColors.neonBlue, shape: BoxShape.circle),
                          child: const Icon(Icons.check_rounded, size: 14, color: Colors.black),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 7),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: selected ? AppColors.textPrimary : AppColors.textMuted,
                  fontSize: 10.5,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
