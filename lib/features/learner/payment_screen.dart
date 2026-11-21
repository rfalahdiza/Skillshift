import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../core/router/routes.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../data/models.dart';
import '../../data/providers.dart';
import '../../shared/widgets/app_button.dart';
import '../../shared/widgets/badges.dart';
import '../../shared/widgets/page_scaffold.dart';
import '../../shared/widgets/state_views.dart';
import '../../shared/widgets/surfaces.dart';
import 'checkout_screen.dart';

/// Midtrans sandbox simulators (to "pay" a test transaction).
const _qrisSimulator = 'https://simulator.sandbox.midtrans.com/v2/qris/index';
const _vaSimulator = 'https://simulator.sandbox.midtrans.com/openapi/va/index';

/// L13 Complete payment: Midtrans Snap SANDBOX page in a WebView (Android)
/// or a browser tab (web/desktop), plus "Check payment status".
class PaymentScreen extends ConsumerStatefulWidget {
  const PaymentScreen({super.key, required this.bookingId, this.args});

  final String bookingId;
  final PaymentArgs? args;

  @override
  ConsumerState<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends ConsumerState<PaymentScreen> {
  Timer? _ticker;
  Timer? _poller;
  bool _checking = false;
  String? _error;
  WebViewController? _web;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _poller?.cancel();
    super.dispose();
  }

  bool _isPreview(String url) => url == 'about:blank';

  /// Real payments: check quietly every 8 s while this screen is open.
  void _startPolling() {
    _poller ??= Timer.periodic(
      const Duration(seconds: 8),
      (_) => _check(quiet: true),
    );
  }

  WebViewController _controllerFor(String url) => _web ??= WebViewController()
    ..setJavaScriptMode(JavaScriptMode.unrestricted)
    ..loadRequest(Uri.parse(url));

