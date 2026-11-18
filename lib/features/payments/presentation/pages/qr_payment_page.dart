import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gal/gal.dart';
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
import 'package:_50cents/features/payments/presentation/widgets/qr_share_image.dart';

/// The API accepts a UPI ID (`name@bank`) or an Indian mobile number, with an
/// optional `+91` prefix. Mirrors the backend `upiId` validation pattern.
final RegExp _paymentIdPattern = RegExp(r'^(?:[a-zA-Z0-9._-]+@[a-zA-Z]+|(?:\+?91)?[6-9]\d{9})$');

String _normalizePaymentId(String value) => value.trim().replaceAll(RegExp(r'[\s-]+'), '');

String? _validatePaymentId(String? value) {
  final normalized = _normalizePaymentId(value ?? '');
  if (normalized.isEmpty) return 'Enter your UPI ID or mobile number';
  if (!_paymentIdPattern.hasMatch(normalized)) {
    return 'Use a UPI ID like name@bank or a 10-digit mobile number';
  }
  return null;
}

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
  bool _saving = false;
  String? _error;
  _PaymentRequest? _request;

  final TextEditingController _upiController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _upiController.dispose();
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
        _upiController.text = user.paymentId;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = userErrorMessage(e);
        _loading = false;
      });
    }
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message, style: const TextStyle(color: AppColors.textPrimary, fontSize: 13)),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.surface,
          margin: const EdgeInsets.fromLTRB(20, 0, 20, 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: AppColors.border),
          ),
        ),
      );
  }

  /// First-time setup: saves the payment ID and switches to the QR view.
  Future<void> _savePaymentId() async {
    final value = _normalizePaymentId(_upiController.text);
    final validation = _validatePaymentId(value);
    if (validation != null) {
      setState(() => _error = validation);
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final updated = await ref.read(userRepositoryProvider).updateUpi(upiId: value);
      if (!mounted) return;
      setState(() {
        _user = updated;
        _saving = false;
        _upiController.text = updated.paymentId;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = userErrorMessage(e);
      });
    }
  }

  Future<void> _showEditPaymentId() async {
    final user = _user;
    if (user == null) return;
    final updated = await showModalBottomSheet<User>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      // Lift the sheet by the keyboard height so the focused field stays visible.
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(sheetContext).bottom),
        child: _EditPaymentIdSheet(initialValue: user.paymentId),
      ),
    );
    if (updated == null || !mounted) return;
    setState(() {
      _user = updated;
      // The previous request was built for the old payee ID.
      _request = null;
      _upiController.text = updated.paymentId;
    });
    _toast('Payment ID updated');
  }

  bool get _hasPaymentId {
    final user = _user;
    return user != null && (user.upi != null || user.mobile != null);
  }

  String get _qrData {
    final user = _user!;
    return generateUpiUri(pa: user.paymentId, pn: user.displayName);
  }

  Future<void> _showAmountSheet() async {
    final user = _user!;
    final draft = await showModalBottomSheet<_RequestDraft>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(sheetContext).bottom),
        child: _AmountSheet(payee: user.paymentId),
      ),
    );
    if (draft == null || !mounted) return;
    final link = generatePaymentRedirectUrl(pa: draft.pa, pn: user.displayName, am: draft.amount, tn: draft.note);
    setState(() {
      _request = _PaymentRequest(pa: draft.pa, pn: user.displayName, am: draft.amount, tn: draft.note, link: link);
    });
    _toast('Payment request created');
  }

  Future<void> _copyLink(String url) async {
    await Clipboard.setData(ClipboardData(text: url));
    _toast('Payment link copied');
  }

  Future<void> _copyUpi(String upi) async {
    await Clipboard.setData(ClipboardData(text: upi));
    _toast('UPI ID copied');
  }

  Future<void> _shareLink(String url, {String? amount}) async {
    await SharePlus.instance.share(
      ShareParams(
        text: amount == null || amount.isEmpty
            ? 'Pay me via UPI on 50cents: $url'
            : 'Pay ₹$amount via UPI on 50cents: $url',
        subject: 'Pay me via 50cents',
      ),
    );
  }

  void _showRequestQr(_PaymentRequest request) {
    showDialog<void>(
      context: context,
      builder: (_) => _RequestQrDialog(request: request),
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
            : _error != null && _user == null
            ? _ErrorState(message: _error!, onRetry: _load)
            : _user == null
            ? const Center(child: Text('Unable to load your profile.'))
            : !_hasPaymentId
            ? _setupView()
            : _qrView(),
      ),
    );
  }

  Widget _setupView() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      children: [
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.neonBlue.withValues(alpha: 0.14), AppColors.surface, AppColors.surface],
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.neonBlue.withValues(alpha: 0.2)),
            boxShadow: [BoxShadow(color: AppColors.neonBlue.withValues(alpha: 0.08), blurRadius: 30, spreadRadius: 1)],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.neonBlue.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.neonBlue.withValues(alpha: 0.24)),
                    ),
                    child: const Icon(Icons.account_balance_wallet_rounded, color: AppColors.neonBlue, size: 26),
                  ),
                  const SizedBox(width: 14),
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
                          'Add a UPI ID or mobile number to receive payments.',
                          style: TextStyle(color: AppColors.textMuted, fontSize: 12.5, height: 1.4),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              TextFormField(
                controller: _upiController,
                textInputAction: TextInputAction.done,
                decoration: appInputDecoration(
                  'UPI ID or mobile number',
                  Icons.alternate_email_rounded,
                  hint: 'e.g. name@okhdfcbank or 9876543210',
                ),
                onFieldSubmitted: (_) => _savePaymentId(),
              ),
              if (_error != null) ...[const SizedBox(height: 12), _InlineError(message: _error!)],
              const SizedBox(height: 20),
              NeonButton(
                label: _saving ? 'Saving...' : 'Save & show my QR',
                icon: Icons.qr_code_2_rounded,
                loading: _saving,
                onPressed: _saving ? null : _savePaymentId,
              ),
              const SizedBox(height: 14),
              const Text(
                'Your UPI PIN and bank details are never accessed by 50cents.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textMuted, fontSize: 11.5, height: 1.4),
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
    final paymentLink = generatePlainPaymentLink(pa: user.paymentId);
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 32),
      children: [
        _MainQrCard(
          user: user,
          data: _qrData,
          onCopy: () => _copyUpi(user.paymentId),
          onShareLink: () => _shareLink(paymentLink),
          onCopyLink: () => _copyLink(paymentLink),
        ),
        const SizedBox(height: 18),
        NeonButton(label: 'Request amount', icon: Icons.request_quote_rounded, onPressed: _showAmountSheet),
        const SizedBox(height: 8),
        const Text(
          'Create an amount-specific QR or payment link to share.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.textMuted, fontSize: 12.5),
        ),
        if (request != null) ...[
          const SizedBox(height: 16),
          _RequestCard(
            request: request,
            onCopy: () => _copyLink(request.link),
            onShare: () => _shareLink(request.link, amount: request.am),
            onShowQr: () => _showRequestQr(request),
          ),
        ],
        const SizedBox(height: 14),
        _PaymentIdTile(value: user.paymentId, label: user.paymentLabel, onTap: _showEditPaymentId),
      ],
    );
  }
}

