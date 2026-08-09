import 'package:flutter/material.dart';
import 'package:sporcle/app_colors.dart';
import 'package:sporcle/views/games_view.dart';
import 'package:sporcle/views/room_entry_view.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Game Room',
      theme: ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: AppColors.deepPurple,
        colorScheme: const ColorScheme.light(
          primary: AppColors.partyPurple,
          onPrimary: AppColors.white,
          primaryContainer: AppColors.softGray,
          onPrimaryContainer: AppColors.ink,
          secondary: AppColors.cyan,
          onSecondary: AppColors.white,
          surface: AppColors.midnight,
          onSurface: AppColors.ink,
          onSurfaceVariant: AppColors.mutedText,
          outline: AppColors.partyPurple,
          outlineVariant: AppColors.softGray,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.partyPurple,
          foregroundColor: AppColors.white,
          elevation: 0,
        ),
        cardTheme: const CardThemeData(
          color: AppColors.midnight,
          surfaceTintColor: Colors.transparent,
        ),
        chipTheme: const ChipThemeData(
          backgroundColor: AppColors.softGray,
          labelStyle: TextStyle(color: AppColors.ink),
          side: BorderSide(color: AppColors.softGray),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.partyPurple,
            foregroundColor: AppColors.white,
            disabledBackgroundColor: AppColors.softGray,
            disabledForegroundColor: AppColors.mutedText,
            textStyle: const TextStyle(fontWeight: FontWeight.w800),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            minimumSize: const Size.fromHeight(46),
          ),
        ),
        listTileTheme: const ListTileThemeData(
          iconColor: AppColors.partyPurple,
          textColor: AppColors.ink,
        ),
      ),
      debugShowCheckedModeBanner: false,
      home: const GamesView(),
    );
  }
}
