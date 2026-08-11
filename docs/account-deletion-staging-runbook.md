# Validação de exclusão de conta em Supabase staging

Este runbook prepara a validação segura do fluxo de exclusão de conta do Flag Game em um projeto Supabase separado de staging. Nenhum comando deste documento deve ser executado contra produção até a validação em staging estar concluída e revisada.

## Parada obrigatória

- Não use o projeto configurado atualmente no app como ambiente de teste destrutivo sem confirmar que ele é staging.
- A URL local encontrada em `js/supabase-client.js` aponta para `https://kyupoytmphmdbwuvigcu.supabase.co`. Trate esse projeto como atual/produção até prova em contrário.
- Não exponha `SUPABASE_SERVICE_ROLE_KEY` no aplicativo, JavaScript, GitHub, logs, issues, prints ou respostas.
- Não use a assinatura de debug, chaves locais ou usuários reais para provar a exclusão.
- Não rode migrations, Edge Functions ou SQLs destrutivos no Supabase remoto nesta etapa.

## Pré-requisitos

- Um projeto Supabase novo, isolado e descartável para staging.
- Supabase CLI instalado no computador que fará a validação.
- Acesso ao painel do projeto staging para copiar URL, anon key e service role key.
- Uma conta Google de teste para login.
- Opcional, mas recomendado: Android Studio e um aparelho/emulador de teste.

## Branch local

Trabalhe na branch local de staging:

```powershell
git switch playstore-account-deletion-staging
```

Confira que não há alteração inesperada antes de qualquer teste remoto:

```powershell
git status --short
```

## Migrações a aplicar em staging

Em um projeto staging limpo, aplique as migrations nesta ordem:

```text
01_extensions_types.sql
02_profiles_identities.sql
03_entitlements_purchases.sql
04_sessions_results.sql
05_challenges.sql
06_views.sql
07_rpcs.sql
08_rls.sql
09_indices.sql
13_fix_ensure_profile_signature.sql
14_fix_ranking_view_visibility.sql
15_fix_global_rankings_schema_cache.sql
16_create_global_rankings_view.sql
17_fix_create_ranked_session_extensions.sql
18_fix_submit_ranked_result_remote_schema.sql
19_fix_submit_ranked_result_session_schema.sql
20_add_submit_ranked_result_sanitized_diagnostics.sql
21_fix_submit_ranked_result_remote_exact_schema.sql
22_make_check_is_supporter_schema_safe.sql
23_prepare_player_challenges_backend.sql
24_secure_completed_match_challenges.sql
25_remote_history_alignment_security.sql
26_promote_ranked_matches_to_challenges.sql
27_fix_ranked_session_contract.sql
28_fix_ranked_result_metrics_and_promotion.sql
29_account_deletion_backend.sql
```

Com Supabase CLI, valide o alvo antes de aplicar:

```powershell
supabase projects list
supabase link --project-ref STAGING_PROJECT_REF
supabase db push --include-all
```

Pare se o project ref não for o de staging.

## Edge Function

A função local fica em:

```text
supabase/functions/delete-account/index.ts
```

Segredos necessários no projeto staging:

```text
SUPABASE_URL=https://STAGING_PROJECT_REF.supabase.co
SUPABASE_ANON_KEY=<anon key do projeto staging>
SUPABASE_SERVICE_ROLE_KEY=<service role key do projeto staging>
DELETE_ACCOUNT_ALLOWED_ORIGINS=https://localhost,https://flaggameapp.github.io
DELETE_ACCOUNT_MAX_SESSION_AGE_SECONDS=900
```

`DELETE_ACCOUNT_ALLOWED_ORIGINS` pode receber temporariamente o domínio do site de staging, por exemplo:

```text
https://localhost,https://flaggameapp.github.io,https://staging.example.com
```

Não use `*`.

Exemplo de deploy somente para staging:

```powershell
supabase functions deploy delete-account --project-ref STAGING_PROJECT_REF
supabase secrets set SUPABASE_URL="https://STAGING_PROJECT_REF.supabase.co" --project-ref STAGING_PROJECT_REF
supabase secrets set SUPABASE_ANON_KEY="<staging anon key>" --project-ref STAGING_PROJECT_REF
supabase secrets set SUPABASE_SERVICE_ROLE_KEY="<staging service role key>" --project-ref STAGING_PROJECT_REF
supabase secrets set DELETE_ACCOUNT_ALLOWED_ORIGINS="https://localhost,https://flaggameapp.github.io" --project-ref STAGING_PROJECT_REF
supabase secrets set DELETE_ACCOUNT_MAX_SESSION_AGE_SECONDS="900" --project-ref STAGING_PROJECT_REF
```

Nunca cole valores reais de segredo em arquivos versionados.

## Configuração temporária do app para staging