/// Gradient card with the user's personal QR and share/save actions.
class _MainQrCard extends StatelessWidget {
  const _MainQrCard({
    required this.user,
    required this.data,
    required this.onCopy,
    required this.onShareLink,
    required this.onCopyLink,
  });

  final User user;
  final String data;
  final VoidCallback onCopy;
  final VoidCallback onShareLink;
  final VoidCallback onCopyLink;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.neonBlue.withValues(alpha: 0.13), AppColors.surface, AppColors.surface],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.neonBlue.withValues(alpha: 0.2)),
        boxShadow: [BoxShadow(color: AppColors.neonBlue.withValues(alpha: 0.08), blurRadius: 28, spreadRadius: 1)],
      ),
      child: Column(
        children: [
          Row(
            children: [
              const AppLogo(size: 38, radius: 12),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'My payment QR',
                      style: TextStyle(color: AppColors.textPrimary, fontSize: 17, fontWeight: FontWeight.w700),
                    ),
                    SizedBox(height: 2),
                    Text('Scan with any UPI app', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.neonBlue.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.neonBlue.withValues(alpha: 0.26)),
                ),
                child: Text(
                  user.paymentLabel,
                  style: const TextStyle(
                    color: AppColors.neonBlue,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _QrPanel(data: data, size: 238),
          const SizedBox(height: 18),
          Text(
            user.displayName,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 19,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 6),
          InkWell(
            onTap: onCopy,
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      user.paymentId,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.neonBlueBright,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                  const SizedBox(width: 7),
                  const Icon(Icons.copy_all_rounded, color: AppColors.neonBlue, size: 16),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          _QrImageActions(data: data, payeeName: user.displayName, paymentId: user.paymentId, label: 'Share QR'),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _OutlinedAction(label: 'Share link', icon: Icons.ios_share_rounded, onTap: onShareLink),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _OutlinedAction(label: 'Copy link', icon: Icons.link_rounded, onTap: onCopyLink),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// White QR panel with the small app mark in the middle.
class _QrPanel extends StatelessWidget {
  const _QrPanel({required this.data, this.size = 238});

  final String data;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size + 28,
      height: size + 28,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.neonBlue.withValues(alpha: 0.35)),
        boxShadow: [
          BoxShadow(
            color: AppColors.neonBlue.withValues(alpha: 0.28),
            blurRadius: 26,
            spreadRadius: 1,
            offset: const Offset(0, 8),
          ),
          BoxShadow(color: Colors.black.withValues(alpha: 0.35), blurRadius: 18, offset: const Offset(0, 10)),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          QrImageView(
            data: data,
            version: QrVersions.auto,
            size: size,
            padding: EdgeInsets.zero,
            gapless: true,
            errorCorrectionLevel: QrErrorCorrectLevel.H,
            backgroundColor: Colors.white,
            eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: Color(0xFF0A1420)),
            dataModuleStyle: const QrDataModuleStyle(
              dataModuleShape: QrDataModuleShape.square,
              color: Color(0xFF0A1420),
            ),
          ),
          _QrLogo(size: size * 0.155),
        ],
      ),
    );
  }
}

