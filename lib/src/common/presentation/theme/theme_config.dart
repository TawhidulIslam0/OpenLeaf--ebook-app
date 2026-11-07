import 'package:flutter/material.dart';

const Color lightPrimary = Color(0xffF5F5F5);
const Color darkPrimary = Color(0xff1f1f1f);
const Color lightAccent = Color(0xff356B52); // OpenBook forest green
const Color darkAccent = Color(0xff8FBE9F);
const Color lightBG = Colors.white;
const Color darkBG = Color(0xff121212);
const Color smokeWhite = Color(0xffF5F5F5);

final ThemeData lightTheme = ThemeData(
  colorScheme: ColorScheme.fromSeed(
    seedColor: lightAccent,
  ).copyWith(
    secondary: lightAccent,
  ),
  useMaterial3: true,
  primaryColor: lightPrimary,
  visualDensity: VisualDensity.adaptivePlatformDensity,
  scaffoldBackgroundColor: const Color(0xffFAF9F5),
  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(
      backgroundColor: lightAccent,
      foregroundColor: Colors.white,
    ),
  ),
  navigationRailTheme: const NavigationRailThemeData(
    backgroundColor: smokeWhite,
  ),
  tabBarTheme: const TabBarThemeData(
    labelColor: Colors.black,
    unselectedLabelColor: Colors.grey,
    indicator: UnderlineTabIndicator(
      borderSide: BorderSide(
        color: lightAccent,
        width: 2.0,
      ),
    ),
  ),
  appBarTheme: const AppBarTheme(
    backgroundColor: lightPrimary,
    elevation: 0.0,
    titleTextStyle: TextStyle(
      color: Colors.black,
      fontSize: 20,
      fontWeight: FontWeight.w800,
    ),
    iconTheme: IconThemeData(color: Colors.black),
  ),
);

final ThemeData darkTheme = ThemeData(
  brightness: Brightness.dark,
  colorScheme: ColorScheme.fromSeed(
    seedColor: darkAccent,
    brightness: Brightness.dark,
  ).copyWith(
    secondary: darkAccent,
  ),
  useMaterial3: true,
  primaryColor: darkPrimary,
  visualDensity: VisualDensity.adaptivePlatformDensity,
  scaffoldBackgroundColor: const Color(0xff151A17),
  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(
      backgroundColor: darkAccent,
      foregroundColor: const Color(0xff142018),
    ),
  ),
  navigationRailTheme: const NavigationRailThemeData(
    backgroundColor: darkPrimary,
  ),
  tabBarTheme: const TabBarThemeData(
    indicator: UnderlineTabIndicator(
      borderSide: BorderSide(
        color: lightAccent,
        width: 2.0,
      ),
    ),
  ),
  appBarTheme: const AppBarTheme(
    backgroundColor: darkPrimary,
    elevation: 0.0,
    titleTextStyle: TextStyle(
      color: Colors.white,
      fontSize: 20,
      fontWeight: FontWeight.w800,
    ),
    iconTheme: IconThemeData(color: Colors.white),
  ),
);
