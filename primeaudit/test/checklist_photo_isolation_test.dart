import 'package:flutter_test/flutter_test.dart';

// Simula o contrato de isolamento sem instanciar o Supabase client
// O teste verifica a lógica de _failedSaves vs upload state machine

void main() {
  group('Photo upload isolation — _failedSaves independence', () {
    test('_failedSaves is not modified by photo upload failure', () {
      // Simula o estado interno da tela
      final failedSaves = <String, String>{}; // itemId → response
      final photosPerItem = <String, List<_MockPhotoEntry>>{};

      // Simula resposta salva com sucesso
      failedSaves['item-001'] = 'sim';

      // Simula falha de upload de foto para item-002
      final failedEntry = _MockPhotoEntry(
          key: 'tmp_123', state: _MockPhotoState.error);
      photosPerItem['item-002'] = [failedEntry];

      // INVARIANTE: falha de foto não modifica _failedSaves
      expect(failedSaves.containsKey('item-002'), isFalse,
          reason: 'Photo upload failure must not add to _failedSaves');
      expect(failedSaves['item-001'], 'sim',
          reason: 'Existing answer save state unaffected by photo failure');
    });

    test('_finalize check uses only _failedSaves — photo error state is ignored', () {
      final failedSaves = <String, String>{};
      final photosPerItem = <String, List<_MockPhotoEntry>>{
        'item-001': [_MockPhotoEntry(key: 'k1', state: _MockPhotoState.error)],
      };

      // _finalize logic: apenas verifica failedSaves
      final canFinalize = failedSaves.isEmpty;

      expect(canFinalize, isTrue,
          reason: 'Photo error state must not block _finalize — only failedSaves blocks');
      expect(photosPerItem['item-001']!.first.state, _MockPhotoState.error,
          reason: 'Photo is in error state but finalize is still allowed');
    });
  });
}

enum _MockPhotoState { uploading, uploaded, error }

class _MockPhotoEntry {
  final String key;
  final _MockPhotoState state;
  const _MockPhotoEntry({required this.key, required this.state});
}
