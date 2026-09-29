import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

const blue = Color(0xFF1688F8);
const navy = Color(0xFF0B1F36);
const green = Color(0xFF15B873);
const orange = Color(0xFFFF9D3D);

class RiderPalette extends ThemeExtension<RiderPalette> {
  const RiderPalette({
    required this.text,
    required this.muted,
    required this.background,
    required this.surface,
    required this.line,
    required this.softBlue,
    required this.softOrange,
    required this.softGreen,
    required this.navIndicator,
    required this.splashStart,
    required this.splashMid,
    required this.splashEnd,
    required this.urgent,
    required this.ratingStar,
    required this.success,
    required this.duskDeep,
    required this.duskMid,
  });

  final Color text;
  final Color muted;
  final Color background;
  final Color surface;
  final Color line;
  final Color softBlue;
  final Color softOrange;
  final Color softGreen;
  final Color navIndicator;
  final Color splashStart;
  final Color splashMid;
  final Color splashEnd;
  final Color urgent;
  final Color ratingStar;
  final Color success;
  final Color duskDeep;
  final Color duskMid;

  static const light = RiderPalette(
    text: Color(0xFF142033),
    muted: Color(0xFF708198),
    background: Color(0xFFF4F8FC),
    surface: Colors.white,
    line: Color(0xFFDDE7F1),
    softBlue: Color(0xFFE8F4FF),
    softOrange: Color(0xFFFFF5E8),
    softGreen: Color(0xFFEFFAF5),
    navIndicator: Color(0xFFDCEEFF),
    splashStart: Colors.white,
    splashMid: Color(0xFFE8F5FF),
    splashEnd: Color(0xFFCFEAFF),
    urgent: Color(0xFFFF6F4A),
    ratingStar: Color(0xFFFFB82E),
    success: green,
    duskDeep: navy,
    duskMid: Color(0xFF144C8C),
  );

  static const dark = RiderPalette(
    text: Color(0xFFE8EEF7),
    muted: Color(0xFF96A6BC),
    background: Color(0xFF0E1623),
    surface: Color(0xFF182434),
    line: Color(0xFF2A3850),
    softBlue: Color(0xFF173250),
    softOrange: Color(0xFF392D20),
    softGreen: Color(0xFF15382D),
    navIndicator: Color(0xFF23446B),
    splashStart: Color(0xFF13233A),
    splashMid: Color(0xFF0F1E33),
    splashEnd: Color(0xFF081424),
    urgent: Color(0xFFFF8061),
    ratingStar: Color(0xFFFFC94D),
    success: Color(0xFF36C98B),
    duskDeep: Color(0xFF07182B),
    duskMid: Color(0xFF123E70),
  );

  @override
  RiderPalette copyWith({
    Color? text,
    Color? muted,
    Color? background,
    Color? surface,
    Color? line,
    Color? softBlue,
    Color? softOrange,
    Color? softGreen,
    Color? navIndicator,
    Color? splashStart,
    Color? splashMid,
    Color? splashEnd,
    Color? urgent,
    Color? ratingStar,
    Color? success,
    Color? duskDeep,
    Color? duskMid,
  }) => RiderPalette(
    text: text ?? this.text,
    muted: muted ?? this.muted,
    background: background ?? this.background,
    surface: surface ?? this.surface,
    line: line ?? this.line,
    softBlue: softBlue ?? this.softBlue,
    softOrange: softOrange ?? this.softOrange,
    softGreen: softGreen ?? this.softGreen,
    navIndicator: navIndicator ?? this.navIndicator,
    splashStart: splashStart ?? this.splashStart,
    splashMid: splashMid ?? this.splashMid,
    splashEnd: splashEnd ?? this.splashEnd,
    urgent: urgent ?? this.urgent,
    ratingStar: ratingStar ?? this.ratingStar,
    success: success ?? this.success,
    duskDeep: duskDeep ?? this.duskDeep,
    duskMid: duskMid ?? this.duskMid,
  );

