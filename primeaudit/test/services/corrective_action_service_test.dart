// Unit tests para funções estáticas de CorrectiveActionService.
// NÃO instancia CorrectiveActionService (Supabase.instance.client throws em testes).
import 'package:flutter_test/flutter_test.dart';
import 'package:primeaudit/services/corrective_action_service.dart';
import 'package:primeaudit/models/corrective_action.dart';

CorrectiveAction _action({
  String id = 'ca1',
  String responsibleUserId = 'user_resp',
  String createdBy = 'criador',
  CorrectiveActionStatus status = CorrectiveActionStatus.aberta,
}) {
  return CorrectiveAction(
    id: id,
    auditId: 'a1',
    templateItemId: 'ti1',
    title: 'Test',
    responsibleUserId: responsibleUserId,
    dueDate: DateTime(2027, 1, 1),
    status: status,
    companyId: 'c1',
    createdBy: createdBy,
    createdAt: DateTime(2026, 4, 25),
    updatedAt: DateTime(2026, 4, 25),
  );
}

void main() {
  // ---------------------------------------------------------------------------
  // isNonConforming — inalterado
  // ---------------------------------------------------------------------------
  group('CorrectiveActionService.isNonConforming — ok_nok', () {
    test("'ok' retorna false", () => expect(CorrectiveActionService.isNonConforming('ok_nok', 'ok'), isFalse));
    test("'nok' retorna true", () => expect(CorrectiveActionService.isNonConforming('ok_nok', 'nok'), isTrue));
    test('null retorna false', () => expect(CorrectiveActionService.isNonConforming('ok_nok', null), isFalse));
    test('vazio retorna false', () => expect(CorrectiveActionService.isNonConforming('ok_nok', ''), isFalse));
  });

  group('CorrectiveActionService.isNonConforming — yes_no', () {
    test("'yes' retorna false", () => expect(CorrectiveActionService.isNonConforming('yes_no', 'yes'), isFalse));
    test("'no' retorna true", () => expect(CorrectiveActionService.isNonConforming('yes_no', 'no'), isTrue));
  });

  group('CorrectiveActionService.isNonConforming — scale_1_5', () {
    test("'1' retorna true (<=2)", () => expect(CorrectiveActionService.isNonConforming('scale_1_5', '1'), isTrue));
    test("'2' retorna true (<=2)", () => expect(CorrectiveActionService.isNonConforming('scale_1_5', '2'), isTrue));
    test("'3' retorna false (>=3)", () => expect(CorrectiveActionService.isNonConforming('scale_1_5', '3'), isFalse));
    test("'5' retorna false", () => expect(CorrectiveActionService.isNonConforming('scale_1_5', '5'), isFalse));
  });

  group('CorrectiveActionService.isNonConforming — percentage', () {
    test("'49' retorna true (<50)", () => expect(CorrectiveActionService.isNonConforming('percentage', '49'), isTrue));
    test("'50' retorna false (>=50)", () => expect(CorrectiveActionService.isNonConforming('percentage', '50'), isFalse));
    test("'100' retorna false", () => expect(CorrectiveActionService.isNonConforming('percentage', '100'), isFalse));
  });

  group('CorrectiveActionService.isNonConforming — text e selection', () {
    test('text com conteudo retorna true', () => expect(CorrectiveActionService.isNonConforming('text', 'qualquer'), isTrue));
    test('selection com opcao retorna true', () => expect(CorrectiveActionService.isNonConforming('selection', 'opcao_a'), isTrue));
    test('text null retorna false', () => expect(CorrectiveActionService.isNonConforming('text', null), isFalse));
  });

  // ---------------------------------------------------------------------------
  // canTransitionTo — admin/superuser/dev: bypass total
  // ---------------------------------------------------------------------------
  group('canTransitionTo — admin/superuser/dev bypass', () {
    test('adm pode cancelar qualquer acao', () {
      expect(CorrectiveActionService.canTransitionTo(
        newStatus: 'cancelada', action: _action(), role: 'adm', userId: 'outro',
      ), isTrue);
    });
    test('superuser pode aprovar qualquer acao', () {
      expect(CorrectiveActionService.canTransitionTo(
        newStatus: 'aprovada',
        action: _action(status: CorrectiveActionStatus.emAvaliacao),
        role: 'superuser', userId: 'outro',
      ), isTrue);
    });
    test('dev pode rejeitar qualquer acao', () {
      expect(CorrectiveActionService.canTransitionTo(
        newStatus: 'rejeitada',
        action: _action(status: CorrectiveActionStatus.emAvaliacao),
        role: 'dev', userId: 'outro',
      ), isTrue);
    });
  });

  // ---------------------------------------------------------------------------
  // canTransitionTo — responsável (executa a ação)
  // ---------------------------------------------------------------------------
  group('canTransitionTo — responsavel', () {
    test('pode iniciar: aberta -> em_andamento', () {
      expect(CorrectiveActionService.canTransitionTo(
        newStatus: 'em_andamento',
        action: _action(status: CorrectiveActionStatus.aberta, responsibleUserId: 'user_resp', createdBy: 'outro'),
        role: 'auditor', userId: 'user_resp',
      ), isTrue);
    });

    test('pode submeter: em_andamento -> em_avaliacao', () {
      expect(CorrectiveActionService.canTransitionTo(
        newStatus: 'em_avaliacao',
        action: _action(status: CorrectiveActionStatus.emAndamento, responsibleUserId: 'user_resp', createdBy: 'outro'),
        role: 'auditor', userId: 'user_resp',
      ), isTrue);
    });

    test('pode reabrir: rejeitada -> em_andamento', () {
      expect(CorrectiveActionService.canTransitionTo(
        newStatus: 'em_andamento',
        action: _action(status: CorrectiveActionStatus.rejeitada, responsibleUserId: 'user_resp', createdBy: 'outro'),
        role: 'auditor', userId: 'user_resp',
      ), isTrue);
    });

    test('NAO pode cancelar', () {
      expect(CorrectiveActionService.canTransitionTo(
        newStatus: 'cancelada',
        action: _action(responsibleUserId: 'user_resp', createdBy: 'outro'),
        role: 'auditor', userId: 'user_resp',
      ), isFalse);
    });

    test('NAO pode aprovar (responsavel nao avalia a propria acao)', () {
      expect(CorrectiveActionService.canTransitionTo(
        newStatus: 'aprovada',
        action: _action(status: CorrectiveActionStatus.emAvaliacao, responsibleUserId: 'user_resp', createdBy: 'outro'),
        role: 'auditor', userId: 'user_resp',
      ), isFalse);
    });

    test('NAO pode rejeitar (responsavel nao avalia a propria acao)', () {
      expect(CorrectiveActionService.canTransitionTo(
        newStatus: 'rejeitada',
        action: _action(status: CorrectiveActionStatus.emAvaliacao, responsibleUserId: 'user_resp', createdBy: 'outro'),
        role: 'auditor', userId: 'user_resp',
      ), isFalse);
    });
  });

  // ---------------------------------------------------------------------------
  // canTransitionTo — criador (avalia e gerencia a ação)
  // ---------------------------------------------------------------------------
  group('canTransitionTo — criador (nao-responsavel)', () {
    test('pode iniciar acao aberta', () {
      expect(CorrectiveActionService.canTransitionTo(
        newStatus: 'em_andamento',
        action: _action(status: CorrectiveActionStatus.aberta, responsibleUserId: 'user_resp', createdBy: 'criador'),
        role: 'auditor', userId: 'criador',
      ), isTrue);
    });

    test('pode reabrir acao rejeitada', () {
      expect(CorrectiveActionService.canTransitionTo(
        newStatus: 'em_andamento',
        action: _action(status: CorrectiveActionStatus.rejeitada, responsibleUserId: 'user_resp', createdBy: 'criador'),
        role: 'auditor', userId: 'criador',
      ), isTrue);
    });

    test('pode aprovar acao em avaliacao', () {
      expect(CorrectiveActionService.canTransitionTo(
        newStatus: 'aprovada',
        action: _action(status: CorrectiveActionStatus.emAvaliacao, responsibleUserId: 'user_resp', createdBy: 'criador'),
        role: 'auditor', userId: 'criador',
      ), isTrue);
    });

    test('pode rejeitar acao em avaliacao', () {
      expect(CorrectiveActionService.canTransitionTo(
        newStatus: 'rejeitada',
        action: _action(status: CorrectiveActionStatus.emAvaliacao, responsibleUserId: 'user_resp', createdBy: 'criador'),
        role: 'auditor', userId: 'criador',
      ), isTrue);
    });

    test('NAO pode submeter (apenas o responsavel executa)', () {
      expect(CorrectiveActionService.canTransitionTo(
        newStatus: 'em_avaliacao',
        action: _action(status: CorrectiveActionStatus.emAndamento, responsibleUserId: 'user_resp', createdBy: 'criador'),
        role: 'auditor', userId: 'criador',
      ), isFalse);
    });

    test('NAO pode cancelar', () {
      expect(CorrectiveActionService.canTransitionTo(
        newStatus: 'cancelada',
        action: _action(responsibleUserId: 'user_resp', createdBy: 'criador'),
        role: 'auditor', userId: 'criador',
      ), isFalse);
    });

    test('criador que tambem e responsavel NAO pode aprovar a propria acao', () {
      expect(CorrectiveActionService.canTransitionTo(
        newStatus: 'aprovada',
        action: _action(status: CorrectiveActionStatus.emAvaliacao, responsibleUserId: 'criador', createdBy: 'criador'),
        role: 'auditor', userId: 'criador',
      ), isFalse);
    });
  });

  // ---------------------------------------------------------------------------
  // canTransitionTo — terceiro (auditor sem vinculo com a acao)
  // ---------------------------------------------------------------------------
  group('canTransitionTo — terceiro sem vinculo', () {
    test('NAO pode iniciar acao', () {
      expect(CorrectiveActionService.canTransitionTo(
        newStatus: 'em_andamento',
        action: _action(status: CorrectiveActionStatus.aberta, responsibleUserId: 'user_resp', createdBy: 'criador'),
        role: 'auditor', userId: 'terceiro',
      ), isFalse);
    });

    test('NAO pode aprovar acao', () {
      expect(CorrectiveActionService.canTransitionTo(
        newStatus: 'aprovada',
        action: _action(status: CorrectiveActionStatus.emAvaliacao, responsibleUserId: 'user_resp', createdBy: 'criador'),
        role: 'auditor', userId: 'terceiro',
      ), isFalse);
    });

    test('NAO pode rejeitar acao', () {
      expect(CorrectiveActionService.canTransitionTo(
        newStatus: 'rejeitada',
        action: _action(status: CorrectiveActionStatus.emAvaliacao, responsibleUserId: 'user_resp', createdBy: 'criador'),
        role: 'auditor', userId: 'terceiro',
      ), isFalse);
    });

    test('NAO pode cancelar', () {
      expect(CorrectiveActionService.canTransitionTo(
        newStatus: 'cancelada',
        action: _action(responsibleUserId: 'user_resp', createdBy: 'criador'),
        role: 'auditor', userId: 'terceiro',
      ), isFalse);
    });
  });
}
