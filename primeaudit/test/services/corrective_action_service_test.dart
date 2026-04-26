// Unit tests para funções estáticas de CorrectiveActionService.
// NÃO instancia CorrectiveActionService (Supabase.instance.client throws em testes).
import 'package:flutter_test/flutter_test.dart';
import 'package:primeaudit/services/corrective_action_service.dart';
import 'package:primeaudit/models/corrective_action.dart';

CorrectiveAction _action({
  String id = 'ca1',
  String responsibleUserId = 'user_resp',
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
    createdBy: 'u2',
    createdAt: DateTime(2026, 4, 25),
    updatedAt: DateTime(2026, 4, 25),
  );
}

void main() {
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

  group('CorrectiveActionService.canTransitionTo — admin/superuser/dev', () {
    test('adm pode transicionar para qualquer status', () {
      expect(CorrectiveActionService.canTransitionTo(
        newStatus: 'cancelada', action: _action(), role: 'adm', userId: 'outro',
      ), isTrue);
    });
    test('superuser pode transicionar para qualquer status', () {
      expect(CorrectiveActionService.canTransitionTo(
        newStatus: 'cancelada', action: _action(), role: 'superuser', userId: 'outro',
      ), isTrue);
    });
    test('dev pode transicionar para qualquer status', () {
      expect(CorrectiveActionService.canTransitionTo(
        newStatus: 'aprovada',
        action: _action(status: CorrectiveActionStatus.emAvaliacao),
        role: 'dev', userId: 'outro',
      ), isTrue);
    });
  });

  group('CorrectiveActionService.canTransitionTo — responsavel', () {
    test('responsavel pode mover aberta -> em_andamento', () {
      expect(CorrectiveActionService.canTransitionTo(
        newStatus: 'em_andamento',
        action: _action(status: CorrectiveActionStatus.aberta, responsibleUserId: 'user_resp'),
        role: 'auditor', userId: 'user_resp',
      ), isTrue);
    });
    test('responsavel pode mover em_andamento -> em_avaliacao', () {
      expect(CorrectiveActionService.canTransitionTo(
        newStatus: 'em_avaliacao',
        action: _action(status: CorrectiveActionStatus.emAndamento, responsibleUserId: 'user_resp'),
        role: 'auditor', userId: 'user_resp',
      ), isTrue);
    });
    test('responsavel pode re-abrir rejeitada -> em_andamento', () {
      expect(CorrectiveActionService.canTransitionTo(
        newStatus: 'em_andamento',
        action: _action(status: CorrectiveActionStatus.rejeitada, responsibleUserId: 'user_resp'),
        role: 'auditor', userId: 'user_resp',
      ), isTrue);
    });
    test('responsavel NAO pode cancelar', () {
      expect(CorrectiveActionService.canTransitionTo(
        newStatus: 'cancelada',
        action: _action(responsibleUserId: 'user_resp'),
        role: 'auditor', userId: 'user_resp',
      ), isFalse);
    });
    test('responsavel NAO pode aprovar (precisa ser auditor/admin)', () {
      expect(CorrectiveActionService.canTransitionTo(
        newStatus: 'aprovada',
        action: _action(status: CorrectiveActionStatus.emAvaliacao, responsibleUserId: 'user_resp'),
        role: 'auditor', userId: 'user_resp',
      ), isFalse);
    });
  });

  group('CorrectiveActionService.canTransitionTo — auditor nao-responsavel', () {
    test('auditor pode aprovar em_avaliacao', () {
      expect(CorrectiveActionService.canTransitionTo(
        newStatus: 'aprovada',
        action: _action(status: CorrectiveActionStatus.emAvaliacao, responsibleUserId: 'outro_user'),
        role: 'auditor', userId: 'auditor_user',
      ), isTrue);
    });
    test('auditor pode rejeitar em_avaliacao', () {
      expect(CorrectiveActionService.canTransitionTo(
        newStatus: 'rejeitada',
        action: _action(status: CorrectiveActionStatus.emAvaliacao, responsibleUserId: 'outro_user'),
        role: 'auditor', userId: 'auditor_user',
      ), isTrue);
    });
    test('auditor NAO pode mover aberta -> em_andamento (somente responsavel/admin)', () {
      expect(CorrectiveActionService.canTransitionTo(
        newStatus: 'em_andamento',
        action: _action(status: CorrectiveActionStatus.aberta, responsibleUserId: 'outro_user'),
        role: 'auditor', userId: 'auditor_user',
      ), isFalse);
    });
    test('auditor NAO pode cancelar', () {
      expect(CorrectiveActionService.canTransitionTo(
        newStatus: 'cancelada',
        action: _action(responsibleUserId: 'outro_user'),
        role: 'auditor', userId: 'auditor_user',
      ), isFalse);
    });
  });
}
