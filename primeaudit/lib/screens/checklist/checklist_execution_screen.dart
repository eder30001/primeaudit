import 'package:flutter/material.dart';
import '../../models/checklist_execution.dart';

/// Tela de execução de checklist — implementada no plano 14-04.
///
/// Stub temporário para permitir compilação e análise estática
/// enquanto o plano 14-04 é executado em paralelo.
class ChecklistExecutionScreen extends StatelessWidget {
  final ChecklistExecution execution;

  const ChecklistExecutionScreen({super.key, required this.execution});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(execution.templateName)),
      body: const Center(child: CircularProgressIndicator()),
    );
  }
}
