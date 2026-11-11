import 'package:flutter/material.dart';

import 'package:_50cents/core/theme/app_colors.dart';
import 'package:_50cents/core/theme/app_inputs.dart';
import 'package:_50cents/features/payments/data/contact_directory.dart';

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
    // Keep the sheet fully on screen while the keyboard is open.
    final sheetHeight = (media.size.height - bottomInset) * 0.9;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        height: sheetHeight,
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  margin: const EdgeInsets.only(top: 12, bottom: 18),
                  decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(4)),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 22),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppColors.neonBlue.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(13),
                        border: Border.all(color: AppColors.neonBlue.withValues(alpha: 0.3)),
                      ),
                      child: const Icon(Icons.contacts_rounded, color: AppColors.neonBlue, size: 21),
                    ),
                    const SizedBox(width: 13),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Choose a contact',
                            style: TextStyle(color: AppColors.textPrimary, fontSize: 17, fontWeight: FontWeight.w700),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Search by name or phone number',
                            style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 16, 22, 4),
                child: TextField(
                  controller: _searchController,
                  autofocus: true,
                  onChanged: (value) => setState(() => _query = value),
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: appInputDecoration('Search contacts', Icons.search_rounded).copyWith(
                    suffixIcon: _query.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Clear',
                            icon: const Icon(Icons.close_rounded, color: AppColors.textMuted, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _query = '');
                            },
                          ),
                  ),
                ),
              ),
              Expanded(
                child: FutureBuilder<List<ContactEntry>>(
                  future: _contactsFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator(color: AppColors.neonBlue, strokeWidth: 2));
                    }

                    final entries = snapshot.data ?? const <ContactEntry>[];
                    if (entries.isEmpty) {
                      return _EmptyContacts(denied: ContactDirectory.permissionDenied, onRetry: _retry);
                    }

                    final filtered = _filter(entries);
                    if (filtered.isEmpty) {
                      return const _NoMatches();
                    }

                    return ListView.separated(
                      padding: const EdgeInsets.fromLTRB(14, 6, 14, 18),
                      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                      itemCount: filtered.length,
                      separatorBuilder: (_, _) =>
                          const Divider(height: 1, color: AppColors.border, indent: 62, endIndent: 14),
                      itemBuilder: (context, index) {
                        final entry = filtered[index];
                        return ListTile(
                          onTap: () => Navigator.of(context).pop(entry.digits),
                          leading: _ContactAvatar(name: entry.name),
                          title: Text(
                            entry.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          subtitle: Text(
                            entry.digits,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                          ),
                          trailing: const Icon(Icons.arrow_forward_ios_rounded, color: AppColors.textMuted, size: 12),
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

class _ContactAvatar extends StatelessWidget {
  const _ContactAvatar({required this.name});

  final String name;

  String get _initials {
    final parts = name.trim().split(RegExp(r'\s+')).where((part) => part.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    String first(String value) => value.substring(0, 1).toUpperCase();
    if (parts.length == 1) return first(parts.first);
    return '${first(parts.first)}${first(parts[1])}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.neonBlue.withValues(alpha: 0.12),
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.neonBlue.withValues(alpha: 0.25)),
      ),
      child: Text(
        _initials,
        style: const TextStyle(color: AppColors.neonBlue, fontSize: 13, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _EmptyContacts extends StatelessWidget {
  const _EmptyContacts({required this.denied, required this.onRetry});

  final bool denied;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(denied ? Icons.no_accounts_outlined : Icons.contacts_outlined, color: AppColors.textMuted, size: 42),
            const SizedBox(height: 14),
            Text(
              denied ? 'Contact access is off' : 'No contacts found',
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 15, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              denied
                  ? 'Allow contact access in your device settings to pick a payee by name.'
                  : 'Add contacts to your device to pay them by name or number.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textMuted, fontSize: 12.5, height: 1.45),
            ),
            if (denied) ...[
              const SizedBox(height: 14),
              TextButton(
                onPressed: onRetry,
                style: TextButton.styleFrom(foregroundColor: AppColors.neonBlue),
                child: const Text('Try again'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _NoMatches extends StatelessWidget {
  const _NoMatches();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off_rounded, color: AppColors.textMuted, size: 40),
            SizedBox(height: 12),
            Text('No contacts match your search', style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
          ],
        ),
      ),
    );
  }
}
