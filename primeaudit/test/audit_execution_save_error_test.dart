// Widget tests da tela de execução de auditoria — comportamento de save com erro.
//
// Scaffold criado no Plan 01 (Wave 0) para satisfazer o Nyquist Rule: os comandos
// `flutter test` dos plans downstream apontam para este arquivo. Os `testWidgets`
// estão marcados como `skip` e serão implementados no Plan 03 (Wave 2) após o
// fix real em audit_execution_screen.dart (Plan 02, Wave 1).

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AuditExecutionScreen — save error handling', () {
    testWidgets(
      'DINT-01: exibe snackbar quando upsertAnswer lança exceção',
      (WidgetTester tester) async {
        // TODO(Plan 03): implementar — mockar AuditAnswerService para throw,
        // tocar em um item, esperar snackbar com texto "Não foi possível salvar".
      },
      skip: true, // preenchido no Plan 03 (Wave 2)
    );

    testWidgets(
      'DINT-03: snackbar action "Tentar novamente" chama _saveAnswer novamente',
      (WidgetTester tester) async {
        // TODO(Plan 03): implementar — primeiro upsertAnswer throws, segundo succeeds;
        // tocar em "Tentar novamente"; verificar que _failedSaves fica vazio.
      },
      skip: true, // preenchido no Plan 03 (Wave 2)
    );

    testWidgets(
      'D-06: _finalize() exibe dialog de bloqueio quando _failedSaves não está vazio',
      (WidgetTester tester) async {
        // TODO(Plan 03): implementar — simular falha de save, tocar em Finalizar,
        // verificar dialog "Respostas não salvas" com contagem correta.
      },
      skip: true, // preenchido no Plan 03 (Wave 2)
    );
  });
}
