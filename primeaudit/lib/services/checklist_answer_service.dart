import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/checklist_template.dart';

/// Gerencia respostas de execução de checklist (tabela `checklist_answers`).
///
/// Usa upsert com UNIQUE(execution_id, item_id) para que cada item tenha
/// sempre uma única resposta por execução.
///
/// Sem try/catch interno — callers (screens) são responsáveis por capturar exceções.
class ChecklistAnswerService {
  final _client = Supabase.instance.client;

  /// Retorna todas as respostas de uma execução ordenadas por answered_at.
  ///
  /// Retorna raw maps para o screen mapear diretamente:
  ///   _answers[row['item_id']] = row['response']
  ///   _observations[row['item_id']] = row['observation']
  ///
  /// Não usa ChecklistAnswer model intermediário — o screen consome Maps diretamente
  /// para evitar conversão desnecessária (padrão de performance documentado em 14-PATTERNS.md).
  Future<List<Map<String, dynamic>>> getAnswers(String executionId) async {
    final data = await _client
        .from('checklist_answers')
        .select()
        .eq('execution_id', executionId)
        .order('answered_at');
    return List<Map<String, dynamic>>.from(data as List);
  }

  /// Upsert idempotente de resposta por (execution_id, item_id).
  ///
  /// onConflict é obrigatório — sem ele o banco retorna 409 quando o item
  /// já tem resposta (violação da constraint UNIQUE(execution_id, item_id)).
  ///
  /// Mecanismo central do auto-save silencioso (EXEC-05): fire-and-forget na screen,
  /// sem interrupção da UI em caso de sucesso.
  Future<void> upsertAnswer({
    required String executionId,
    required String itemId,
    required String response,
    String? observation,
  }) async {
    await _client.from('checklist_answers').upsert(
      {
        'execution_id': executionId,
        'item_id': itemId,
        'response': response,
        'observation': observation,
        'answered_at': DateTime.now().toIso8601String(),
      },
      onConflict: 'execution_id,item_id',
    );
  }

  /// Calcula conformidade excluindo tipos informativos (number, date, photo).
  ///
  /// Tipos elegíveis para conformidade: yes_no, text, multiple_choice.
  /// Decisão STATE.md v1.2: "Tipos number e date excluídos do denominador".
  ///
  /// Regras de conformidade por tipo:
  ///   yes_no: 'yes' = conforme, 'no' = não conforme (entra no denominador)
  ///   text: qualquer string não vazia = conforme
  ///   multiple_choice: qualquer opção selecionada = conforme
  ///   Itens sem resposta entram no denominador mas não no numerador (continue).
  ///
  /// Retorna 100.0 quando não há itens elegíveis (evita divisão por zero).
  /// Resultado clampado em [0.0, 100.0].
  static double calculateConformity(
    List<ChecklistTemplateItem> items,
    Map<String, String> answers,
  ) {
    const conformityTypes = {'yes_no', 'text', 'multiple_choice'};
    final eligible =
        items.where((i) => conformityTypes.contains(i.itemType)).toList();
    if (eligible.isEmpty) return 100.0;

    final int total = eligible.length;
    int conforming = 0;

    for (final item in eligible) {
      final ans = answers[item.id];
      if (ans == null || ans.isEmpty) continue;
      switch (item.itemType) {
        case 'yes_no':
          if (ans == 'yes') conforming++;
        case 'text':
          if (ans.isNotEmpty) conforming++;
        case 'multiple_choice':
          if (ans.isNotEmpty) conforming++;
      }
    }

    return (conforming / total * 100).clamp(0.0, 100.0);
  }
}
