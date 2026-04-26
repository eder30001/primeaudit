import 'package:supabase_flutter/supabase_flutter.dart';

/// Agregações de dados para o dashboard da HomeScreen.
///
/// Métodos que dependem de tabelas ainda não existentes (Phase 8+)
/// implementam fallback try/catch retornando 0.
class DashboardService {
  final _client = Supabase.instance.client;

  /// Retorna o total de ações corretivas não-finalizadas da empresa.
  Future<int> getOpenActionsCount(String? companyId) async {
    var query = _client
        .from('corrective_actions')
        .select('id')
        .inFilter('status', ['aberta', 'em_andamento', 'em_avaliacao']);
    if (companyId != null) {
      query = query.eq('company_id', companyId);
    }
    final data = await query;
    return (data as List).length;
  }

  /// Retorna o total de empresas cadastradas.
  /// Uso exclusivo de superuser/dev (D-07 em 07-CONTEXT.md).
  Future<int> getCompaniesCount() async {
    final data = await _client.from('companies').select('id');
    return (data as List).length;
  }
}
