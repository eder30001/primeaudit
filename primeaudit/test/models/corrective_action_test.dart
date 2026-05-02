import 'package:flutter_test/flutter_test.dart';
import 'package:primeaudit/models/corrective_action.dart';

Map<String, dynamic> _fullActionMap() => {
  'id': 'ca1',
  'audit_id': 'a1',
  'template_item_id': 'ti1',
  'title': 'Acao teste',
  'description': 'Descricao',
  'responsible_user_id': 'u1',
  'due_date': '2027-01-01',
  'status': 'aberta',
  'company_id': 'c1',
  'created_by': 'u2',
  'created_at': '2026-04-25T00:00:00.000Z',
  'updated_at': '2026-04-25T00:00:00.000Z',
  'profiles': {'full_name': 'Ana'},
  'audits': {'title': 'Auditoria X'},
};

void main() {
  // fromMap — scalar fields
  group('CorrectiveAction.fromMap — campos escalares', () {
    test('parseia id, auditId, templateItemId, title', () {
      final a = CorrectiveAction.fromMap(_fullActionMap());
      expect(a.id, equals('ca1'));
      expect(a.auditId, equals('a1'));
      expect(a.templateItemId, equals('ti1'));
      expect(a.title, equals('Acao teste'));
    });

    test('parseia dueDate como DateTime a partir de DATE string', () {
      final a = CorrectiveAction.fromMap(_fullActionMap());
      expect(a.dueDate, equals(DateTime(2027, 1, 1)));
    });

    test('description e null quando campo ausente', () {
      final map = Map<String, dynamic>.from(_fullActionMap())..remove('description');
      final a = CorrectiveAction.fromMap(map);
      expect(a.description, isNull);
    });
  });

  // fromMap — nested joins
  group('CorrectiveAction.fromMap — joins', () {
    test('parseia responsibleName de profiles join', () {
      final a = CorrectiveAction.fromMap(_fullActionMap());
      expect(a.responsibleName, equals('Ana'));
    });

    test('responsibleName e null quando profiles join ausente', () {
      final map = Map<String, dynamic>.from(_fullActionMap())..remove('profiles');
      final a = CorrectiveAction.fromMap(map);
      expect(a.responsibleName, isNull);
    });

    test('parseia linkedAuditTitle de audits join', () {
      final a = CorrectiveAction.fromMap(_fullActionMap());
      expect(a.linkedAuditTitle, equals('Auditoria X'));
    });
  });

  // Status enum fromDb
  group('CorrectiveActionStatus.fromDb — todos os 6 valores', () {
    test("'aberta' -> aberta", () => expect(CorrectiveActionStatus.fromDb('aberta'), equals(CorrectiveActionStatus.aberta)));
    test("'em_andamento' -> emAndamento", () => expect(CorrectiveActionStatus.fromDb('em_andamento'), equals(CorrectiveActionStatus.emAndamento)));
    test("'em_avaliacao' -> emAvaliacao", () => expect(CorrectiveActionStatus.fromDb('em_avaliacao'), equals(CorrectiveActionStatus.emAvaliacao)));
    test("'aprovada' -> aprovada", () => expect(CorrectiveActionStatus.fromDb('aprovada'), equals(CorrectiveActionStatus.aprovada)));
    test("'rejeitada' -> rejeitada", () => expect(CorrectiveActionStatus.fromDb('rejeitada'), equals(CorrectiveActionStatus.rejeitada)));
    test("'cancelada' -> cancelada", () => expect(CorrectiveActionStatus.fromDb('cancelada'), equals(CorrectiveActionStatus.cancelada)));
    test('null -> aberta (fallback)', () => expect(CorrectiveActionStatus.fromDb(null), equals(CorrectiveActionStatus.aberta)));
    test('desconhecido -> aberta (fallback)', () => expect(CorrectiveActionStatus.fromDb('desconhecido'), equals(CorrectiveActionStatus.aberta)));
  });

  // isFinal — novo fluxo: finalizada e cancelada são finais; rejeitada passou a ser
  // legado não-final (responsável pode reenviar via transição legado → em_analise)
  group('CorrectiveActionStatus.isFinal', () {
    test('aprovada e final (legado)', () => expect(CorrectiveActionStatus.aprovada.isFinal, isTrue));
    test('finalizada e final (novo)', () => expect(CorrectiveActionStatus.finalizada.isFinal, isTrue));
    test('cancelada e final', () => expect(CorrectiveActionStatus.cancelada.isFinal, isTrue));
    test('rejeitada NAO e final (legado reenviavel)', () => expect(CorrectiveActionStatus.rejeitada.isFinal, isFalse));
    test('aberta NAO e final', () => expect(CorrectiveActionStatus.aberta.isFinal, isFalse));
    test('emAndamento NAO e final', () => expect(CorrectiveActionStatus.emAndamento.isFinal, isFalse));
    test('emAvaliacao NAO e final', () => expect(CorrectiveActionStatus.emAvaliacao.isFinal, isFalse));
    test('emAnalise NAO e final', () => expect(CorrectiveActionStatus.emAnalise.isFinal, isFalse));
    test('reaberta NAO e final', () => expect(CorrectiveActionStatus.reaberta.isFinal, isFalse));
  });

  // isOverdue
  group('CorrectiveAction.isOverdue', () {
    test('true quando dueDate passado e status nao-final', () {
      final map = Map<String, dynamic>.from(_fullActionMap())
        ..['due_date'] = '2020-01-01'
        ..['status'] = 'aberta';
      expect(CorrectiveAction.fromMap(map).isOverdue, isTrue);
    });

    test('false quando status final (aprovada), mesmo dueDate passado', () {
      final map = Map<String, dynamic>.from(_fullActionMap())
        ..['due_date'] = '2020-01-01'
        ..['status'] = 'aprovada';
      expect(CorrectiveAction.fromMap(map).isOverdue, isFalse);
    });

    test('false quando dueDate futuro', () {
      final map = Map<String, dynamic>.from(_fullActionMap())
        ..['due_date'] = '2099-12-31'
        ..['status'] = 'aberta';
      expect(CorrectiveAction.fromMap(map).isOverdue, isFalse);
    });
  });
}
