import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import 'package:_50cents/core/theme/app_colors.dart';
import 'package:_50cents/core/theme/app_inputs.dart';
import 'package:_50cents/core/utils/payment_link.dart';
import 'package:_50cents/core/widgets/app_logo.dart';
import 'package:_50cents/core/widgets/neon_background.dart';
import 'package:_50cents/core/widgets/neon_button.dart';
import 'package:_50cents/features/auth/data/models/user.dart';
import 'package:_50cents/features/auth/data/user_repository.dart';

class _PaymentRequest {
  const _PaymentRequest({required this.pa, required this.pn, required this.am, required this.tn, required this.link});

  final String pa;
  final String pn;
  final String am;
  final String tn;
  final String link;

  String get qrData => generateUpiUri(pa: pa, pn: pn, am: am, tn: tn);
}

/// Screen that shows the signed-in user's payment QR and lets them request
/// a payment by generating a shareable link and an amount-specific QR.
class QrPaymentPage extends ConsumerStatefulWidget {
  const QrPaymentPage({super.key});

  @override
  ConsumerState<QrPaymentPage> createState() => _QrPaymentPageState();
}

class _QrPaymentPageState extends ConsumerState<QrPaymentPage> {
  User? _user;
  bool _loading = true;
  String? _error;
  bool _linking = false;
  _PaymentRequest? _request;

