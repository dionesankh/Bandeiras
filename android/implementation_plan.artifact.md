# Etapa 3: Autenticação Google, Sessão Supabase e Vinculação com Play Games

Este plano detalha a implementação do sistema de identidade unificada para o Flag Game, permitindo que os jogadores salvem seu progresso na nuvem e participem de rankings globais.

## User Review Required

> [!IMPORTANT]
> **Identidade Principal:** A conta oficial do usuário será gerida pelo Supabase Auth através do Login com Google (ID Token).
>
> [!IMPORTANT]
> **Vinculação de Plataforma:** O Google Play Games será vinculado como uma "identidade de plataforma" usando um processo seguro de *Server Auth Code*, validado por uma Supabase Edge Function.
>
> [!WARNING]
> **Dependência do Supabase:** Será necessário incluir a biblioteca `@supabase/supabase-js`. Como o projeto utiliza cópia direta de arquivos, forneceremos uma versão pré-compilada em `js/libs/supabase.js`.

## Proposed Changes

### [Componente] Build e Configuração

#### [MODIFY] [scripts/build-android.js](file:///D:/Bandeiras/scripts/build-android.js)
- Remover o termo `/supabase/i` da lista `FORBIDDEN_TERMS` para permitir a inclusão da biblioteca e referências no código.

### [Componente] Backend (Supabase)

#### [NEW] `supabase/functions/link-play-games-identity/index.ts`
- Implementar a troca do *Server Auth Code* por tokens do Google.
- Obter o *Player ID* verificado.
- Chamar a RPC interna para vincular o usuário.

### [Componente] Native (Android)

#### [MODIFY] [FlagGamePlayGamesPlugin.java](file:///D:/Bandeiras/plugins/capacitor-play-games/android/src/main/java/app/flaggame/playgames/FlagGamePlayGamesPlugin.java)
- Adicionar o método `@PluginMethod public void requestServerSideAccess(PluginCall call)`.
- Este método utilizará `PlayGames.getGamesSignInClient(activity).requestServerSideAccess(...)` para obter o código de autorização do servidor.

### [Componente] Lógica de Autenticação e Dados (JS)

#### [NEW] `js/supabase-client.js`
- Inicialização centralizada do cliente Supabase.
- Configuração de persistência de sessão compatível com Capacitor.

#### [NEW] `js/auth.js`
- Camada de abstração para Supabase Auth.
- Implementação do fluxo `signInWithGoogle` (Nativo via ID Token).
- Lógica de vinculação com Play Games via Edge Function.
- Gestão de estados: `unauthenticated`, `authenticating`, `authenticated`, `linking`.

#### [NEW] `js/profile-migration.js`
- Lógica para detectar perfis locais (`fgp_...`) e oferecer migração para a nuvem.
- Tratamento de conflitos (Nuvem vs Local) com interface de decisão para o usuário.

### [Componente] Interface (UI)

#### [MODIFY] [game/index.html](file:///D:/Bandeiras/game/index.html)
- Adicionar contêineres para status de conta na tela de Perfil.
- Incluir novos botões: "Entrar com Google", "Sair", "Vincular Play Games".
- Adicionar as tags `<script>` para as novas bibliotecas e módulos.

#### [MODIFY] [js/app.js](file:///D:/Bandeiras/js/app.js)
- Integrar a inicialização do `auth.js` no fluxo de boot do app.
- Reagir a mudanças de sessão para atualizar a interface em tempo real.

## Configurações Necessárias (Google & Supabase)

Para o funcionamento, o usuário deverá configurar:
1.  **Google Cloud Console:**
    *   **Android Client ID:** Vinculado ao SHA-1 do certificado de dev/prod e ao pacote `app.flaggame`.
    *   **Web Client ID:** Necessário para o Supabase Auth e para o *Server Side Access* do Play Games.
2.  **Supabase Dashboard:**
    *   Habilitar provedor Google.
    *   Configurar os Client IDs obtidos.
    *   Definir as URLs de redirecionamento do Capacitor (ex: `app.flaggame://`).

## Verification Plan

### Manual Verification (No Emulador)
1.  **Login Inicial:** Clicar em "Entrar com Google", selecionar conta e verificar se a sessão é criada no Supabase.
2.  **Restauração:** Fechar o app totalmente e reabrir. A sessão deve ser restaurada sem intervenção.
3.  **Vinculação:** Verificar se, após o login, o *Player ID* do Play Games é vinculado corretamente via Edge Function.
4.  **Migração:** Usar um ID `fgp_...` pré-existente e confirmar se o sistema oferece a migração para a nova conta Google.
5.  **Offline:** Desativar a rede e confirmar que o jogo local continua funcionando e que a interface indica "Modo Offline".
