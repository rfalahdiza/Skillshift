import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/session_controller.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/app_button.dart';
import '../../shared/widgets/form_fields.dart';
import '../../shared/widgets/page_scaffold.dart';
import '../../shared/widgets/surfaces.dart';

/// L04 Check your inbox: 6-digit code. On success the router moves on.
class VerifyCodeScreen extends ConsumerStatefulWidget {
  const VerifyCodeScreen({super.key, required this.email});

  final String email;

  @override
  ConsumerState<VerifyCodeScreen> createState() => _VerifyCodeScreenState();
}

class _VerifyCodeScreenState extends ConsumerState<VerifyCodeScreen> {
  static const _resendAfter = 60;

  String _code = '';
  bool _verifying = false;
  String? _error;
  String? _info;
  int _secondsLeft = _resendAfter;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    setState(() => _secondsLeft = _resendAfter);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_secondsLeft <= 1) t.cancel();
      if (mounted) setState(() => _secondsLeft--);
    });
  }

  Future<void> _verify() async {
    if (_code.length != 6 || _verifying) return;
    setState(() {
      _verifying = true;
      _error = null;
    });
    try {
      await ref.read(sessionProvider.notifier).verifyCode(widget.email, _code);
    } on SignInException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }

  Future<void> _resend() async {
    setState(() {
      _error = null;
      _info = null;
    });
    try {
      await ref.read(sessionProvider.notifier).sendCode(widget.email);
      _startTimer();
      setState(() => _info = 'New code sent to ${widget.email}.');
    } on SignInException catch (e) {
      setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final m = (_secondsLeft ~/ 60).toString();
    final s = (_secondsLeft % 60).toString().padLeft(2, '0');
    return PageScaffold(
      header: const PageHeader(title: ''),
      body: [
        Text('Check your inbox', style: AppText.h1),
        const SizedBox(height: Space.sm),
        Text(
          'Enter the 6-digit code we sent to\n${widget.email}',
          style: AppText.body.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: Space.xxl),
        OtpField(
          onChanged: (v) => setState(() => _code = v),
          onCompleted: (_) => _verify(),
        ),
        const SizedBox(height: Space.xl),
        Row(
          children: [
            Text(
              'Didn’t get it? ',
              style: AppText.small.copyWith(color: AppColors.textSecondary),
            ),
            if (_secondsLeft > 0)
              Text(
                'Resend in $m:$s',
                style: AppText.smallSemibold.copyWith(
                  color: AppColors.textTertiary,
                ),
              )
            else
              InkWell(
                onTap: _resend,
                child: Text(
                  'Resend code',
                  style: AppText.smallSemibold.copyWith(
                    color: AppColors.primaryPressed,
                  ),
                ),
              ),
          ],
        ),
        if (_error != null) ...[
          const SizedBox(height: Space.lg),
          InfoBanner(tone: BannerTone.danger, text: _error!),
        ],
        if (_info != null) ...[
          const SizedBox(height: Space.lg),
          InfoBanner(tone: BannerTone.info, text: _info!),
        ],
      ],
      bottom: BottomActionBar(
        children: [
          AppButton(
            label: 'Verify',
            loading: _verifying,
            onPressed: _code.length == 6 ? _verify : null,
          ),
        ],
      ),
    );
  }
}
