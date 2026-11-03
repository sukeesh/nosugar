import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// The night-sky palette. Gold = stars (sugar-free nights), lilac = sugar
/// crystals, pale blue = moons, sea blue = craving SOS.
class C {
  static const night = Color(0xFF0B1020);
  static const surface = Color(0xFF151B30);
  static const line = Color(0xFF262E4A);
  static const dim = Color(0xFF3A4366);
  static const text = Color(0xFFEEF0F7);
  static const soft = Color(0xFFC9CFE2);
  static const muted = Color(0xFF9AA3BD);

  static const gold = Color(0xFFF5C76B);
  static const ink = Color(0xFF1A1405);
  static const moon = Color(0xFFDCE3FF);

  static const sosBg = Color(0xFF0A1A2A);
  static const sosSurface = Color(0xFF13263A);
  static const sosLine = Color(0xFF22405E);
  static const sos = Color(0xFF7FB4FF);
  static const sosSoft = Color(0xFFA9C4E6);

  static const crystalTop = Color(0xFFF3EEF8);
  static const crystalLeft = Color(0xFFCFC6E0);
  static const crystalRight = Color(0xFFA79DC0);
}

class T {
  static TextStyle display(double size, {Color color = C.text, FontWeight weight = FontWeight.w700, double height = 1.0}) =>
      GoogleFonts.bricolageGrotesque(
        fontSize: size,
        fontWeight: weight,
        color: color,
        height: height,
        letterSpacing: -0.03 * size,
      );

  static TextStyle body(double size, {Color color = C.soft, FontWeight weight = FontWeight.w400, double height = 1.45}) =>
      GoogleFonts.inter(fontSize: size, fontWeight: weight, color: color, height: height);
}

ThemeData buildTheme() {
  final base = ThemeData(brightness: Brightness.dark, useMaterial3: true);
  return base.copyWith(
    scaffoldBackgroundColor: C.night,
    colorScheme: base.colorScheme.copyWith(primary: C.gold, surface: C.surface, onPrimary: C.ink),
    textTheme: GoogleFonts.interTextTheme(base.textTheme).apply(bodyColor: C.text, displayColor: C.text),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: C.surface,
      contentTextStyle: T.body(15, color: C.text),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    pageTransitionsTheme: const PageTransitionsTheme(builders: {
      TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
    }),
  );
}

/// Full-width pill button used for primary and secondary actions.
class Pill extends StatelessWidget {
  const Pill({
    super.key,
    required this.label,
    required this.onPressed,
    this.background = C.gold,
    this.foreground = C.ink,
    this.outlined = false,
    this.icon,
    this.sublabel,
    this.height = 60,
  });

  final String label;
  final String? sublabel;
  final VoidCallback? onPressed;
  final Color background;
  final Color foreground;
  final bool outlined;
  final Widget? icon;
  final double height;

  @override
  Widget build(BuildContext context) {
    final fg = outlined ? C.text : foreground;
    return SizedBox(
      width: double.infinity,
      height: sublabel == null ? height : height + 6,
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          backgroundColor: outlined ? Colors.transparent : background,
          foregroundColor: fg,
          shape: StadiumBorder(side: outlined ? const BorderSide(color: C.dim) : BorderSide.none),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[icon!, const SizedBox(width: 8)],
                Text(label, style: T.body(17, color: fg, weight: FontWeight.w600, height: 1.2)),
              ],
            ),
            if (sublabel != null)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(sublabel!, style: T.body(13, color: fg.withValues(alpha: 0.7), weight: FontWeight.w500, height: 1.2)),
              ),
          ],
        ),
      ),
    );
  }
}

class CircleIconButton extends StatelessWidget {
  const CircleIconButton({super.key, required this.icon, required this.onPressed, required this.tooltip, this.border = C.line});
  final IconData icon;
  final VoidCallback onPressed;
  final String tooltip;
  final Color border;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon, size: 20, color: C.soft),
      style: IconButton.styleFrom(
        fixedSize: const Size(44, 44),
        shape: CircleBorder(side: BorderSide(color: border)),
      ),
    );
  }
}
