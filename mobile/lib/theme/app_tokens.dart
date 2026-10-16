import 'package:flutter/material.dart';

/// Spacing scale (4pt grid).
class Gap {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
}

/// Corner radii.
class Corners {
  static const double sm = 10;
  static const double md = 16;
  static const double lg = 24;
  static const double pill = 999;

  static BorderRadius get smAll => BorderRadius.circular(sm);
  static BorderRadius get mdAll => BorderRadius.circular(md);
  static BorderRadius get lgAll => BorderRadius.circular(lg);
}

/// Brand palette.
class Brand {
  static const Color indigo = Color(0xFF4F46E5);
  static const Color indigoDeep = Color(0xFF3730A3);
  static const Color violet = Color(0xFF7C3AED);
  static const Color mint = Color(0xFF10B981);
  static const Color amber = Color(0xFFF59E0B);
  static const Color rose = Color(0xFFE11D48);
  static const Color ink = Color(0xFF0B1020);

  static const LinearGradient hero = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [indigoDeep, indigo, violet],
  );
}

/// Semantic colours that Material's ColorScheme has no slot for
/// (stop status, shortfall warnings). Access via `context.status`.
@immutable
class StatusColors extends ThemeExtension<StatusColors> {
  const StatusColors({
    required this.success,
    required this.successContainer,
    required this.warning,
    required this.warningContainer,
    required this.next,
    required this.nextContainer,
    required this.pending,
    required this.pendingContainer,
  });

  final Color success, successContainer;
  final Color warning, warningContainer;
  final Color next, nextContainer;
  final Color pending, pendingContainer;

  static const light = StatusColors(
    success: Color(0xFF047857),
    successContainer: Color(0xFFD1FAE5),
    warning: Color(0xFFB45309),
    warningContainer: Color(0xFFFEF3C7),
    next: Brand.indigo,
    nextContainer: Color(0xFFE0E7FF),
    pending: Color(0xFF64748B),
    pendingContainer: Color(0xFFE2E8F0),
  );

  static const dark = StatusColors(
    success: Color(0xFF34D399),
    successContainer: Color(0xFF064E3B),
    warning: Color(0xFFFBBF24),
    warningContainer: Color(0xFF451A03),
    next: Color(0xFFA5B4FC),
    nextContainer: Color(0xFF312E81),
    pending: Color(0xFF94A3B8),
    pendingContainer: Color(0xFF1E293B),
  );

  @override
  StatusColors copyWith({
    Color? success,
    Color? successContainer,
    Color? warning,
    Color? warningContainer,
    Color? next,
    Color? nextContainer,
    Color? pending,
    Color? pendingContainer,
  }) => StatusColors(
    success: success ?? this.success,
    successContainer: successContainer ?? this.successContainer,
    warning: warning ?? this.warning,
    warningContainer: warningContainer ?? this.warningContainer,
    next: next ?? this.next,
    nextContainer: nextContainer ?? this.nextContainer,
    pending: pending ?? this.pending,
    pendingContainer: pendingContainer ?? this.pendingContainer,
  );

  @override
  StatusColors lerp(StatusColors? other, double t) {
    if (other == null) return this;
    return StatusColors(
      success: Color.lerp(success, other.success, t)!,
      successContainer: Color.lerp(
        successContainer,
        other.successContainer,
        t,
      )!,
      warning: Color.lerp(warning, other.warning, t)!,
      warningContainer: Color.lerp(
        warningContainer,
        other.warningContainer,
        t,
      )!,
      next: Color.lerp(next, other.next, t)!,
      nextContainer: Color.lerp(nextContainer, other.nextContainer, t)!,
      pending: Color.lerp(pending, other.pending, t)!,
      pendingContainer: Color.lerp(
        pendingContainer,
        other.pendingContainer,
        t,
      )!,
    );
  }
}

extension ThemeX on BuildContext {
  ThemeData get theme => Theme.of(this);
  ColorScheme get colors => Theme.of(this).colorScheme;
  TextTheme get text => Theme.of(this).textTheme;
  StatusColors get status =>
      Theme.of(this).extension<StatusColors>() ??
      (Theme.of(this).brightness == Brightness.dark
          ? StatusColors.dark
          : StatusColors.light);
}