class _QrLogo extends StatelessWidget {
  const _QrLogo({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(size * 0.14),
      decoration: const BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: Color(0x33000000), blurRadius: 8)],
      ),
      child: ClipOval(
        child: Image.asset('assets/icon/app_icon_v1.png', fit: BoxFit.cover, filterQuality: FilterQuality.high),
      ),
    );
  }
}

/// Share + save buttons for a QR image. Used by the main card, the request
/// card and the request QR dialog.
class _QrImageActions extends StatefulWidget {
  const _QrImageActions({
    required this.data,
    required this.payeeName,
    required this.paymentId,
    this.amount,
    this.note,
    this.label = 'Share QR',
  });

  final String data;
  final String payeeName;
  final String paymentId;
  final String? amount;
  final String? note;
  final String label;

  @override
  State<_QrImageActions> createState() => _QrImageActionsState();
}

class _QrImageActionsState extends State<_QrImageActions> {
  bool _busy = false;

  String get _amount => widget.amount?.trim() ?? '';

  String get _fileName {
    final stamp = DateTime.now().millisecondsSinceEpoch;
    return _amount.isEmpty ? '50cents-qr-$stamp' : '50cents-request-${_amount.replaceAll('.', '-')}-$stamp';
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message, style: const TextStyle(color: AppColors.textPrimary, fontSize: 13)),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.surface,
          margin: const EdgeInsets.fromLTRB(20, 0, 20, 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: AppColors.border),
          ),
        ),
      );
  }

  Future<Uint8List> _render() {
    return QrShareImage.build(
      data: widget.data,
      payeeName: widget.payeeName,
      paymentId: widget.paymentId,
      amount: _amount.isEmpty ? null : _amount,
      note: widget.note,
    );
  }

  String get _shareText => _amount.isEmpty
      ? 'Scan my 50cents QR to pay ${widget.payeeName} (${widget.paymentId}) on UPI.'
      : 'Pay ₹$_amount to ${widget.payeeName} (${widget.paymentId}) on UPI. Scan the attached QR in any UPI app.';

  Future<void> _share() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final bytes = await _render();
      if (!mounted) return;
      final box = context.findRenderObject() as RenderBox?;
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile.fromData(bytes, mimeType: 'image/png', name: '$_fileName.png')],
          text: _shareText,
          subject: 'Payment QR from 50cents',
          sharePositionOrigin: box == null ? null : box.localToGlobal(Offset.zero) & box.size,
        ),
      );
    } catch (_) {
      _toast('Could not share the QR image. Please try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final bytes = await _render();
      await Gal.putImageBytes(bytes, name: _fileName);
      _toast('QR saved to your gallery');
    } on GalException catch (error) {
      _toast(
        error.type == GalExceptionType.permissionDenied
            ? 'Allow photo access to save the QR to your gallery.'
            : 'Could not save the QR. Please try again.',
      );
    } catch (_) {
      _toast('Could not save the QR. Please try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Longer labels (e.g. "Share request QR") need more room than "Save QR"
    // on narrow phones, otherwise the button content overflows.
    final hasLongLabel = widget.label.length > 12;
    return Row(
      children: [
        Expanded(
          flex: hasLongLabel ? 3 : 1,
          child: NeonButton(
            label: widget.label,
            icon: Icons.ios_share_rounded,
            height: 46,
            fontSize: hasLongLabel ? 13 : 16,
            loading: _busy,
            onPressed: _busy ? null : _share,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          flex: hasLongLabel ? 2 : 1,
          child: _OutlinedAction(
            label: 'Save QR',
            icon: Icons.download_rounded,
            height: 46,
            onTap: _busy ? null : _save,
          ),
        ),
      ],
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
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.neonBlue.withValues(alpha: 0.10), AppColors.surface, AppColors.surface],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.neonBlue.withValues(alpha: 0.24)),
        boxShadow: [
          BoxShadow(color: AppColors.neonBlue.withValues(alpha: 0.07), blurRadius: 18, offset: const Offset(0, 6)),
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
                child: const Icon(Icons.send_rounded, color: AppColors.neonBlue, size: 18),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Payment request',
                  style: TextStyle(color: AppColors.textPrimary, fontSize: 15, fontWeight: FontWeight.w700),
                ),
              ),
              if (request.am.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.neonBlue.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.neonBlue.withValues(alpha: 0.25)),
                  ),
                  child: Text(
                    '₹${request.am}',
                    style: const TextStyle(color: AppColors.neonBlue, fontSize: 13.5, fontWeight: FontWeight.w800),
                  ),
                ),
            ],
          ),
          if (request.tn.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(request.tn, style: const TextStyle(color: AppColors.textMuted, fontSize: 13, height: 1.35)),
          ],
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
            decoration: BoxDecoration(
              color: AppColors.background.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Expanded(
                  child: SelectableText(
                    request.link,
                    maxLines: 2,
                    style: const TextStyle(
                      color: AppColors.neonBlueBright,
                      fontSize: 12,
                      fontFamily: 'monospace',
                      height: 1.4,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                IconButton(
                  tooltip: 'Copy link',
                  visualDensity: VisualDensity.compact,
                  onPressed: onCopy,
                  icon: const Icon(Icons.copy_all_rounded, color: AppColors.neonBlue, size: 18),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _OutlinedAction(label: 'Share link', icon: Icons.share_rounded, onTap: onShare),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _OutlinedAction(label: 'View QR', icon: Icons.qr_code_2_rounded, onTap: onShowQr),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _QrImageActions(
            data: request.qrData,
            payeeName: request.pn,
            paymentId: request.pa,
            amount: request.am,
            note: request.tn,
            label: 'Share request QR',
          ),
        ],
      ),
    );
  }
}

