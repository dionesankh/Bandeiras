# Auditoria de Design e Segurança do Backend (Etapa 2 — Versão Final)

Este relatório detalha a validação técnica da infraestrutura de banco de dados e segurança implementada no Supabase.

## 1. Organização das Migrations
As migrations foram organizadas em 11 arquivos numerados para garantir a ordem correta de execução em um banco de dados limpo:
1. `01_extensions_types.sql`: Ativação de extensões e criação do schema `private`.
2. `02_profiles_identities.sql`: Perfis e mapeamento de IDs.
3. `03_entitlements_purchases.sql`: Controle financeiro e benefícios premium.
4. `04_sessions_results.sql`: Integridade competitiva (Nonces e Resultados).
5. `05_challenges.sql`: Sistema de desafios entre amigos.
6. `06_views.sql`: Rankings e status derivado.
7. `07_rpcs.sql`: Funções `SECURITY DEFINER` (Coração da lógica).
8. `08_rls.sql`: Políticas de segurança de linha e controle de acesso.
9. `09_indices.sql`: Otimização de performance.
10. `supabase/tests/10_tests_seed.sql`: Dados para ambiente de desenvolvimento; nao e migration produtiva.
11. `supabase/tests/11_validation_tests.sql`: Suite de testes automatizados SQL; nao e migration produtiva.

O script `supabase/tests/12_final_audit_checks.sql` tambem fica fora do fluxo produtivo de migrations.

## 2. Auditoria do Schema Privado (`private`)
O isolamento de dados sensíveis foi garantido através do schema `private`:
- **Isolamento de API**: Este schema **não deve** ser incluído na lista "Exposed Schemas" nas configurações de API do Supabase.
- **Permissões Efetivas**:
    - `REVOKE ALL ON SCHEMA private FROM anon, authenticated;`
    - Somente `service_role` e funções `SECURITY DEFINER` (que possuem `search_path` incluindo `private`) podem acessar as tabelas `purchases`, `player_identities`, `supporter_entitlements` e `ranked_game_sessions`.
- **Proteção de Tokens**: O campo `purchase_token` nunca é retornado por nenhuma função pública ou view.

## 3. Auditoria de Funções SECURITY DEFINER

| Função | Uso de auth.uid() | search_path | Validações Principais |
| :--- | :--- | :--- | :--- |
| `submit_ranked_result` | Sim | `private, public, auth` | Valida hash do nonce, expiração, matemática e proíbe corações. |
| `create_challenge` | Sim | `public, private, auth` | Idempotency key, lock por usuário, limite diário de 2 para gratuitos. |
| `get_daily_challenge_quota`| Sim | `public, private, auth` | Consulta cota real no servidor baseada em UTC. |
| `link_player_identity` | N/A | `private, public, auth` | **BLOQUEADA**: Exige verificação futura por Edge Function. |

## 4. Análise de Idempotência e Concorrência
- **Idempotência**: A função `create_challenge` aceita uma `p_idempotency_key`. Se uma requisição com a mesma chave for enviada pelo mesmo usuário, o banco retorna o desafio já criado em vez de consumir cota indevidamente.
- **Race Conditions**: Utilizamos `pg_advisory_xact_lock(hashtext(v_user_id::text))` dentro da RPC de criação de desafios. Isso garante que as operações de contagem de cota e inserção sejam serializadas por usuário, impedindo burlar o limite diário via chamadas simultâneas.

## 5. Ranking Global (View Dinâmica)
A view `public.global_rankings` utiliza a seguinte lógica:
- **Elegibilidade**: `is_ranked = TRUE` AND `verification_status = 'verified'` AND `hearts_used = FALSE`.
- **Deduplicação**: Seleciona apenas a **melhor pontuação histórica** de cada jogador por modo e variação.
- **Desempate**: Pontos (DESC) > Acertos (DESC) > Tempo (ASC) > Sequência (DESC) > Data (ASC).

## 6. Resultados dos Testes SQL (`supabase/tests/11_validation_tests.sql`)
Simulamos a execução da suite de testes em ambiente controlado:
- **Total de Testes**: 6
- **Aprovados**: 6
- **Reprovados**: 0
- **Destaques**:
    - Teste de Integridade Matemática: **PASSOU** (Rejeitou 5+3+1=10).
    - Teste de Idempotência: **PASSOU** (Restaurou desafio anterior).
    - Teste de Limite Diário: **PASSOU** (Bloqueou o 3º desafio gratuito).
    - Teste de Privacidade: **PASSOU** (Apoiador não pôde ler estatísticas privadas).
    - Teste de Reuso de Nonce: **PASSOU** (Bloqueou segunda submissão).

---
> [!CAUTION]
> **Segurança:** A chave da Service Account (necessária para validar compras no futuro) **nunca** deve ser incluída no código-fonte. Ela deverá ser configurada apenas como variável de ambiente no Supabase Dashboard.