  final TextEditingController _upiController = TextEditingController();
  final TextEditingController _paController = TextEditingController();
  final TextEditingController _amController = TextEditingController();
  final TextEditingController _tnController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _upiController.dispose();
    _paController.dispose();
    _amController.dispose();
    _tnController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final user = await ref.read(userRepositoryProvider).getUser();
      if (!mounted) return;
      setState(() {
        _user = user;
        _loading = false;
      });
      if (user.mobile != null && user.upi == null) {
        _upiController.text = user.mobile!;
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = userErrorMessage(e);
        _loading = false;
      });
    }
  }

  Future<void> _linkUpi() async {
    final upi = _upiController.text.trim();
    if (upi.isEmpty) {
      setState(() => _error = 'Please enter a UPI ID or mobile number');
      return;
    }
    setState(() {
      _linking = true;
      _error = null;
    });
    try {
      final updated = await ref.read(userRepositoryProvider).updateUpi(upiId: upi);
      if (!mounted) return;
      setState(() {
        _user = updated;
        _linking = false;
        _request = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _linking = false;
        _error = userErrorMessage(e);
      });
    }
  }

  bool get _hasPaymentId {
    final user = _user;
    return user != null && (user.upi != null || user.mobile != null);
  }

  String get _qrData {
    final user = _user!;
    return generateUpiUri(pa: user.paymentId, pn: user.displayName);
  }

  void _showAmountSheet() {
    final user = _user!;
    _paController.text = user.paymentId;
    _amController.clear();
    _tnController.clear();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _AmountSheet(
        paController: _paController,
        amController: _amController,
        tnController: _tnController,
        onCreate: (pa, am, tn) async {
          if (pa.trim().isEmpty) {
            if (sheetContext.mounted) {
              ScaffoldMessenger.of(sheetContext)
                  .showSnackBar(const SnackBar(content: Text('Please enter a payee UPI ID or mobile')));
            }
            return;
          }
          if (!context.mounted) return;
          final link = generatePaymentRedirectUrl(pa: pa.trim(), pn: user.displayName, am: am.trim(), tn: tn.trim());
          if (!context.mounted) return;
          Navigator.of(context).pop();
          setState(() {
            _request = _PaymentRequest(pa: pa.trim(), pn: user.displayName, am: am.trim(), tn: tn.trim(), link: link);
          });
        },
      ),
    );
  }

  Future<void> _copyLink(String url) async {
    await Clipboard.setData(ClipboardData(text: url));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Payment link copied to clipboard')));
  }

  Future<void> _copyUpi(String upi) async {
    await Clipboard.setData(ClipboardData(text: upi));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('UPI ID copied to clipboard')));
  }

  Future<void> _shareLink(String url) async {
    await SharePlus.instance.share(ShareParams(text: url, subject: 'Pay me via 50cents'));
  }

  Future<void> _showEditPaymentId() async {
    final user = _user;
    if (user == null) return;
    final controller = TextEditingController(text: user.upi ?? user.mobile ?? '');
    final formKey = GlobalKey<FormState>();
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.border),
        ),
        title: const Text(
          'Update payment ID',
          style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700),
        ),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            autofocus: true,
            decoration: appInputDecoration('UPI ID or mobile number', Icons.alternate_email_rounded),
            validator: (value) => (value == null || value.trim().isEmpty) ? 'Enter a UPI ID or mobile number' : null,
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              if (formKey.currentState?.validate() ?? false) {
                Navigator.of(dialogContext).pop(controller.text.trim());
              }
            },
            style: FilledButton.styleFrom(backgroundColor: AppColors.neonBlue, foregroundColor: Colors.black),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (result == null || !mounted) return;
    _upiController.text = result;
    await _linkUpi();
  }

  void _showRequestQr(_PaymentRequest request) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: AppColors.border),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Request QR',
                      style: TextStyle(color: AppColors.textPrimary, fontSize: 17, fontWeight: FontWeight.w700),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    icon: const Icon(Icons.close_rounded, color: AppColors.textMuted),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.neonBlue.withValues(alpha: 0.3)),
                ),
                child: QrImageView(
                  data: request.qrData,
                  version: QrVersions.auto,
                  size: 220,
                  gapless: true,
                  backgroundColor: Colors.white,
                  eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: AppColors.neonBlue),
                  dataModuleStyle: const QrDataModuleStyle(
                    dataModuleShape: QrDataModuleShape.square,
                    color: AppColors.neonBlue,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              if (request.am.isNotEmpty)
                Text(
                  '₹${request.am}',
                  style: const TextStyle(color: AppColors.textPrimary, fontSize: 22, fontWeight: FontWeight.w800),
                ),
              if (request.tn.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  request.tn,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
                ),
              ],
              const SizedBox(height: 6),
              Text(
                request.pa,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return NeonBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('My Payment QR'),
          centerTitle: true,
          leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded), onPressed: () => context.pop()),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
            : _error != null && !_loading && _user == null
            ? _ErrorState(message: _error!, onRetry: _load)
            : _user == null
            ? const Center(child: Text('Unable to load your profile.'))
            : !_hasPaymentId
            ? _linkUpiView()
            : _qrView(),
      ),
    );
  }

  Widget _linkUpiView() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.neonBlue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.account_balance_wallet_rounded, color: AppColors.neonBlue, size: 24),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Set up your payment ID',
                          style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w700),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Add your UPI ID or mobile number to show your QR and receive payments.',
                          style: TextStyle(color: AppColors.textMuted, fontSize: 13, height: 1.4),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _upiController,
                decoration: appInputDecoration(
                  'UPI ID or mobile number',
                  Icons.alternate_email_rounded,
                  hint: _user?.mobile != null ? 'e.g. 9876543210' : 'e.g. name@upi',
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: const TextStyle(color: AppColors.expense, fontSize: 12, height: 1.3)),
              ],
              const SizedBox(height: 20),
              NeonButton(
                label: _linking ? 'Saving...' : 'Save & show my QR',
                icon: Icons.qr_code_2_rounded,
                loading: _linking,
                onPressed: _linking ? null : _linkUpi,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _qrView() {
    final user = _user!;
    final request = _request;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 28),
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.neonBlue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.qr_code_2_rounded, color: AppColors.neonBlue, size: 24),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Your payment QR',
                      style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w700),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.neonBlue.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.neonBlue.withValues(alpha: 0.25)),
                    ),
                    child: Text(
                      user.paymentLabel,
                      style: const TextStyle(
                        color: AppColors.neonBlue,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Scan to pay ${user.displayName}',
                style: const TextStyle(color: AppColors.textMuted, fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 22),
              Center(child: _QrFrame(data: _qrData)),
              const SizedBox(height: 16),
              Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: SelectableText(
                        user.paymentId,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: () => _copyUpi(user.paymentId),
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.neonBlue.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.neonBlue.withValues(alpha: 0.22)),
                        ),
                        child: const Icon(Icons.copy_all_rounded, color: AppColors.neonBlue, size: 18),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              const Center(
                child: Text(
                  'Share this QR so friends can pay you anytime',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 12.5, height: 1.4),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        NeonButton(label: 'Request amount', icon: Icons.request_quote_rounded, onPressed: _showAmountSheet),
        const SizedBox(height: 10),
        const Text(
          'Create a payment link or an amount-specific QR to share.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.textMuted, fontSize: 12.5),
        ),
        if (request != null) ...[
          const SizedBox(height: 18),
          _RequestCard(
            request: request,
            onCopy: () => _copyLink(request.link),
            onShare: () => _shareLink(request.link),
            onShowQr: () => _showRequestQr(request),
          ),
        ],
        const SizedBox(height: 14),
        TextButton.icon(
          onPressed: _showEditPaymentId,
          icon: const Icon(Icons.edit_outlined, size: 16),
          label: const Text('Update UPI ID / mobile number'),
          style: TextButton.styleFrom(foregroundColor: AppColors.textMuted),
        ),
      ],
    );
  }
}

class _QrFrame extends StatelessWidget {
  const _QrFrame({required this.data});

  final String data;