class _RequestQrDialog extends StatelessWidget {
  const _RequestQrDialog({required this.request});

  final _PaymentRequest request;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: AppColors.border),
            boxShadow: [BoxShadow(color: AppColors.neonBlue.withValues(alpha: 0.10), blurRadius: 32)],
          ),
          child: SingleChildScrollView(
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
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded, color: AppColors.textMuted),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                _QrPanel(data: request.qrData, size: 210),
                const SizedBox(height: 16),
                if (request.am.isNotEmpty)
                  Text(
                    '₹${request.am}',
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.4,
                    ),
                  ),
                if (request.tn.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    request.tn,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: AppColors.textMuted, fontSize: 13, height: 1.35),
                  ),
                ],
                const SizedBox(height: 6),
                Text(
                  'To ${request.pn} · ${request.pa}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 11.5),
                ),
                const SizedBox(height: 18),
                _QrImageActions(
                  data: request.qrData,
                  payeeName: request.pn,
                  paymentId: request.pa,
                  amount: request.am,
                  note: request.tn,
                  label: 'Share QR',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PaymentIdTile extends StatelessWidget {
  const _PaymentIdTile({required this.value, required this.label, required this.onTap});

  final String value;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: AppColors.neonBlue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.account_balance_wallet_rounded, color: AppColors.neonBlue, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Payment ID · $label',
                      style: const TextStyle(color: AppColors.textMuted, fontSize: 11.5, letterSpacing: 0.2),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: AppColors.textPrimary, fontSize: 14.5, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.edit_outlined, color: AppColors.neonBlue, size: 19),
            ],
          ),
        ),
      ),
    );
  }
}

class _EditPaymentIdSheet extends ConsumerStatefulWidget {
  const _EditPaymentIdSheet({required this.initialValue});

  final String initialValue;

  @override
  ConsumerState<_EditPaymentIdSheet> createState() => _EditPaymentIdSheetState();
}

