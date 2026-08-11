# Android project setup

## Estado auditado

- Repositorio: `D:\Bandeiras`.
- `android/` nao existia antes desta tarefa.
- `package.json`, `package-lock.json` e `capacitor.config.*` tambem nao existiam antes desta tarefa.
- `game/index.html` e a fonte funcional do jogo.
- Homepage fica separada na raiz e em `homepage/`; ela nao e copiada para o build Android.
- Plugin local encontrado em `plugins/capacitor-play-games`.

## Versoes encontradas

- Node.js: `v24.18.0`.
- npm: `11.16.0` via `npm.cmd`.
- Java: OpenJDK `21.0.10`.
- Capacitor CLI/Core/Android: `8.4.2`.
- Gradle wrapper: `8.14.3`.
- Android Gradle Plugin: `8.13.0`.
- Android SDK local: `C:\Users\DDD\AppData\Local\Android\Sdk`.
- SDK platforms: `android-36`, `android-36.1`.
- Build tools: `35.0.0`, `36.0.0`.
- `ANDROID_HOME`: nao estava definido no ambiente; os builds locais foram executados definindo a variavel apenas no processo.

## Identidade do app

- Nome publico: `Flag Game`.
- `appId` / `applicationId`: `app.flaggame`.
- Origem da decisao: nao havia `applicationId` documentado no checkout; o namespace do plugin local ja usava `app.flaggame.playgames`, entao o app principal usa o prefixo estavel `app.flaggame`.
- Namespace Android: `app.flaggame`.
- `versionCode`: `1`.
- `versionName`: `1.1.0`.
- `minSdk`: `24`.
- `targetSdk`: `36`.

## WebDir Android

- `webDir`: `dist/android`.
- Script: `npm run build:android`.
- Entrada gerada: `dist/android/index.html`.
- Origem da entrada: `game/index.html`.
- O script ajusta apenas o `<base href>` para `./` no arquivo gerado, preservando a fonte unica em `game/index.html`.
- Copia somente `assets/flags`, `assets/images`, `css`, `js` e `locales`.
- Valida 20 arquivos de idioma.
- Bloqueia referencias a Pix, Ko-fi, doacao, donation, Google Play Billing, purchase e Supabase no pacote web Android.

## Comandos de build

```powershell
npm.cmd install
npm.cmd run build:android
npx.cmd cap sync android
$env:ANDROID_HOME='C:\Users\DDD\AppData\Local\Android\Sdk'; .\gradlew.bat assembleDebug
```

O comando Gradle deve ser executado dentro de `android/`.

## APK debug

- Caminho: `D:\Bandeiras\android\app\build\outputs\apk\debug\app-debug.apk`.

## Android Studio

Abra a pasta:

```text
D:\Bandeiras\android
```

Depois sincronize o Gradle pelo Android Studio. Se o SDK nao for detectado automaticamente, configure o SDK local pela IDE ou crie um `local.properties` local nao versionado apontando para o SDK.

## Arquivos que nao devem ser versionados

- `android/.gradle/`.
- `android/**/build/`.
- `android/local.properties`.
- APKs e AABs.
- keystores e arquivos de assinatura.
- caches e arquivos locais do Android Studio.
- `node_modules/`.
- `dist/`.
- `google-services.json`.

## Plugin Capacitor local

- Pacote: `@flaggame/capacitor-play-games`.
- Classe Android: `app.flaggame.playgames.FlagGamePlayGamesPlugin`.
- Nome Capacitor: `FlagGamePlayGames`.
- O sync Android registrou o plugin em `capacitor.plugins.json`.
- O plugin compila com Capacitor `8.4.2`.
- IDs reais de Play Games continuam vazios/placeholders; nenhum ID de Play Console foi inventado.

## Pendencias Google Play Games

- Criar/vincular o app na Play Console.
- Confirmar `app.flaggame` na Play Console.
- Configurar SHA-1 de debug e release.
- Ativar Saved Games.
- Criar leaderboards e achievements reais.
- Preencher recursos XML com IDs reais da Play Console.
- Testar em dispositivo/emulador com Google Play services e conta testadora.

## Limitacoes de teste

- O build debug compila e gera APK.
- Google Play Games nao foi validado funcionalmente contra a Play Console.
- Nenhuma chave de assinatura, senha, Billing, compra, doacao, Firebase novo ou Supabase novo foi configurado.
