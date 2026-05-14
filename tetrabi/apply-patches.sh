#!/bin/sh
# tetrabi/apply-patches.sh
# Aplicado em BUILD TIME no Dockerfile (RUN /bin/sh /tetrabi/apply-patches.sh).
# Sobrescreve arquivos originais do upstream com versões corrigidas da TETRABI.
# Nunca editar os arquivos em app/ diretamente — as correções vivem aqui.
set -e

echo "[tetrabi] Aplicando patches customizados TETRABI..."

# ──────────────────────────────────────────────────────────────────────────────
# PATCH 1 — WhatsApp extendedTextMessage
# Fix: links enviados pelo Baileys/Evolution como extendedTextMessage
#      apareciam como "arquivo" em vez do texto do link.
# Arquivo: app/services/whatsapp/incoming_message_service_helpers.rb
# ──────────────────────────────────────────────────────────────────────────────
cp /tetrabi/patches/incoming_message_service_helpers.rb \
   /app/app/services/whatsapp/incoming_message_service_helpers.rb
echo "[tetrabi] ✓ PATCH 1: incoming_message_service_helpers.rb"

# ──────────────────────────────────────────────────────────────────────────────
# PATCH 2 — Instagram share/ig_reel normalization (Array vs Hash + payload.url)
# Fix 1: Graph API retorna attachments como Hash {"data":[...]}, webhook retorna
#        Array. Normalizar para sempre retornar Array.
# Fix 2: message_content extrai URL de qualquer attachment com payload.url
#        (share, ig_reel, futuro) evitando Down.download de HTML.
# Arquivo: app/builders/messages/instagram/base_message_builder.rb
# ──────────────────────────────────────────────────────────────────────────────
cp /tetrabi/patches/base_message_builder.rb \
   /app/app/builders/messages/instagram/base_message_builder.rb
echo "[tetrabi] ✓ PATCH 2: instagram/base_message_builder.rb"

# ──────────────────────────────────────────────────────────────────────────────
# PATCH 3 — Messenger process_attachment guard (share/ig_reel skip)
# Fix: quando message_content já extraiu a URL como texto, não chamar
#      Down.download para o attachment — evita caixa vazia no frontend.
# Arquivo: app/builders/messages/messenger/message_builder.rb
# ──────────────────────────────────────────────────────────────────────────────
cp /tetrabi/patches/message_builder.rb \
   /app/app/builders/messages/messenger/message_builder.rb
echo "[tetrabi] ✓ PATCH 3: messenger/message_builder.rb"

echo "[tetrabi] Todos os patches aplicados com sucesso."
