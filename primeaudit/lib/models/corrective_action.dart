import 'package:flutter/material.dart';
import '../core/app_colors.dart';

enum CorrectiveActionStatus {
  aberta,
  emAndamento,
  emAvaliacao,
  aprovada,
  rejeitada,
  cancelada;

  String get dbValue {
    switch (this) {
      case aberta:      return 'aberta';
      case emAndamento: return 'em_andamento';
      case emAvaliacao: return 'em_avaliacao';
      case aprovada:    return 'aprovada';
      case rejeitada:   return 'rejeitada';
      case cancelada:   return 'cancelada';
    }
  }

  String get label {
    switch (this) {
      case aberta:      return 'Aberta';
      case emAndamento: return 'Em andamento';
      case emAvaliacao: return 'Em avaliação';
      case aprovada:    return 'Aprovada';
      case rejeitada:   return 'Rejeitada';
      case cancelada:   return 'Cancelada';
    }
  }

  Color get chipBackground {
    switch (this) {
      case aberta:      return Colors.orange.shade100;
      case emAndamento: return const Color(0xFFE3F2FD);
      case emAvaliacao: return Colors.purple.shade50;
      case aprovada:    return const Color(0xFFE8F5E9);
      case rejeitada:   return const Color(0xFFFFEBEE);
      case cancelada:   return Colors.grey.shade100;
    }
  }

  Color get chipText {
    switch (this) {
      case aberta:      return Colors.orange.shade800;
      case emAndamento: return const Color(0xFF1565C0);
      case emAvaliacao: return Colors.purple.shade800;
      case aprovada:    return const Color(0xFF2E7D32);
      case rejeitada:   return AppColors.error;
      case cancelada:   return Colors.grey.shade700;
    }
  }

  IconData get icon {
    switch (this) {
      case aberta:      return Icons.radio_button_unchecked_rounded;
      case emAndamento: return Icons.pending_rounded;
      case emAvaliacao: return Icons.rate_review_rounded;
      case aprovada:    return Icons.check_circle_rounded;
      case rejeitada:   return Icons.cancel_rounded;
      case cancelada:   return Icons.block_rounded;
    }
  }

  bool get isFinal =>
      this == aprovada || this == rejeitada || this == cancelada;

  static CorrectiveActionStatus fromDb(String? value) {
    switch (value) {
      case 'em_andamento': return CorrectiveActionStatus.emAndamento;
      case 'em_avaliacao': return CorrectiveActionStatus.emAvaliacao;
      case 'aprovada':     return CorrectiveActionStatus.aprovada;
      case 'rejeitada':    return CorrectiveActionStatus.rejeitada;
      case 'cancelada':    return CorrectiveActionStatus.cancelada;
      default:             return CorrectiveActionStatus.aberta;
    }
  }
}

class CorrectiveAction {
  final String id;
  final String auditId;
  final String templateItemId;
  final String title;
  final String? description;
  final String responsibleUserId;
  final String? responsibleName;
  final DateTime dueDate;
  final CorrectiveActionStatus status;
  final String companyId;
  final String createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? linkedAuditTitle;
  final String? resolutionNotes;

  const CorrectiveAction({
    required this.id,
    required this.auditId,
    required this.templateItemId,
    required this.title,
    this.description,
    required this.responsibleUserId,
    this.responsibleName,
    required this.dueDate,
    required this.status,
    required this.companyId,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
    this.linkedAuditTitle,
    this.resolutionNotes,
  });

  factory CorrectiveAction.fromMap(Map<String, dynamic> map) {
    return CorrectiveAction(
      id: map['id'] as String,
      auditId: map['audit_id'] as String,
      templateItemId: map['template_item_id'] as String,
      title: map['title'] as String,
      description: map['description'] as String?,
      responsibleUserId: map['responsible_user_id'] as String,
      responsibleName: (map['profiles'] as Map<String, dynamic>?)?['full_name'] as String?,
      dueDate: DateTime.parse(map['due_date'] as String),
      status: CorrectiveActionStatus.fromDb(map['status'] as String?),
      companyId: map['company_id'] as String,
      createdBy: map['created_by'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
      linkedAuditTitle: (map['audits'] as Map<String, dynamic>?)?['title'] as String?,
      resolutionNotes: map['resolution_notes'] as String?,
    );
  }

  bool get isOverdue =>
      dueDate.isBefore(DateTime.now()) && !status.isFinal;
}
