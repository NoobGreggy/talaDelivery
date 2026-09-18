import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

const sky = Color(0xFF1688F8);
const success = Color(0xFF18B878);
const warning = Color(0xFFFFA23F);
const danger = Color(0xFFE85656);

class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette({
    required this.brand,
    required this.text,
    required this.quiet,
    required this.background,
    required this.line,
    required this.surface,
    required this.cardBorder,
    required this.avatarFill,
    required this.softBlue,
    required this.infoFill,
    required this.successFill,
    required this.successCircleFill,
    required this.dangerFill,
    required this.unreadFill,
    required this.emptyIcon,
    required this.inactiveStep,
    required this.navIndicator,
    required this.splashBg,
    required this.splashStart,
    required this.splashMid,
    required this.splashEnd,
    required this.frosted,
  });

  final Color brand;
  final Color text;
  final Color quiet;
  final Color background;
  final Color line;
  final Color surface;
  final Color cardBorder;
  final Color avatarFill;
  final Color softBlue;
  final Color infoFill;
  final Color successFill;
  final Color successCircleFill;
  final Color dangerFill;
  final Color unreadFill;
  final Color emptyIcon;
  final Color inactiveStep;
  final Color navIndicator;
  final Color splashBg;
  final Color splashStart;
  final Color splashMid;
  final Color splashEnd;
  final Color frosted;

  static const light = AppPalette(
    brand: Color(0xFF102238),
    text: Color(0xFF172335),
    quiet: Color(0xFF718197),
    background: Color(0xFFF5F8FC),
    line: Color(0xFFDDE7F0),
    surface: Colors.white,
    cardBorder: Color(0xFFEBF0F5),
    avatarFill: Color(0xFFE1F0FD),
    softBlue: Color(0xFFE7F4FF),
    infoFill: Color(0xFFE8F4FF),
    successFill: Color(0xFFE7F8F0),
    successCircleFill: Color(0xFFE3F8EF),
    dangerFill: Color(0xFFFFEEEE),
    unreadFill: Color(0xFFF0F7FF),
    emptyIcon: Color(0xFFB8C7D5),
    inactiveStep: Color(0xFFCCD7E2),
    navIndicator: Color(0xFFDCEEFF),
    splashBg: Color(0xFFE4F3FF),
    splashStart: Colors.white,
    splashMid: Color(0xFFEAF6FF),
    splashEnd: Color(0xFFD8EDFF),
    frosted: Colors.white,
  );

  static const dark = AppPalette(
    brand: Color(0xFFE9EFF8),
    text: Color(0xFFE6EDF6),
    quiet: Color(0xFF94A4BB),
    background: Color(0xFF0E1623),
    line: Color(0xFF27344C),
    surface: Color(0xFF182434),
    cardBorder: Color(0xFF26344C),
    avatarFill: Color(0xFF1D2D48),
    softBlue: Color(0xFF173250),
    infoFill: Color(0xFF16304E),
    successFill: Color(0xFF12382C),
    successCircleFill: Color(0xFF113A2B),
    dangerFill: Color(0xFF3A2428),
    unreadFill: Color(0xFF1C2B45),
    emptyIcon: Color(0xFF53637C),
    inactiveStep: Color(0xFF35445C),
    navIndicator: Color(0xFF23446B),
    splashBg: Color(0xFF0B1626),
    splashStart: Color(0xFF13233A),
    splashMid: Color(0xFF0F1E33),
    splashEnd: Color(0xFF081424),
    frosted: Color(0xFF1A263A),
  );

  AppPalette _copyWith(
    Color? brand,
    Color? text,
    Color? quiet,
    Color? background,
    Color? line,
    Color? surface,
    Color? cardBorder,
    Color? avatarFill,
    Color? softBlue,
    Color? infoFill,
    Color? successFill,
    Color? successCircleFill,
    Color? dangerFill,
    Color? unreadFill,
    Color? emptyIcon,
    Color? inactiveStep,
    Color? navIndicator,
    Color? splashBg,
    Color? splashStart,
    Color? splashMid,
    Color? splashEnd,
    Color? frosted,
  ) => AppPalette(
    brand: brand ?? this.brand,
    text: text ?? this.text,
    quiet: quiet ?? this.quiet,
    background: background ?? this.background,
    line: line ?? this.line,
    surface: surface ?? this.surface,
    cardBorder: cardBorder ?? this.cardBorder,
    avatarFill: avatarFill ?? this.avatarFill,
    softBlue: softBlue ?? this.softBlue,
    infoFill: infoFill ?? this.infoFill,
    successFill: successFill ?? this.successFill,
    successCircleFill: successCircleFill ?? this.successCircleFill,
    dangerFill: dangerFill ?? this.dangerFill,
    unreadFill: unreadFill ?? this.unreadFill,
    emptyIcon: emptyIcon ?? this.emptyIcon,
    inactiveStep: inactiveStep ?? this.inactiveStep,
    navIndicator: navIndicator ?? this.navIndicator,
    splashBg: splashBg ?? this.splashBg,
    splashStart: splashStart ?? this.splashStart,
    splashMid: splashMid ?? this.splashMid,
    splashEnd: splashEnd ?? this.splashEnd,
    frosted: frosted ?? this.frosted,
  );

  @override
  AppPalette copyWith({
    Color? brand,
    Color? text,
    Color? quiet,
    Color? background,
    Color? line,
    Color? surface,
    Color? cardBorder,
    Color? avatarFill,
    Color? softBlue,
    Color? infoFill,
    Color? successFill,
    Color? successCircleFill,
    Color? dangerFill,
    Color? unreadFill,
    Color? emptyIcon,
    Color? inactiveStep,
    Color? navIndicator,
    Color? splashBg,
    Color? splashStart,
    Color? splashMid,
    Color? splashEnd,
    Color? frosted,
  }) => _copyWith(
    brand,
    text,
    quiet,
    background,
    line,
    surface,
    cardBorder,
    avatarFill,
    softBlue,
    infoFill,
    successFill,
    successCircleFill,
    dangerFill,
    unreadFill,
    emptyIcon,
    inactiveStep,
    navIndicator,
    splashBg,
    splashStart,
    splashMid,
    splashEnd,
    frosted,
  );

  @override
  AppPalette lerp(ThemeExtension<AppPalette>? other, double t) {
    if (other is! AppPalette) return this;
    return AppPalette(
      brand: Color.lerp(brand, other.brand, t)!,
      text: Color.lerp(text, other.text, t)!,
      quiet: Color.lerp(quiet, other.quiet, t)!,
      background: Color.lerp(background, other.background, t)!,
      line: Color.lerp(line, other.line, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      cardBorder: Color.lerp(cardBorder, other.cardBorder, t)!,
      avatarFill: Color.lerp(avatarFill, other.avatarFill, t)!,
      softBlue: Color.lerp(softBlue, other.softBlue, t)!,
      infoFill: Color.lerp(infoFill, other.infoFill, t)!,
      successFill: Color.lerp(successFill, other.successFill, t)!,
      successCircleFill: Color.lerp(
        successCircleFill,
        other.successCircleFill,
        t,
      )!,
      dangerFill: Color.lerp(dangerFill, other.dangerFill, t)!,
      unreadFill: Color.lerp(unreadFill, other.unreadFill, t)!,
      emptyIcon: Color.lerp(emptyIcon, other.emptyIcon, t)!,
      inactiveStep: Color.lerp(inactiveStep, other.inactiveStep, t)!,
      navIndicator: Color.lerp(navIndicator, other.navIndicator, t)!,
      splashBg: Color.lerp(splashBg, other.splashBg, t)!,
      splashStart: Color.lerp(splashStart, other.splashStart, t)!,
      splashMid: Color.lerp(splashMid, other.splashMid, t)!,
      splashEnd: Color.lerp(splashEnd, other.splashEnd, t)!,
      frosted: Color.lerp(frosted, other.frosted, t)!,
    );
  }
}