class _EditPaymentIdSheetState extends ConsumerState<_EditPaymentIdSheet> {
  late final TextEditingController _controller = TextEditingController(text: widget.initialValue);
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final value = _normalizePaymentId(_controller.text);
    FocusScope.of(context).unfocus();
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final updated = await ref.read(userRepositoryProvider).updateUpi(upiId: value);
      if (!mounted) return;
      Navigator.of(context).pop(updated);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = userErrorMessage(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(20, 10, 20, 20 + MediaQuery.paddingOf(context).bottom),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.neonBlue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.edit_rounded, color: AppColors.neonBlue, size: 20),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Update payment ID',
                          style: TextStyle(color: AppColors.textPrimary, fontSize: 17, fontWeight: FontWeight.w700),
                        ),
                        SizedBox(height: 2),
                        Text('Your QR updates instantly.', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _controller,
                autofocus: true,
                textInputAction: TextInputAction.done,
                decoration: appInputDecoration(
                  'UPI ID or mobile number',
                  Icons.alternate_email_rounded,
                  hint: 'e.g. name@okhdfcbank or 9876543210',
                ),
                validator: _validatePaymentId,
                onFieldSubmitted: (_) => _save(),
              ),
              if (_error != null) ...[const SizedBox(height: 12), _InlineError(message: _error!)],
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: _OutlinedAction(
                      label: 'Cancel',
                      icon: Icons.close_rounded,
                      onTap: _saving ? null : () => Navigator.of(context).pop(),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: NeonButton(
                      label: _saving ? 'Saving...' : 'Save',
                      icon: Icons.check_rounded,
                      height: 46,
                      loading: _saving,
                      onPressed: _saving ? null : _save,
                    ),
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

class _OutlinedAction extends StatelessWidget {
  const _OutlinedAction({required this.label, required this.icon, this.onTap, this.height = 44});

  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  final double height;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 17),
      label: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
      ),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.neonBlue,
        side: BorderSide(color: AppColors.neonBlue.withValues(alpha: 0.45)),
        minimumSize: Size(double.infinity, height),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

class _InlineError extends StatelessWidget {
  const _InlineError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.expense.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.expense.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline_rounded, color: AppColors.expense, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message, style: const TextStyle(color: AppColors.expense, fontSize: 12, height: 1.35)),
          ),
        ],
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
      child: Padding(
        padding: const EdgeInsets.all(24),
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
      ),
    );
  }
}

class _RequestDraft {
  const _RequestDraft({required this.pa, required this.amount, required this.note});

  final String pa;
  final String amount;
  final String note;
}

/// Bottom sheet used to request an amount. The amount is required; the note
/// is optional.
class _AmountSheet extends StatefulWidget {
  const _AmountSheet({required this.payee});

  final String payee;

  @override
  State<_AmountSheet> createState() => _AmountSheetState();
}

class _AmountSheetState extends State<_AmountSheet> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  String? _validateAmount(String? value) {
    final text = (value ?? '').trim();
    if (text.isEmpty) return 'Amount is required';
    final amount = double.tryParse(text);
    if (amount == null || amount <= 0) return 'Enter an amount greater than zero';
    return null;
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();
    Navigator.of(context).pop(
      _RequestDraft(
        pa: _normalizePaymentId(widget.payee),
        amount: _amountController.text.trim(),
        note: _noteController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(11),
                      decoration: BoxDecoration(
                        color: AppColors.neonBlue.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.request_quote_rounded, color: AppColors.neonBlue, size: 22),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Request amount',
                            style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w700),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Amount is required · note is optional',
                            style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.background.withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.person_rounded, color: AppColors.textMuted, size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          widget.payee,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: AppColors.textPrimary, fontSize: 13.5),
                        ),
                      ),
                      const Text(
                        'You',
                        style: TextStyle(color: AppColors.neonBlue, fontSize: 11, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _amountController,
                  autofocus: true,
                  textInputAction: TextInputAction.next,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}'))],
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                  decoration: appInputDecoration('Amount', Icons.currency_rupee_rounded, hint: 'Required'),
                  validator: _validateAmount,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _noteController,
                  textInputAction: TextInputAction.done,
                  maxLength: 50,
                  decoration: appInputDecoration('Note', Icons.notes_rounded, hint: 'Optional'),
                  onFieldSubmitted: (_) => _submit(),
                ),
                const SizedBox(height: 10),
                NeonButton(label: 'Generate QR & link', icon: Icons.auto_awesome_rounded, onPressed: _submit),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