  @override
  RiderPalette lerp(ThemeExtension<RiderPalette>? other, double t) {
    if (other is! RiderPalette) return this;
    return RiderPalette(
      text: Color.lerp(text, other.text, t)!,
      muted: Color.lerp(muted, other.muted, t)!,
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      line: Color.lerp(line, other.line, t)!,
      softBlue: Color.lerp(softBlue, other.softBlue, t)!,
      softOrange: Color.lerp(softOrange, other.softOrange, t)!,
      softGreen: Color.lerp(softGreen, other.softGreen, t)!,
      navIndicator: Color.lerp(navIndicator, other.navIndicator, t)!,
      splashStart: Color.lerp(splashStart, other.splashStart, t)!,
      splashMid: Color.lerp(splashMid, other.splashMid, t)!,
      splashEnd: Color.lerp(splashEnd, other.splashEnd, t)!,
      urgent: Color.lerp(urgent, other.urgent, t)!,
      ratingStar: Color.lerp(ratingStar, other.ratingStar, t)!,
      success: Color.lerp(success, other.success, t)!,
      duskDeep: Color.lerp(duskDeep, other.duskDeep, t)!,
      duskMid: Color.lerp(duskMid, other.duskMid, t)!,
    );
  }
}

RiderPalette riderPaletteOf(BuildContext context) =>
    Theme.of(context).extension<RiderPalette>() ?? RiderPalette.light;

ThemeData buildRiderTheme(RiderPalette palette) {
  final brightness = identical(palette, RiderPalette.dark)
      ? Brightness.dark
      : Brightness.light;
  final scheme =
      ColorScheme.fromSeed(
        seedColor: blue,
        primary: blue,
        brightness: brightness,
      ).copyWith(
        surface: palette.surface,
        // Rider heroes and gradient actions use the brand-blue primary as
        // their background in both brightness modes. The generated dark
        // scheme can otherwise choose a dark foreground for this bright blue,
        // making operational text almost invisible on the dusk gradient.
        onPrimary: Colors.white,
        onSurface: palette.text,
        onSurfaceVariant: palette.muted,
        outline: palette.line,
        outlineVariant: palette.line,
        tertiary: palette.urgent,
      );
  return ThemeData(
    useMaterial3: true,
    fontFamily: 'Arial',
    scaffoldBackgroundColor: palette.background,
    colorScheme: scheme,
    extensions: <ThemeExtension<dynamic>>[palette],
    textTheme: TextTheme(
      displaySmall: TextStyle(color: palette.text, fontWeight: FontWeight.w900),
      headlineMedium: TextStyle(
        color: palette.text,
        fontWeight: FontWeight.w900,
      ),
      titleLarge: TextStyle(color: palette.text, fontWeight: FontWeight.w800),
      titleMedium: TextStyle(color: palette.text, fontWeight: FontWeight.w700),
      bodyLarge: TextStyle(color: palette.text, height: 1.4),
      bodyMedium: TextStyle(color: palette.muted, height: 1.4),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: palette.surface,
      surfaceTintColor: Colors.transparent,
      foregroundColor: palette.text,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: palette.surface,
      indicatorColor: palette.navIndicator,
      surfaceTintColor: Colors.transparent,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: palette.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 17),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: palette.line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: palette.line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: blue, width: 1.5),
      ),
    ),
    dividerTheme: DividerThemeData(color: palette.line),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
  );
}

class RiderThemeController extends ValueNotifier<ThemeMode> {
  RiderThemeController([
    super.value = ThemeMode.system,
    SharedPreferences? preferences,
  ]) : _preferences = preferences;

  static const preferenceKey = 'rider_theme_mode';
  final SharedPreferences? _preferences;

  static Future<RiderThemeController> restore() async {
    final preferences = await SharedPreferences.getInstance();
    final mode = switch (preferences.getString(preferenceKey)) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
    return RiderThemeController(mode, preferences);
  }

  ThemeMode get mode => value;

  Future<void> setMode(ThemeMode mode) async {
    if (value == mode) return;
    value = mode;
    await _preferences?.setString(preferenceKey, mode.name);
  }
}

class RiderThemeScope extends InheritedWidget {
  const RiderThemeScope({
    super.key,
    required this.controller,
    required super.child,
  });
  final RiderThemeController controller;

  static RiderThemeController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<RiderThemeScope>();
    assert(scope != null, 'RiderThemeScope is missing.');
    return scope!.controller;
  }

  @override
  bool updateShouldNotify(RiderThemeScope oldWidget) =>
      controller != oldWidget.controller;
}
