import 'package:flutter/material.dart';

const _byCategory = <String, IconData>{
  'joy': Icons.sentiment_satisfied_alt,
  'love': Icons.favorite_border,
  'friendship': Icons.people_outline,
  'wins': Icons.emoji_events_outlined,
  'beginnings': Icons.wb_sunny_outlined,
  'everyday': Icons.coffee_outlined,
  'wonder': Icons.explore_outlined,
  'starting-over': Icons.restart_alt,
  'making': Icons.brush_outlined,
  'work': Icons.work_outline,
  'job-search': Icons.badge_outlined,
  'money': Icons.payments_outlined,
  'study': Icons.school_outlined,
  'family': Icons.family_restroom,
  'identity': Icons.fingerprint,
  'health': Icons.medical_services_outlined,
  'mental-health': Icons.psychology_outlined,
  'caregiving': Icons.volunteer_activism_outlined,
  'loneliness': Icons.nights_stay_outlined,
  'heartbreak': Icons.heart_broken_outlined,
  'sacrifice': Icons.balance,
  'grief': Icons.local_florist_outlined,
};

IconData iconForCategory(String? categoryId) =>
    _byCategory[categoryId] ?? Icons.forum_outlined;
