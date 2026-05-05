# Changelog

All notable changes to **evo-ai-crm-community** will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- N/A

### Changed

- N/A

### Fixed

- N/A

## [v1.0.0-rc2] - 2026-05-05

Release de estabilização — concentra correções de `500 Internal Server Error` em endpoints REST, fixes do fluxo Evolution Go e ajustes de listeners / dispatchers.

### Fixed

#### API REST — bugs que causavam 500
- **`PATCH /api/v1/pipelines/:id/pipeline_items/:id/update_custom_fields`**: `before_action :set_pipeline_item` não cobria `:update_custom_fields`, então `@pipeline_item` ficava `nil` e cada chamada levantava `NoMethodError`. (#32)
- **`POST /api/v1/contacts/:id/companies` levantava `NoMethodError`**: `validate :must_belong_to_same_account` declarado em `ContactCompany` não tinha implementação. Definido como `no-op` (Community é single-tenant). (#34)
- **`POST` / `DELETE /api/v1/contacts/:id/companies` retornavam 500 em violação de regra de negócio**: `error_response(code:, message:)` com kwargs incompatíveis com a assinatura do helper (positional). Corrigido para retornar 400 com envelope `BUSINESS_RULE_VIOLATION`. (#35)
- **`/api/v1/agents/*` retornavam 500 / `Unauthorized`**: `current_user` era passado como primeiro argumento posicional para `EvoAiCoreService.*_agent` (a assinatura espera `params` / `agent_data` / `agent_id`); além disso, `request.headers` nunca era encaminhado, então o `evo-core` recebia chamadas sem token Bearer. (#33) — *follow-up registrado em [#42](https://github.com/EvolutionAPI/evo-ai-crm-community/issues/42) para replicar o fix nos demais controllers (`apikeys`, `folders`, etc).*
- **`GET /api/v1/oauth/applications`**: retornava array JSON puro, mas o frontend espera o envelope padrão `{ success, data, meta: { pagination } }`. Tela `/settings/integrations/oauth-apps` quebrava com `TypeError: Cannot read properties of undefined (reading 'pagination')`. (#36)
- **EVO-1000** — `POST /api/v1/team_members` retornava 401 + body `{"error":"Invalid User IDs"}` para todo UUID válido (a validação fazia `params[:user_ids].map(&:to_i)`, mas o PK do `User` é UUID — todos viravam `0` e nunca casavam). Resgate ajustado para `RecordInvalid` / `InvalidForeignKey` com 422 limpo. (#24)

#### Listeners e dispatchers
- **`ContactCompanyListener`**: eventos eram publicados via `Wisper::Publisher` com `data: { ... }`, mas todos os listeners do projeto leem como `event.data[:contact]` (esperando o wrapper `Events::Base` do `SyncDispatcher`). Resultado: `undefined method 'data' for an instance of Hash` no log + broadcast `CONTACT_COMPANY_LINKED` nunca disparava. Migrado para `Rails.configuration.dispatcher.dispatch(...)` em `LinkCompanyService`, `UnlinkCompanyService`, `Contact#add_company` e `#remove_company`; listener tolera `account: nil` via `single_tenant_account`. (#37)

#### Serializers
- **EVO-1010** — `TeamSerializer` agora inclui `members_count` (rodando `team.team_members.count` indexado por `team_id`), corrigindo cards / linhas que mostravam `0 members` mesmo com membros associados. (#25)

#### Pipelines / Templates / Mensageria (do ciclo `develop`)
- **EVO-974**: aceita payload com filtros aninhados, suporta `pipeline_id` / `contact_id`, e `query_builder` agora pareia `row + clause` para sobreviver a cláusulas vazias.
- **EVO-1002**: `MessageTemplate#serialized` espelha `settings.status` no top-level; criação de template roteia pelo provider sync (Meta) e não inverte mais `active` para `false` em sync de templates `PENDING` / `REJECTED`.
- **EVO-1001**: resolve UUIDs de labels ao tagear / renderizar conversas. (#14)
- **EVO-1005**: `pipeline_items#update` persiste `pipeline_stage_id`. (#27)
- **EVO-1006**: `include_labels` agora atravessa toda a cadeia de serialização do pipeline. (#39)
- **EVO-984**: fallback de credencial + webhook eager para Evolution Go. (#41)
- **EVO-985**: `BACKEND_URL` apontando para `localhost` é bloqueado em produção. (#30)
- **EVO-996**: preserva `in_reply_to` quando a mensagem-pai ainda não foi resolvida. (#31)
- **EVO-1012**: expõe `thumbnail` e fia o avatar fetch via Evolution API. (#28)
- **WhatsApp groups**: mensagens de grupo agora são ingeridas em uma única conversa por grupo (não mais uma por participante). (#29)

#### Banco / DevOps
- **db**: dropados FKs para tabela `users` removida (que travavam `db:migrate`). (#3)
- **evolution_go**: `api_url` e `admin_token` agora persistem no `provider_config` a partir do `GlobalConfig`. (#5)
- **whatsapp_cloud**: removido fetch de avatar do Evolution Go no fluxo Cloud inbound.

### Changed

- **CI**: workflow agora também publica imagens `develop` para staging.

## [v1.0.0-rc1] - 2026-04-24

### Added

- Primeiro release candidate público do `evo-ai-crm-community`.
- API REST `Api::V1::*` com controladores para conversas, contatos, pipelines, agents, OAuth applications, teams, channels, etc.
- Integração com `evo-ai-core-service` (agents) via `EvoAiCoreService`.
- Listeners de eventos via `Wisper` + `SyncDispatcher` com broadcasts para `ActionCableListener`.
- Serializers `MessageTemplate`, `Team`, `Pipeline`, etc.
- Background jobs (`Webhooks::WhatsappEventsJob`, `ActionCableBroadcastJob`).
- Master schema do banco como fonte de verdade do setup.

---

[Unreleased]: https://github.com/EvolutionAPI/evo-ai-crm-community/compare/v1.0.0-rc2...HEAD
[v1.0.0-rc2]: https://github.com/EvolutionAPI/evo-ai-crm-community/compare/v1.0.0-rc1...v1.0.0-rc2
[v1.0.0-rc1]: https://github.com/EvolutionAPI/evo-ai-crm-community/releases/tag/v1.0.0-rc1
