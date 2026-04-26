import 'package:flutter/material.dart';
import '../core/app_colors.dart';
import '../models/corrective_action.dart';

// Stub — substituído completamente na Wave 4 (08-04-PLAN.md)
class CorrectiveActionDetailScreen extends StatelessWidget {
  final CorrectiveAction action;
  final String currentUserId;
  final String currentUserRole;

  const CorrectiveActionDetailScreen({
    super.key,
    required this.action,
    required this.currentUserId,
    required this.currentUserRole,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(action.title),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: const Center(child: CircularProgressIndicator()),
    );
  }
}