Antes de testar o aplicativo contra staging, crie uma alteração local não commitada em `js/supabase-client.js` com a URL e a anon key de staging.

Checklist:

- `CONFIG.url` deve apontar para `https://STAGING_PROJECT_REF.supabase.co`.
- `CONFIG.anonKey` deve ser a anon key de staging.
- `googleWebClientId` só deve mudar se o OAuth de staging exigir outro client id.
- Não coloque service role key no app.
- Ao terminar, reverta manualmente essa alteração local ou deixe-a fora de qualquer commit.

Depois gere os assets Android locais:

```powershell
node scripts/build-android.js
```

Se `node` não estiver no PATH, use o Node empacotado do Codex:

```powershell
& 'C:\Users\DIONES\.cache\codex-runtimes\codex-primary-runtime\dependencies\node\bin\node.exe' scripts\build-android.js
```

## Origem Android e CORS

O projeto Capacitor usa `server.androidScheme = "https"`. A origem esperada do WebView Android é:

```text
https://localhost
```

Para confirmar sem vazar dados sensíveis:

1. Gere um build de teste apontando para staging.
2. Execute a exclusão em um usuário de teste.
3. Se a Edge Function retornar `origin_not_allowed`, leia somente o valor do header `Origin` no log da função.
4. Adicione esse origin em `DELETE_ACCOUNT_ALLOWED_ORIGINS` no projeto staging.
5. Repita o teste.

Não registre Authorization headers, JWTs, anon key, service role key, e-mail do usuário ou payload completo.

## SQL de dados de teste

Use IDs fictícios quando inserir por SQL. Para testar a exclusão real via app, prefira criar os usuários pelo próprio login Google de staging.

```sql
-- Execute em staging. Não execute em produção.
-- Substitua os UUIDs por usuários reais de teste criados em auth.users.

select id, email, created_at
from auth.users
order by created_at desc
limit 10;

-- Exemplo: conferir dados do usuário de teste antes da exclusão.
select * from public.profiles where id = '<TEST_USER_ID>';
select * from public.game_results where user_id = '<TEST_USER_ID>';
select * from private.player_identities where user_id = '<TEST_USER_ID>';
select * from private.ranked_game_sessions where user_id = '<TEST_USER_ID>';
select * from public.challenges where creator_id = '<TEST_USER_ID>';
select * from public.challenge_participants where user_id = '<TEST_USER_ID>';
select * from private.challenge_sessions where user_id = '<TEST_USER_ID>';
select * from private.supporter_entitlements where user_id = '<TEST_USER_ID>';
select * from private.purchases where user_id = '<TEST_USER_ID>';
```

Para criar cenários pelo app:

- Cenário A: usuário com apenas perfil.
- Cenário B: usuário com partidas ranqueadas.
- Cenário C: usuário criador de desafio aberto.
- Cenário D: dois usuários de teste com desafio concluído.
- Cenário E: usuário com identidade Play Games, se disponível no ambiente.
- Cenário F: usuário com entitlement/purchase artificial em staging, se as tabelas existirem.

## SQL antes da exclusão

Rode antes de clicar em "Excluir minha conta":

```sql
with target as (
  select '<TEST_USER_ID>'::uuid as user_id
)
select 'auth.users' as table_name, count(*) from auth.users, target where id = target.user_id
union all
select 'public.profiles', count(*) from public.profiles, target where id = target.user_id
union all
select 'public.game_results', count(*) from public.game_results, target where user_id = target.user_id
union all
select 'private.player_identities', count(*) from private.player_identities, target where user_id = target.user_id
union all
select 'private.ranked_game_sessions', count(*) from private.ranked_game_sessions, target where user_id = target.user_id
union all
select 'public.challenges.creator_id', count(*) from public.challenges, target where creator_id = target.user_id
union all
select 'public.challenge_participants.user_id', count(*) from public.challenge_participants, target where user_id = target.user_id
union all
select 'private.challenge_sessions', count(*) from private.challenge_sessions, target where user_id = target.user_id;
```

Também rode a validação estrutural:

```sql
\i supabase/validation/29_account_deletion_validation.sql
```

## Procedimento de reautenticação

Fluxo esperado no app:

1. Usuário autenticado abre conta/perfil.
2. Toca em "Excluir minha conta".
3. Marca o checkbox de entendimento.
4. Digita a palavra de confirmação traduzida.
5. O app força nova autenticação Google quando necessário.
6. A Edge Function valida a sessão e chama a exclusão do usuário autenticado.
7. O app limpa dados locais vinculados à conta e mostra confirmação.

Erros esperados:

- Sem sessão: app deve pedir login.
- Sessão antiga: backend retorna `reauthentication_required`.
- Conta Google diferente: backend deve recusar ou o app deve manter a conta anterior sem excluir.
- Origin inválido: backend retorna `origin_not_allowed`.
- Falha temporária: backend retorna erro retryable e a conta não fica parcialmente excluída.