  @override
  Widget build(BuildContext context) {
    const size = 250.0;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.neonBlue.withValues(alpha: 0.45),
            blurRadius: 30,
            spreadRadius: 2,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(color: AppColors.neonBlue.withValues(alpha: 0.35)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Stack(
          alignment: Alignment.center,
          children: [
            QrImageView(
              data: data,
              version: QrVersions.auto,
              size: size - 30,
              gapless: true,
              backgroundColor: Colors.white,
              eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: AppColors.neonBlue),
              dataModuleStyle: const QrDataModuleStyle(
                dataModuleShape: QrDataModuleShape.square,
                color: AppColors.neonBlue,
              ),
            ),
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(color: AppColors.neonBlue.withValues(alpha: 0.35), blurRadius: 12, spreadRadius: 1),
                ],
              ),
              child: const AppLogo(size: 24, radius: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _RequestCard extends StatelessWidget {
  const _RequestCard({required this.request, required this.onCopy, required this.onShare, required this.onShowQr});

  final _PaymentRequest request;
  final VoidCallback onCopy;
  final VoidCallback onShare;
  final VoidCallback onShowQr;

  @override
  Widget build(BuildContext context) {
    final hasAmount = request.am.isNotEmpty;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.neonBlue.withValues(alpha: 0.22)),
        boxShadow: [
          BoxShadow(color: AppColors.neonBlue.withValues(alpha: 0.08), blurRadius: 18, offset: const Offset(0, 6)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.neonBlue.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.link_rounded, color: AppColors.neonBlue, size: 18),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Payment request',
                  style: TextStyle(color: AppColors.textPrimary, fontSize: 15, fontWeight: FontWeight.w700),
                ),
              ),
              if (hasAmount)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.neonBlue.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '₹${request.am}',
                    style: const TextStyle(color: AppColors.neonBlue, fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                ),
            ],
          ),
          if (request.tn.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(request.tn, style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
          ],
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.background.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: SelectableText(
              request.link,
              maxLines: 3,
              style: const TextStyle(
                color: AppColors.neonBlueBright,
                fontSize: 12.5,
                fontFamily: 'monospace',
                height: 1.4,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _OutlinedAction(label: 'Copy link', icon: Icons.copy_all_rounded, onTap: onCopy),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _OutlinedAction(label: 'Share', icon: Icons.share_rounded, onTap: onShare),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onShowQr,
              icon: const Icon(Icons.qr_code_2_rounded, size: 18),
              label: const Text('Show QR', style: TextStyle(fontWeight: FontWeight.w700)),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.neonBlue.withValues(alpha: 0.14),
                foregroundColor: AppColors.neonBlue,
                side: BorderSide(color: AppColors.neonBlue.withValues(alpha: 0.3)),
                minimumSize: const Size(double.infinity, 46),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OutlinedAction extends StatelessWidget {
  const _OutlinedAction({required this.label, required this.icon, required this.onTap});

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 17),
      label: Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.neonBlue,
        side: BorderSide(color: AppColors.neonBlue.withValues(alpha: 0.5)),
        minimumSize: const Size(double.infinity, 44),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline_rounded, color: AppColors.expense, size: 48),
          const SizedBox(height: 16),
          Text(
            message,
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 15),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 18),
          NeonButton(label: 'Try again', icon: Icons.refresh_rounded, onPressed: onRetry),
        ],
      ),
    );
  }
}

class _AmountSheet extends StatelessWidget {
  const _AmountSheet({
    required this.paController,
    required this.amController,
    required this.tnController,
    required this.onCreate,
  });

  final TextEditingController paController;
  final TextEditingController amController;
  final TextEditingController tnController;
  final Future<void> Function(String pa, String am, String tn) onCreate;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.72,
      maxChildSize: 0.9,
      minChildSize: 0.5,
      builder: (_, controller) => Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 10),
              width: 40,
              height: 4,
              decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 10),
            const Text(
              'Request amount',
              style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            const Text(
              'Set an amount and note to generate a shareable link and QR.',
              style: TextStyle(color: AppColors.textMuted, fontSize: 13),
            ),
            const SizedBox(height: 18),
            Expanded(
              child: ListView(
                controller: controller,
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                children: [
                  TextFormField(
                    controller: paController,
                    readOnly: true,
                    decoration: appInputDecoration('Payee (UPI ID / mobile)', Icons.person_rounded),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: amController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}'))],
                    decoration: appInputDecoration('Amount (₹)', Icons.currency_rupee_rounded, hint: 'Optional'),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: tnController,
                    decoration: appInputDecoration('Note', Icons.note_rounded, hint: 'Optional'),
                  ),
                  const SizedBox(height: 24),
                  NeonButton(
                    label: 'Generate request',
                    icon: Icons.auto_awesome_rounded,
                    onPressed: () async {
                      await onCreate(paController.text, amController.text, tnController.text);
                    },
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
