import 'package:flutter/material.dart';

import 'package:_50cents/core/theme/app_colors.dart';
import 'package:_50cents/core/theme/app_inputs.dart';
import 'package:_50cents/core/widgets/neon_button.dart';
import 'package:_50cents/features/payments/data/contact_directory.dart';
import 'package:_50cents/features/payments/presentation/widgets/payment_ui.dart';

/// Opens a searchable contact picker and returns the selected phone number.
Future<String?> showContactPicker(BuildContext context) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _ContactPickerSheet(),
  );
}

class _ContactPickerSheet extends StatefulWidget {
  const _ContactPickerSheet();

  @override
  State<_ContactPickerSheet> createState() => _ContactPickerSheetState();
}

class _ContactPickerSheetState extends State<_ContactPickerSheet> {
  final _searchController = TextEditingController();
  late Future<List<ContactEntry>> _contactsFuture;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _contactsFuture = ContactDirectory.load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _retry() {
    setState(() => _contactsFuture = ContactDirectory.load(refresh: true));
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() => _query = '');
  }

  List<ContactEntry> _filter(List<ContactEntry> entries) {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return entries;

    final digits = query.replaceAll(RegExp(r'[^0-9]'), '');
    return entries
        .where((entry) {
          if (entry.name.toLowerCase().contains(query)) return true;
          return digits.isNotEmpty && entry.digits.contains(digits);
        })
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final bottomInset = media.viewInsets.bottom;
    final height = (media.size.height - bottomInset) * 0.9;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: PaymentSheetShell(
        height: height,
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              const PaymentSheetHandle(),
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 0, 14, 0),
                child: Row(
                  children: [
                    const PaymentIconBadge(icon: Icons.contacts_rounded, size: 42, radius: 13),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Choose a contact',
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.2,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Search by name or phone number',
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
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 14, 22, 6),
                child: TextField(
                  controller: _searchController,
                  autofocus: true,
                  onChanged: (value) => setState(() => _query = value),
                  style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
                  decoration: appInputDecoration('Search contacts', Icons.search_rounded).copyWith(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    suffixIcon: _query.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Clear',
                            icon: const Icon(Icons.close_rounded, color: AppColors.textMuted, size: 18),
                            onPressed: _clearSearch,
                          ),
                  ),
                ),
              ),
              Expanded(
                child: FutureBuilder<List<ContactEntry>>(
                  future: _contactsFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const _ContactListSkeleton();
                    }

                    final entries = snapshot.data ?? const <ContactEntry>[];
                    if (entries.isEmpty) {
                      return _ContactsPanel(
                        icon: ContactDirectory.permissionDenied ? Icons.no_accounts_outlined : Icons.contacts_outlined,
                        title: ContactDirectory.permissionDenied ? 'Contact access is off' : 'No contacts found',
                        message: ContactDirectory.permissionDenied
                            ? 'Allow contact access in your device settings to pick a payee by name.'
                            : 'Add contacts to your device to pay them by name or number.',
                        actionLabel: ContactDirectory.permissionDenied ? 'Try again' : null,
                        onAction: ContactDirectory.permissionDenied ? _retry : null,
                      );
                    }

                    final filtered = _filter(entries);
                    if (filtered.isEmpty) {
                      return _ContactsPanel(
                        icon: Icons.search_off_rounded,
                        title: 'No matches',
                        message: 'No contacts match “${_query.trim()}”. Try a different name or number.',
                      );
                    }

                    return ListView.separated(
                      padding: const EdgeInsets.fromLTRB(14, 8, 14, 18),
                      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                      itemCount: filtered.length + 1,
                      separatorBuilder: (_, index) => const SizedBox(height: 2),
                      itemBuilder: (context, index) {
                        if (index == 0) {
                          return Padding(
                            padding: const EdgeInsets.fromLTRB(8, 4, 8, 10),
                            child: Row(
                              children: [
                                Text(
                                  '${filtered.length} ${filtered.length == 1 ? 'contact' : 'contacts'}',
                                  style: const TextStyle(
                                    color: AppColors.textMuted,
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.6,
                                  ),
                                ),
                                const Spacer(),
                                const Icon(Icons.sort_rounded, color: AppColors.textMuted, size: 13),
                                const SizedBox(width: 4),
                                const Text(
                                  'A–Z',
                                  style: TextStyle(
                                    color: AppColors.textMuted,
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }

                        final entry = filtered[index - 1];
                        return Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => Navigator.of(context).pop(entry.digits),
                            borderRadius: BorderRadius.circular(14),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
                              child: Row(
                                children: [
                                  PaymentAvatar(label: entry.name, size: 42),
                                  const SizedBox(width: 13),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          entry.name,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: AppColors.textPrimary,
                                            fontSize: 13.5,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          entry.digits,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(color: AppColors.textMuted, fontSize: 11.5),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  const Icon(Icons.arrow_outward_rounded, color: AppColors.textMuted, size: 15),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ContactListSkeleton extends StatelessWidget {
  const _ContactListSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(22, 16, 22, 18),
      itemCount: 7,
      itemBuilder: (context, index) => Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: const BoxDecoration(color: AppColors.border, shape: BoxShape.circle),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: 0.55,
                    child: Container(
                      height: 11,
                      decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(6)),
                    ),
                  ),
                  const SizedBox(height: 7),
                  FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: 0.3,
                    child: Container(
                      height: 9,
                      decoration: BoxDecoration(
                        color: AppColors.border.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ContactsPanel extends StatelessWidget {
  const _ContactsPanel({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            PaymentIconBadge(icon: icon, size: 62, radius: 20, color: AppColors.textMuted),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 15.5, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 7),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textMuted, fontSize: 12.5, height: 1.5),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 18),
              SizedBox(
                width: 158,
                child: NeonButton(label: actionLabel!, icon: Icons.refresh_rounded, onPressed: onAction, height: 46),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
