import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_tokens.dart';

/// Brand-gradient header with rounded bottom corners. Content is inset by the
/// status bar automatically.
class HeroHeader extends StatelessWidget {
  const HeroHeader({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    // The gradient is dark in both themes, so the status bar needs light icons.
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
      child: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: Brand.hero,
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
        ),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(Gap.xl, Gap.md, Gap.xl, Gap.xl),
            child: child,
          ),
        ),
      ),
    );
  }
}