AppPalette appPaletteOf(BuildContext context) =>
    Theme.of(context).extension<AppPalette>() ?? AppPalette.light;

ThemeData buildAppTheme(AppPalette palette) {
  final bright = palette == AppPalette.dark
      ? Brightness.dark
      : Brightness.light;
  final colorScheme =
      ColorScheme.fromSeed(
        seedColor: sky,
        primary: sky,
        brightness: bright,
      ).copyWith(
        surface: palette.surface,
        onSurface: palette.text,
        outline: palette.line,
      );
  return ThemeData(
    useMaterial3: true,
    fontFamily: 'Arial',
    scaffoldBackgroundColor: palette.background,
    colorScheme: colorScheme,
    extensions: <ThemeExtension<dynamic>>[palette],
    iconTheme: IconThemeData(color: palette.text),
    cardTheme: CardThemeData(
      color: palette.surface,
      surfaceTintColor: Colors.transparent,
    ),
    textTheme: TextTheme(
      displaySmall: TextStyle(
        color: palette.text,
        fontWeight: FontWeight.w900,
        height: 1.05,
      ),
      headlineMedium: TextStyle(
        color: palette.text,
        fontWeight: FontWeight.w900,
        height: 1.1,
      ),
      titleLarge: TextStyle(color: palette.text, fontWeight: FontWeight.w800),
      titleMedium: TextStyle(color: palette.text, fontWeight: FontWeight.w800),
      bodyLarge: TextStyle(color: palette.text, height: 1.4),
      bodyMedium: TextStyle(color: palette.quiet, height: 1.4),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: palette.surface,
      surfaceTintColor: palette.surface,
      foregroundColor: palette.text,
      titleTextStyle: TextStyle(
        color: palette.text,
        fontWeight: FontWeight.w900,
        fontSize: 18,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: palette.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 17, vertical: 16),
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
        borderSide: const BorderSide(color: sky, width: 1.5),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: palette.surface,
      surfaceTintColor: Colors.transparent,
      indicatorColor: palette.navIndicator,
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          color: states.contains(WidgetState.selected) ? sky : palette.quiet,
        ),
      ),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          color: states.contains(WidgetState.selected) ? sky : palette.quiet,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: palette.surface,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: TextStyle(
        color: palette.text,
        fontWeight: FontWeight.w900,
        fontSize: 20,
      ),
      contentTextStyle: TextStyle(color: palette.text, height: 1.4),
    ),
    dividerTheme: DividerThemeData(color: palette.line),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
  );
}