## SQL depois da exclusão

Substitua `<TEST_USER_ID>` e rode:

```sql
with target as (
  select '<TEST_USER_ID>'::uuid as user_id
)
select 'auth.users' as table_name, count(*) from auth.users, target where id = target.user_id
union all
select 'public.profiles', count(*) from public.profiles, target where id = target.user_id
union all
select 'public.game_results', count(*) from public.game_results, target where user_id = target.user_id
union all
select 'private.player_identities', count(*) from private.player_identities, target where user_id = target.user_id
union all
select 'private.ranked_game_sessions', count(*) from private.ranked_game_sessions, target where user_id = target.user_id
union all
select 'public.challenges.creator_id', count(*) from public.challenges, target where creator_id = target.user_id
union all
select 'public.challenge_participants.user_id', count(*) from public.challenge_participants, target where user_id = target.user_id
union all
select 'private.challenge_sessions', count(*) from private.challenge_sessions, target where user_id = target.user_id;
```

Resultados esperados:

- `auth.users` deve ser `0`.
- `public.profiles` deve ser `0`.
- `public.game_results` deve ser `0`.
- Identidades privadas do usuário devem ser `0`.
- Sessões privadas do usuário devem ser `0`.
- Desafios abertos próprios devem ser cancelados/removidos conforme migration 29.
- Participações concluídas compartilhadas podem permanecer, mas com `user_id null` e sem dados pessoais.
- Dados mínimos de billing, quando existirem, podem permanecer apenas destacados do usuário.

Valide anonimização de desafios concluídos:

```sql
select id, challenge_id, user_id, role, status, correct_count, error_count, duration_ms
from public.challenge_participants
where challenge_id in (
  select challenge_id
  from public.challenge_participants
  where user_id is null
)
order by challenge_id, created_at;
```

Valide retenção mínima de billing:

```sql
select user_id, deleted_user_hash, account_deleted_at, status, revoked_at, revocation_reason
from private.supporter_entitlements
where deleted_user_hash is not null
order by account_deleted_at desc;

select user_id, deleted_user_hash, account_deleted_at, purchase_token, obfuscated_account_id, raw_response
from private.purchases
where deleted_user_hash is not null
order by account_deleted_at desc;
```

`purchase_token`, `obfuscated_account_id` e `raw_response` devem estar `null` após a exclusão.

## Teste de chamada direta da Edge Function

Somente com JWT de usuário de teste e projeto staging:

```powershell
$headers = @{
  "Authorization" = "Bearer <TEST_USER_ACCESS_TOKEN>"
  "apikey" = "<STAGING_ANON_KEY>"
  "Content-Type" = "application/json"
}

Invoke-RestMethod `
  -Method Post `
  -Uri "https://STAGING_PROJECT_REF.functions.supabase.co/delete-account" `
  -Headers $headers `
  -Body "{}"
```

Não cole o token real em logs, prints ou respostas.

## Limpeza do staging

Depois dos testes, você pode apagar apenas usuários/dados de teste no projeto staging:

```sql
-- Revise os IDs antes. Não rode em produção.
delete from auth.users
where email like '%+flaggame-test%@%'
   or email like '%flaggame.staging.test%';

delete from public.challenges
where created_at < now()
  and creator_id is null
  and share_code like 'FG-%';
```

Se o staging for descartável, a limpeza mais segura é excluir o projeto staging inteiro no painel Supabase depois de exportar evidências dos testes.

## Rollback de staging

Se migration 29 falhar em staging:

1. Pare os testes.
2. Não aplique nada em produção.
3. Exporte o erro completo sem segredos.
4. Recrie o projeto staging limpo.
5. Aplique migrations até 28.
6. Reproduza a falha aplicando apenas `29_account_deletion_backend.sql`.

Não há script de rollback destrutivo para produção porque a mudança mexe em FKs, gatilho de `auth.users` e retenção/anonymização. Para produção, a estratégia deve ser backup verificado, janela de manutenção e plano de restauração do banco/projeto.

## Evidências mínimas para aprovar produção

- Migration 29 aplicada em staging limpo.
- Migration 29 aplicada sobre schema de staging equivalente à versão 28.
- `supabase/validation/29_account_deletion_validation.sql` sem achados negativos.
- Exclusão por app Android staging concluída.
- Exclusão por site staging concluída, se houver site de staging.
- CORS confirmado para `https://localhost` e domínio web real.
- Reautenticação Google exigida quando a sessão está antiga.
- Usuário não aparece no ranking após exclusão.
- Desafios concluídos de outro jogador continuam acessíveis sem dados pessoais do usuário excluído.
- Nenhum log contém JWT, service role, anon key completa, e-mail pessoal ou payload sensível.
