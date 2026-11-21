import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_icons.dart';
import '../../core/theme/app_theme.dart';

/// Figma `Form/Text Field`: label above, white field, optional leading icon.
class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    required this.label,
    this.controller,
    this.hint,
    this.icon,
    this.keyboardType,
    this.validator,
    this.onChanged,
    this.maxLines = 1,
    this.textInputAction,
    this.autofillHints,
    this.enabled = true,
  });

  final String label;
  final TextEditingController? controller;
  final String? hint;
  final IconData? icon;
  final TextInputType? keyboardType;
  final FormFieldValidator<String>? validator;
  final ValueChanged<String>? onChanged;
  final int maxLines;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final bool enabled;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: AppText.smallMedium.copyWith(color: AppColors.textSecondary),
      ),
      const SizedBox(height: Space.sm),
      TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        validator: validator,
        onChanged: onChanged,
        maxLines: maxLines,
        enabled: enabled,
        textInputAction: textInputAction,
        autofillHints: autofillHints,
        style: AppText.body,
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: icon == null
              ? null
              : Icon(icon, size: 20, color: AppColors.textTertiary),
        ),
      ),
    ],
  );
}

/// Figma `Form/OTP`: six boxes, teal border on the active one.
class OtpField extends StatefulWidget {
  const OtpField({
    super.key,
    this.length = 6,
    required this.onChanged,
    this.onCompleted,
  });

  final int length;
  final ValueChanged<String> onChanged;
  final ValueChanged<String>? onCompleted;

  @override
  State<OtpField> createState() => _OtpFieldState();
}

class _OtpFieldState extends State<OtpField> {
  final _controller = TextEditingController();
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    setState(() {});
    widget.onChanged(value);
    if (value.length == widget.length) widget.onCompleted?.call(value);
  }

  @override
  Widget build(BuildContext context) {
    final value = _controller.text;
    return Semantics(
      label: '${widget.length}-digit code',
      textField: true,
      child: GestureDetector(
        onTap: () => _focus.requestFocus(),
        child: Stack(
          children: [
            // Hidden field that owns the keyboard, paste and autofill.
            Opacity(
              opacity: 0,
              child: SizedBox(
                height: 1,
                child: TextField(
                  controller: _controller,
                  focusNode: _focus,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  autofillHints: const [AutofillHints.oneTimeCode],
                  maxLength: widget.length,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onChanged: _onChanged,
                  decoration: const InputDecoration(counterText: ''),
                ),
              ),
            ),
            Row(
              children: [
                for (var i = 0; i < widget.length; i++) ...[
                  if (i > 0) const SizedBox(width: Space.sm),
                  Expanded(
                    child: AspectRatio(
                      aspectRatio: 0.88,
                      child: _OtpBox(
                        digit: i < value.length ? value[i] : '',
                        active:
                            _focus.hasFocus &&
                            (i == value.length ||
                                (value.length == widget.length &&
                                    i == widget.length - 1)),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _OtpBox extends StatelessWidget {
  const _OtpBox({required this.digit, required this.active});

  final String digit;
  final bool active;

  @override
  Widget build(BuildContext context) => Container(
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: Radii.rMd,
      border: Border.all(
        color: active ? AppColors.primary : AppColors.border,
        width: active ? 1.5 : 1,
      ),
    ),
    child: Text(digit, style: AppText.h1),
  );
}

/// Radio indicator drawn like the designs (teal ring with white dot).
class RadioDot extends StatelessWidget {
  const RadioDot({super.key, required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) => AnimatedContainer(
    duration: const Duration(milliseconds: 150),
    width: 24,
    height: 24,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: selected ? AppColors.primary : AppColors.surface,
      border: Border.all(
        color: selected ? AppColors.primary : AppColors.borderStrong,
        width: 1.5,
      ),
    ),
    child: selected
        ? Center(
            child: Container(
              width: 9,
              height: 9,
              decoration: const BoxDecoration(
                color: AppColors.surface,
                shape: BoxShape.circle,
              ),
            ),
          )
        : null,
  );
}

/// Figma `Form/Option Card`: icon tile, title, subtitle, radio on the right.
class OptionCard extends StatelessWidget {
  const OptionCard({
    super.key,
    required this.title,
    required this.selected,
    required this.onTap,
    this.subtitle,
    this.icon,
    this.compact = false,
  });

  final String title;
  final String? subtitle;
  final IconData? icon;
  final bool selected;
  final VoidCallback onTap;

  /// Single-line option (quiz answers) with no icon tile.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      inMutuallyExclusiveGroup: true,
      checked: selected,
      button: true,
      child: Material(
        color: selected ? AppColors.primarySoft : AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: Radii.rLg,
          side: BorderSide(
            color: selected ? AppColors.primary : AppColors.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: InkWell(
          borderRadius: Radii.rLg,
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: Space.xl,
              vertical: compact ? 15 : Space.xl,
            ),
            child: Row(
              children: [
                if (icon != null) ...[
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: selected ? AppColors.surface : AppColors.subtle,
                      borderRadius: Radii.rMd,
                    ),
                    child: Icon(
                      icon,
                      size: 22,
                      color: selected
                          ? AppColors.primary
                          : AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(width: Space.lg),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: compact ? AppText.bodyMedium : AppText.h3,
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          subtitle!,
                          style: AppText.small.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: Space.md),
                RadioDot(selected: selected),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Checkbox + text row ("I won't do graded assignments…").
class CheckRow extends StatelessWidget {
  const CheckRow({
    super.key,
    required this.value,
    required this.onChanged,
    required this.label,
  });

  final bool value;
  final ValueChanged<bool> onChanged;
  final String label;

  @override
  Widget build(BuildContext context) => MergeSemantics(
    child: InkWell(
      onTap: () => onChanged(!value),
      borderRadius: Radii.rSm,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 24,
              height: 24,
              child: Checkbox(
                value: value,
                onChanged: (v) => onChanged(v ?? false),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
              ),
            ),
            const SizedBox(width: Space.md),
            Expanded(
              child: Text(
                label,
                style: AppText.small.copyWith(color: AppColors.textSecondary),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// White dropdown-looking field ("Kalkulus 1 ⌄").
class SelectField extends StatelessWidget {
  const SelectField({
    super.key,
    required this.label,
    required this.value,
    required this.onTap,
    this.icon = AppIcons.book,
  });

  final String label;
  final String? value;
  final VoidCallback onTap;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: AppText.smallMedium.copyWith(color: AppColors.textSecondary),
      ),
      const SizedBox(height: Space.sm),
      Material(
        color: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: Radii.rMd,
          side: const BorderSide(color: AppColors.border),
        ),
        child: InkWell(
          borderRadius: Radii.rMd,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: Space.lg,
              vertical: 15,
            ),
            child: Row(
              children: [
                Icon(icon, size: 20, color: AppColors.textSecondary),
                const SizedBox(width: Space.md),
                Expanded(
                  child: Text(
                    value ?? 'Select',
                    style: AppText.body.copyWith(
                      color: value == null
                          ? AppColors.textTertiary
                          : AppColors.textPrimary,
                    ),
                  ),
                ),
                const Icon(
                  AppIcons.chevronDown,
                  size: 20,
                  color: AppColors.textSecondary,
                ),
              ],
            ),
          ),
        ),
      ),
    ],
  );
}