class ThemeController extends ValueNotifier<ThemeMode> {
  ThemeController([
    super.value = ThemeMode.system,
    SharedPreferences? preferences,
  ]) : _preferences = preferences;

  static const preferenceKey = 'customer_theme_mode';

  final SharedPreferences? _preferences;

  static Future<ThemeController> restore() async {
    final preferences = await SharedPreferences.getInstance();
    final savedMode = preferences.getString(preferenceKey);
    final mode = switch (savedMode) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
    return ThemeController(mode, preferences);
  }

  ThemeMode get mode => value;
  set mode(ThemeMode next) => unawaited(setMode(next));

  Future<void> setMode(ThemeMode next) async {
    if (value == next) return;
    value = next;
    await _preferences?.setString(preferenceKey, next.name);
  }

  void cycle() {
    mode = switch (value) {
      ThemeMode.system => ThemeMode.light,
      ThemeMode.light => ThemeMode.dark,
      ThemeMode.dark => ThemeMode.system,
    };
  }
}

class ThemeScope extends InheritedWidget {
  const ThemeScope({super.key, required this.controller, required super.child});

  final ThemeController controller;

  static ThemeController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<ThemeScope>();
    assert(scope != null, 'ThemeScope is missing above this context.');
    return scope!.controller;
  }

  @override
  bool updateShouldNotify(ThemeScope oldWidget) =>
      controller != oldWidget.controller;
}