  Future<void> _check({bool quiet = false}) async {
    if (_checking) return;
    setState(() {
      _checking = true;
      if (!quiet) _error = null;
    });
    final router = GoRouter.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final s = await ref
          .read(repositoryProvider)
          .checkPayment(widget.bookingId);
      ref.invalidate(bookingsProvider);
      if (s.isPaid) {
        _poller?.cancel();
        router.pushReplacement(Routes.learnerBooked(widget.bookingId));
      } else if (s.isDead) {
        _poller?.cancel();
        setState(
          () => _error = s.paymentStatus == 'expired'
              ? 'This payment expired and the booking was released. '
                    'Book again to pick a new time.'
              : 'The payment did not go through. Book again to try another '
                    'method.',
        );
      } else if (!quiet) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text(
              'We have not received the payment yet. It can take a minute.',
            ),
          ),
        );
      }
    } catch (e) {
      if (!quiet && mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final args = widget.args;
    if (args != null) {
      return _build(
        url: args.start.redirectUrl,
        gross: args.start.gross,
        expiresAt: args.start.expiresAt,
        method: args.method,
      );
    }
    // Opened from Sessions: load the stored payment.
    final detail = ref.watch(sessionDetailProvider(widget.bookingId));
    return detail.when(
      loading: () => const PageScaffold(body: [LoadingView()]),
      error: (e, _) => PageScaffold(
        header: const PageHeader(title: 'Complete payment'),
        body: [ErrorView(message: e.toString())],
      ),
      data: (d) => _build(
        url: d.payment?.redirectUrl ?? 'about:blank',
        gross: d.payment?.gross ?? 0,
        expiresAt: d.payment?.expiresAt,
        method: null,
      ),
    );
  }

  Widget _build({
    required String url,
    required int gross,
    required DateTime? expiresAt,
    required PaymentMethod? method,
  }) {
    final preview = _isPreview(url);
    if (!preview) _startPolling();
    final left = expiresAt?.difference(DateTime.now());
    final expired = left != null && left.isNegative;
    final mm = left == null || expired
        ? '00'
        : left.inMinutes.toString().padLeft(2, '0');
    final ss = left == null || expired
        ? '00'
        : (left.inSeconds % 60).toString().padLeft(2, '0');
    final useWebView =
        !preview &&
        !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS);

    final top = <Widget>[
      Center(
        child: StatusBadge(
          expired ? 'Payment time is over' : 'Pay within $mm:$ss',
          tone: expired ? BadgeTone.danger : BadgeTone.warning,
          icon: AppIcons.clock,
        ),
      ),
      const SizedBox(height: Space.md),
      Center(
        child: Text(
          'Amount',
          style: AppText.small.copyWith(color: AppColors.textSecondary),
        ),
      ),
      Center(child: Text(formatRupiah(gross), style: AppText.amount)),
      const SizedBox(height: Space.sm),
      const Center(child: StatusBadge.sandbox()),
      const SizedBox(height: Space.lg),
    ];

    final help = <Widget>[
      const SizedBox(height: Space.lg),
      InfoBanner(
        tone: BannerTone.warning,
        text: preview
            ? 'Dev preview: no real payment. "Check payment status" '
                  'simulates a successful sandbox payment.'
            : 'Sandbox: no real money moves. To pay this test transaction, '
                  'use the Midtrans simulator with the QR image link or VA '
                  'number shown on the payment page.',
      ),
      if (!preview) ...[
        const SizedBox(height: Space.sm),
        Wrap(
          spacing: Space.sm,
          children: [
            if (method != PaymentMethod.va)
              AppButton.text(
                label: 'QRIS simulator',
                size: AppButtonSize.small,
                expand: false,
                onPressed: () => launchUrl(Uri.parse(_qrisSimulator)),
              ),
            if (method != PaymentMethod.qris)
              AppButton.text(
                label: 'VA simulator',
                size: AppButtonSize.small,
                expand: false,
                onPressed: () => launchUrl(Uri.parse(_vaSimulator)),
              ),
          ],
        ),
      ],
      if (_error != null) ...[
        const SizedBox(height: Space.md),
        InfoBanner(tone: BannerTone.danger, text: _error!),
      ],
    ];

    final bottom = BottomActionBar(
      children: [
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppButton(
              label: 'Check payment status',
              loading: _checking,
              onPressed: _check,
            ),
            AppButton.text(
              label: 'Pay later',
              onPressed: () => context.go(Routes.learnerSessions),
            ),
          ],
        ),
      ],
    );

    if (useWebView) {
      return Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(
                  Space.pageH,
                  Space.sm,
                  Space.pageH,
                  0,
                ),
                child: PageHeader(title: 'Complete payment'),
              ),
              ...top.map(
                (w) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: Space.pageH),
                  child: w,
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: Space.pageH),
                  child: ClipRRect(
                    borderRadius: Radii.rLg,
                    child: WebViewWidget(controller: _controllerFor(url)),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: Space.pageH),
                child: Column(children: help),
              ),
            ],
          ),
        ),
        bottomNavigationBar: bottom,
      );
    }

    return PageScaffold(
      header: const PageHeader(title: 'Complete payment'),
      body: [
        ...top,
        if (!preview)
          AppCard(
            child: Column(
              children: [
                const Icon(AppIcons.qr, size: 40, color: AppColors.navy),
                const SizedBox(height: Space.md),
                Text(
                  'Open the Midtrans sandbox payment page to see the QR code '
                  'or virtual account number.',
                  textAlign: TextAlign.center,
                  style: AppText.small.copyWith(color: AppColors.textSecondary),
                ),
                const SizedBox(height: Space.lg),
                AppButton(
                  label: 'Open payment page',
                  icon: AppIcons.eye,
                  onPressed: () =>
                      launchUrl(Uri.parse(url), webOnlyWindowName: '_blank'),
                ),
              ],
            ),
          ),
        ...help,
      ],
      bottom: bottom,
    );
  }
}
