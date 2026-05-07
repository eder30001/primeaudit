---
status: partial
phase: 15-photos-per-item
source: [15-VERIFICATION.md]
started: 2026-05-07T00:00:00Z
updated: 2026-05-07T00:00:00Z
---

## Current Test

[aguardando testes em dispositivo real]

## Tests

### 1. Fluxo câmera/galeria → miniatura inline
expected: Ao tocar o ícone de câmera em um item do tipo 'photo', um bottom sheet aparece com opções "Tirar foto" e "Escolher da galeria". Após selecionar/tirar a foto, ela aparece como miniatura 72x72 com CircularProgressIndicator enquanto faz upload, depois como imagem estática quando uploaded.
result: [pending]

### 2. Isolamento de falha de upload em dispositivo real
expected: Com conectividade simulada ausente (modo avião), a falha de upload exibe um snackbar de erro mas NÃO impede a finalização do checklist. O botão "Finalizar" permanece disponível e funcional quando _failedSaves está vazio, mesmo com fotos em estado error.
result: [pending]

### 3. Carregamento de fotos ao reabrir rascunho
expected: Ao reabrir uma execução de checklist que já tinha fotos enviadas, as fotos carregam automaticamente como miniaturas a partir do banco remoto (via `getImagesByExecution`), sem necessidade de nova interação do usuário.
result: [pending]

## Summary

total: 3
passed: 0
issues: 0
pending: 3
skipped: 0
blocked: 0

## Gaps
