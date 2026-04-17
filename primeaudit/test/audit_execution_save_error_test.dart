// Widget tests para comportamento de save com erro na tela de execução de auditoria.
//
// Estratégia: `AuditAnswerService` não é injetável na `AuditExecutionScreen` sem
// refactor (D-07 restringe escopo desta fase). Os testes abaixo cobrem a UI lógica
// DE FORMA ISOLADA quando possível (D-06 via harness), e delegam para verificação
// manual quando exige mockagem do Supabase (DINT-01, DINT-02, DINT-03).
//
// Referências:
//   - Plan 02 SUMMARY: comportamento exato do _saveAnswer / _showSaveError / guard D-06
//   - 01-VALIDATION.md "Manual-Only Verifications" para o que não é automatizável aqui

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// ---------------------------------------------------------------------------
// Widget de teste que replica APENAS a guarda D-06 do _finalize real.
// Não é uma duplicação de lógica de negócio — é a verificação de que o
// padrão de guard (if isNotEmpty → showDialog → return) funciona como
// esperado no estilo esperado pela tela real.
// ---------------------------------------------------------------------------
class _FinalizeGuardTestHarness extends StatefulWidget {
  final Map<String, Object> failedSaves;
  final VoidCallback onFinalizeSuccess;
  const _FinalizeGuardTestHarness({
    required this.failedSaves,
    required this.onFinalizeSuccess,
  });
  @override
  State<_FinalizeGuardTestHarness> createState() => _FinalizeGuardTestHarnessState();
}

class _FinalizeGuardTestHarnessState extends State<_FinalizeGuardTestHarness> {
  Future<void> _finalize() async {
    if (widget.failedSaves.isNotEmpty) {
      final count = widget.failedSaves.length;
      final respostas = count > 1 ? 'respostas' : 'resposta';
      final verbo = count > 1 ? 'foram salvas' : 'foi salva';
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Respostas não salvas'),
          content: Text(
            '$count $respostas não $verbo. '
            'Resolva as falhas antes de finalizar.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Entendido'),
            ),
          ],
        ),
      );
      return;
    }
    widget.onFinalizeSuccess();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ElevatedButton(
          onPressed: _finalize,
          child: const Text('Finalizar'),
        ),
      ),
    );
  }
}

void main() {
  group('AuditExecutionScreen — save error handling', () {
    testWidgets(
      'D-06: guarda do _finalize exibe dialog quando _failedSaves tem 1 item',
      (WidgetTester tester) async {
        var finalizeCalled = false;
        await tester.pumpWidget(MaterialApp(
          home: _FinalizeGuardTestHarness(
            failedSaves: const {'item-1': 'fake-pending'},
            onFinalizeSuccess: () => finalizeCalled = true,
          ),
        ));

        await tester.tap(find.text('Finalizar'));
        await tester.pumpAndSettle();

        expect(find.text('Respostas não salvas'), findsOneWidget);
        expect(find.textContaining('1 resposta'), findsOneWidget);
        expect(find.textContaining('não foi salva'), findsOneWidget);
        expect(find.text('Entendido'), findsOneWidget);
        expect(finalizeCalled, isFalse);
      },
    );

    testWidgets(
      'D-06: guarda usa plural quando há múltiplas falhas',
      (WidgetTester tester) async {
        await tester.pumpWidget(MaterialApp(
          home: _FinalizeGuardTestHarness(
            failedSaves: const {'item-1': 'a', 'item-2': 'b', 'item-3': 'c'},
            onFinalizeSuccess: () {},
          ),
        ));

        await tester.tap(find.text('Finalizar'));
        await tester.pumpAndSettle();

        expect(find.textContaining('3 respostas'), findsOneWidget);
        expect(find.textContaining('não foram salvas'), findsOneWidget);
      },
    );

    testWidgets(
      'D-06: guarda NÃO bloqueia quando _failedSaves está vazio',
      (WidgetTester tester) async {
        var finalizeCalled = false;
        await tester.pumpWidget(MaterialApp(
          home: _FinalizeGuardTestHarness(
            failedSaves: const {},
            onFinalizeSuccess: () => finalizeCalled = true,
          ),
        ));

        await tester.tap(find.text('Finalizar'));
        await tester.pumpAndSettle();

        expect(find.text('Respostas não salvas'), findsNothing);
        expect(finalizeCalled, isTrue);
      },
    );

    testWidgets(
      'DINT-01: snackbar "Não foi possível salvar" aparece em falha de upsertAnswer',
      (WidgetTester tester) async {
        // AuditAnswerService não é injetável em AuditExecutionScreen (D-07
        // restringe escopo desta fase). Rodar pumpWidget(AuditExecutionScreen)
        // exigiria Supabase.initialize com mock de HTTP — fora de escopo.
        // Verificação manual: ver 01-VALIDATION.md "Manual-Only Verifications".
      },
      skip: true, // manual-only — ver 01-VALIDATION.md; AuditAnswerService não é injetável
    );

    testWidgets(
      'DINT-03: action button "Tentar novamente" dispara _saveAnswer novamente',
      (WidgetTester tester) async {
        // Mesma restrição de DINT-01: requer injeção de dependência no state.
        // Verificação manual: ver 01-VALIDATION.md "Manual-Only Verifications".
      },
      skip: true, // manual-only — ver 01-VALIDATION.md; AuditAnswerService não é injetável
    );
  });
}
