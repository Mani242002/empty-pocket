import 'package:flutter/material.dart';

/// Centralized color palette for EmptyPocket
abstract class AppColors {
  // Brand Colors
  static const Color primaryMint = Color(0xFF00C896);
  static const Color primaryEmerald = Color(0xFF10B981);
  static const Color primaryTeal = Color(0xFF0D9488);

  // Financial Semantics
  static const Color income = Color(0xFF10B981); // Positive / Inflow
  static const Color expense = Color(0xFFF43F5E); // Negative / Outflow
  static const Color warning = Color(0xFFF59E0B); // Budget Alert / Warning
  static const Color investment = Color(0xFF6366F1); // Assets / Investments
  static const Color info = Color(0xFF0EA5E9); // Info / Planning
  static const Color savings = Color(0xFF8B5CF6); // Goals / Savings

  // Dark Theme Palette (Obsidian / Slate)
  static const Color darkBackground = Color(0xFF0B0F17);
  static const Color darkSurface = Color(0xFF131B26);
  static const Color darkSurfaceVariant = Color(0xFF1A2433);
  static const Color darkBorder = Color(0xFF263345);
  static const Color darkTextPrimary = Color(0xFFF1F5F9);
  static const Color darkTextSecondary = Color(0xFF94A3B8);
  static const Color darkTextMuted = Color(0xFF64748B);

  // Light Theme Palette (Ice / Slate)
  static const Color lightBackground = Color(0xFFF8FAFC);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceVariant = Color(0xFFF1F5F9);
  static const Color lightBorder = Color(0xFFE2E8F0);
  static const Color lightTextPrimary = Color(0xFF0F172A);
  static const Color lightTextSecondary = Color(0xFF475569);
  static const Color lightTextMuted = Color(0xFF94A3B8);
}
