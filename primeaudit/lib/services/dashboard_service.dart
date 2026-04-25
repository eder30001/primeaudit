import 'package:supabase_flutter/supabase_flutter.dart';

/// Agregações de dados para o dashboard da HomeScreen.
///
/// Métodos que dependem de tabelas ainda não existentes (Phase 8+)
/// implementam fallback try/catch retornando 0.
class DashboardService {
  final _client = Supabase.instance.client;

  /// Retorna o total de ações corretivas abertas da empresa.
  /// Retorna 0 enquanto a tabela `corrective_actions` não existir (Phase 8).
  /// Retorna 0 se [companyId] for null e a tabela existir (sem escopo).
  Future<int> getOpenActionsCount(String? companyId) async {
    try {
      var query = _client
          .from('corrective_actions')
          .select('id')
          .eq('status', 'aberta');
      if (companyId != null) {
        query = query.eq('company_id', companyId);
      }
      final data = await query;
      return (data as List).length;
    } catch (_) {
      return 0; // tabela corrective_actions ainda não existe (Phase 8)
    }
  }

  /// Retorna o total de empresas cadastradas.
  /// Uso exclusivo de superuser/dev (D-07 em 07-CONTEXT.md).
  Future<int> getCompaniesCount() async {
    final data = await _client.from('companies').select('id');
    return (data as List).length;
  }
}
