import 'package:flutter/widgets.dart';

abstract final class Space {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 20.0;
  static const xxl = 24.0;
  static const xxxl = 32.0;

  /// Horizontal page padding used on every phone frame.
  static const pageH = 20.0;
}

abstract final class Radii {
  static const sm = 8.0;
  static const md = 12.0; // default
  static const lg = 16.0; // cards
  static const xl = 24.0; // sheets
  static const full = 999.0;

  static final rSm = BorderRadius.circular(sm);
  static final rMd = BorderRadius.circular(md);
  static final rLg = BorderRadius.circular(lg);
  static final rXl = BorderRadius.circular(xl);
  static final rFull = BorderRadius.circular(full);
}

abstract final class Breakpoints {
  /// Below this: phone layout with bottom navigation.
  static const phone = 600.0;

  /// From this up: sidebar + two-pane layout.
  static const wide = 900.0;

  static const sidebarWidth = 248.0;

  /// Content max width for the 600–899 band (phone layout, centered).
  static const compactMaxWidth = 560.0;
}
