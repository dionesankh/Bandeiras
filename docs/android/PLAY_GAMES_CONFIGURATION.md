# Google Play Games Services v2

Este projeto integra somente a base estrutural de autenticacao do Google Play Games Services v2 no Android Capacitor.

Nao estao implementados nesta etapa:

- Saved Games
- placares
- conquistas
- Billing
- conta propria do jogo

## Dependencia Android

A dependencia usada deve permanecer com versao exata, sem `+`:

```gradle
implementation 'com.google.android.gms:play-services-games-v2:21.0.0'
```

Essa versao foi conferida na tabela oficial atual de dependencias do Google Play services.

## Configuracao local

O plugin Android declara o `APP_ID` documentado pelo Play Games Services:

```xml
<meta-data
    android:name="com.google.android.gms.games.APP_ID"
    android:value="@string/game_services_project_id" />
```

O arquivo `plugins/capacitor-play-games/android/src/main/res/values/play_games_ids.xml` contem placeholders evidentes. Substitua apenas depois de criar e publicar a configuracao no Play Console:

```xml
<string name="game_services_project_id" translatable="false">&lt;PLAY_GAMES_PROJECT_ID&gt;</string>
```

Enquanto esse valor continuar como placeholder, as chamadas nativas que dependem da configuracao retornam `configuration_pending` e o jogo deve seguir carregando.

## Checklist Play Console

- Criar o jogo em Play Console > Play Games Services.
- Vincular o jogo ao aplicativo Android correto.
- Confirmar o package name: `app.flaggame`.
- Adicionar o SHA-1 debug do keystore usado no build local.
- Adicionar futuramente o SHA-1 da chave de upload/release antes de publicar builds de teste/release.
- Adicionar contas de teste em Play Games Services > Testers.
- Confirmar ou vincular o projeto do Google Cloud associado ao jogo.
- Publicar a configuracao do Play Games Services no Play Console.
- Copiar para o projeto apenas os IDs oficiais gerados pelo Play Console.

## IDs Pendentes

Copiar do Play Console quando existirem:

- `game_services_project_id`
- IDs de leaderboard, somente quando placares forem implementados
- IDs de achievement, somente quando conquistas forem implementadas
- OAuth client IDs, somente se uma etapa futura implementar acesso server-side documentado

Nao inclua credenciais reais neste repositorio.

## Plugin Capacitor

Metodos validados nesta etapa:

- `isAvailable()`
- `getAuthenticationStatus()`
- `requestAuthenticationRetry()`
- `getPlayerSummary()`

Todos retornam objetos estruturados e serializaveis com campos como `available`, `configured`, `authenticated`, `status`, `player` e `error`.

Metodos futuros continuam presentes por compatibilidade, mas bloqueados:

- `syncSavedGame()`
- `commitSavedGame()`
- `submitLeaderboardScore()`
- `unlockAchievement()`
- `openLeaderboards()`
- `openAchievements()`

Esses metodos retornam `not_configured`/`*_not_implemented` e nao chamam APIs nativas de Saved Games, placares ou conquistas.

## Testes em Aparelho Real

Exigem aparelho Android ou emulador com Google APIs/Google Play Store:

- autenticacao automatica ao abrir o jogo;
- leitura de `getAuthenticationStatus()` com conta de teste cadastrada;
- fluxo de `requestAuthenticationRetry()` depois de falha ou conta nao autenticada;
- retorno de `getPlayerSummary()` para jogador autenticado;
- comportamento quando Google Play services esta indisponivel, desatualizado ou sem conta Play Games.
