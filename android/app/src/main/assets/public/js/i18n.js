(function (root, factory) {
  if (typeof module === "object" && module.exports) {
    module.exports = factory(root);
  } else {
    // Definir no root (window/globalThis)
    const result = factory(root);
    Object.defineProperties(
      root,
      Object.getOwnPropertyDescriptors(result)
    );
  }
})(typeof globalThis !== "undefined" ? globalThis : window, function (root) {
  "use strict";

  let translations = {};
  let currentLanguage = "en";
  let languageLoadRequestId = 0;

  const fallbackTranslations = {
    en: {
      appName: "Flag Game",
      loading: "Loading...",
      languageSelectLabel: "Select language",
      soundOnLabel: "Enable sounds",
      soundOffLabel: "Disable sounds",
      exit: "← Exit",
      question: "Which country does this flag belong to?",
      points: "points",
      pointCount_one: "{count} point",
      pointCount_other: "{count} points",
      countryCount_one: "{count} country",
      countryCount_other: "{count} countries",
      questionProgress: "Question {current} of {total}",
      resultTotal: "of {total}",
      accuracyValue: "{percent}% accuracy",
      scoreValue: "{label}: {value}",
      score: "Score",
      challengeResultSummary:
        "{correct} correct, {errors} errors, {time}, streak {streak}",
      matchSummaryLabel: "Match summary",
      worldChallengeTitle: "World Challenge",
      worldChallengeModeSubtitle: "Expert Mode",
      worldChallengeTeaser: "Identify all 195 flags before losing your five lives.",
      worldChallengeRestored: "Game restored on this device.",
      worldChallengeStatusLabel: "World Challenge status",
      worldChallengeIdentified: "Countries identified",
      worldChallengeIdentifiedShort: "Identified",
      worldChallengeQuestion: "Which country does this flag belong to?",
      worldChallengeOptionsLabel: "Answer choices",
      worldChallengeSkip: "I don't know",
      worldChallengeLivesRemaining: "Lives remaining: {count} of {total}",
      worldChallengeFeedbackCorrect: "Correct! You kept your lives.",
      worldChallengeFeedbackIncorrect: "Incorrect. The correct answer is {country}. You lost 1 life.",
      worldChallengeFeedbackSkip: "Skipped. The correct answer is {country}. You lost 1 life.",
      worldChallengeFinished: "World Challenge complete",
      worldChallengeFinishedSubtitle: "You correctly identified all 195 flags.",
      worldChallengeGameOver: "Game over",
      worldChallengeGameOverSubtitle: "You identified {count} of {total} countries.",
      worldChallengeNoRecord: "No personal record yet",
      worldChallengeRecordPreview: "Record: {progress}/{total} • best time: {bestTime}",
      worldChallengeFinishButton: "View result",
      worldChallengeContinuationUsed: "Continuation",
      worldChallengeRankingEligibility: "Future ranking",
      worldChallengeRankingEligible: "Eligible",
      worldChallengeRankingNotEligible: "Not eligible",
      worldChallengeRankingUnavailable: "Unavailable",
      worldChallengeYes: "Yes",
      worldChallengeNo: "No",
      rankingsTitle: "Global rankings",
      myProfile: "My profile",
      account: "My account",
      privacySettings: "Profile privacy",
      showDetailedStats: "Show detailed statistics",
      showRecentActivity: "Show recent activity",
      saveNickname: "Save Name",
      logout: "Log out",
      confirmLogout: "Do you really want to log out?",
      nameSaved: "Name saved!",
      connectionError: "Connection error",
      noInternet: "No internet connection.",
      rankingAuthRequired: "Sign in again to access the ranking.",
      rankingLoadError: "Could not load the ranking.",
      noResults: "No results found.",
      noResultsRanking: "No results in this ranking yet.",
      loadMore: "Load more",
      you: "You",
      resultRegistered: "Result registered in ranking!",
      resultNotValidated: "Could not validate for ranking.",
      rankedIndicator: "Ranked",
      rankedMatchToggle: "Count for ranking",
      loginSuccess: "Logged in successfully!",
      loginError: "Login error: ",
      androidDisclosureMessage: "Compete on the global leaderboard and keep your progress saved in the Android app.",
      androidDisclosureInstall: "Install Android app",
      cloudSaveLocal: "Saved locally",
      cloudSaveSyncing: "Syncing",
      cloudSaveSynced: "Saved with Google Play",
      cloudSavePending: "Sync pending",
      cloudSaveError: "Sync error",
      playGamesStatusTitle: "Google Play Games",
      playGamesStatusChecking: "Checking status...",
      playGamesStatusAuthenticated: "Connected to Google Play Games",
      playGamesStatusUnavailable: "Google Play Games unavailable",
      playGamesStatusPending: "Play Games sync pending",
      playGamesStatusSubmitted: "Play Games updated",
      openPlayGamesLeaderboards: "Open leaderboards",
      openPlayGamesAchievements: "Open achievements",
      onboardingLoginDesc: "Connect your account to save your progress and join the global ranking.",
      onboardingFinish: "Start",
      challengeFriendsDescription: "Enter the code you received to play a friend's challenge.",
      challengeCodePlaceholder: "FG-XXXXXXXX",
      challengeFriendAction: "Challenge a friend",
      shareChallenge: "Share challenge",
      copyCode: "Copy code",
      creatingChallenge: "Creating challenge...",
      challengeCreated: "Challenge code created.",
      challengeCreateError: "Could not create the challenge.",
      challengeLoginRequired: "Sign in to use challenges.",
      challengeNetworkError: "Connection failed. Try again without clearing the code.",
      challengeUnavailable: "This challenge is unavailable.",
      challengeBaseRequired: "This match cannot be turned into a challenge. Start a new match while connected to the internet.",
      challengeRankedResultMissing: "The ranked result has not been confirmed yet. Wait a few seconds and try again.",
      challengeRankedSequenceMissing: "This ranked match does not have a protected sequence. Start a new ranked match while connected to the internet.",
      challengeRankedSubmitFailed: "The ranked result was not validated, so the challenge cannot be created.",
      challengeWaitingRankedSubmit: "Waiting for ranking validation...",
      challengeUnsupportedMode: "This mode cannot be challenged yet.",
      challengeAlreadyUsed: "This challenge has already been used.",
      challengeExpired: "This challenge has expired.",
      challengeValid: "Challenge code accepted.",
      validatingChallenge: "Validating code...",
      challengeResultSubmitted: "Challenge result sent.",
      challengeResultSubmitError: "Could not send the challenge result.",
      challengeShareError: "Could not share right now.",
      challengeCopyError: "Could not copy right now.",
      bestSequence: "Best sequence",
      correctAnswers: "Correct",
      timeLabel: "Time",
      playerFallbackName: "Player",
      profileSaveError: "Could not save right now.",
      nicknameTooShort: "Use at least 3 characters.",
      loginWithGoogle: "Sign in with Google",
      onboardingLoginTitle: "Welcome!",
      onboardingSkip: "Skip for now",
      onboardingLanguageTitle: "Choose language",
      onboardingLanguageDesc: "Select your preferred language to play.",
      onboardingNicknameDesc: "Choose your name for the global ranking.",
      createProfileTitle: "Create profile",
      openMenu: "Open menu",
      close: "Close",
      perfectResult: "Perfect!",
      greatResult: "Well done!",
      nicknamePlaceholder: "Nickname",
      continue: "Continue",
      cancel: "Cancel",
      accountSecurityTitle: "Account and security",
      accountDeleteProfileHint: "Delete your account and personal data linked to Flag Game.",
      deleteMyAccount: "Delete my account",
      accountDeletionTitle: "Account deletion",
      accountDeleteIrreversible: "This action is irreversible.",
      accountDeleteDataRemoved: "Your profile, login, ranking, results, and personal links will be deleted or anonymized.",
      accountDeleteRecordsRetained: "Minimal transaction records may be kept for support, fraud prevention, chargebacks, and legal obligations.",
      accountDeleteLocalProgressRemoved: "Local progress linked to the account will also be removed from this device.",
      accountDeleteUnderstand: "I confirm that I understand this action cannot be undone.",
      accountDeleteTypeWord: "Type the confirmation word",
      accountDeleteConfirmWord: "DELETE",
      accountDeleteConfirmPlaceholder: "Type the word",
      accountDeleteReauthenticate: "Choose the same Google account to continue.",
      accountDeleteChooseSameGoogle: "Choose the same Google account used in this profile.",
      accountDeleteDeleting: "Deleting your account...",
      accountDeleted: "Your account was deleted.",
      accountDeleteFailed: "Could not delete the account.",
      accountDeleteSessionExpired: "Your session expired. Sign in again and try later.",
      accountDeleteConnectionUnavailable: "Connection failed. Check your internet and try again.",
      accountDeleteTryAgain: "Could not delete the account. Please try again.",
      accountDeleteIncorrectConfirmation: "Complete the confirmation fields before continuing.",
      accountDeleteCancelled: "Google reauthentication was cancelled.",
      accountDeleteTemporaryFailure: "The account could not be deleted now. Please try again later.",
      accountDeleteUnexpected: "Unexpected response while deleting the account.",
      accountDeleteInProgress: "Account deletion is already in progress.",
      accountDeleteGoogleUnavailable: "Google authentication is not available on this device.",
      accountDeleteBackendReauthRequired: "For security, sign in with Google again and retry the deletion."
    },
    "pt-BR": {
      appName: "Flag Game",
      loading: "Carregando...",
      languageSelectLabel: "Selecionar idioma",
      soundOnLabel: "Ativar sons",
      soundOffLabel: "Desativar sons",
      exit: "← Sair",
      question: "De qual país é esta bandeira?",
      points: "pontos",
      pointCount_one: "{count} ponto",
      pointCount_other: "{count} pontos",
      countryCount_one: "{count} país",
      countryCount_other: "{count} países",
      questionProgress: "Pergunta {current} de {total}",
      resultTotal: "de {total}",
      accuracyValue: "{percent}% de acertos",
      scoreValue: "{label}: {value}",
      score: "Pontuação",
      challengeResultSummary:
        "{correct} acertos, {errors} erros, {time}, sequência {streak}",
      matchSummaryLabel: "Resumo da partida",
      worldChallengeTitle: "Desafio Mundial",
      worldChallengeModeSubtitle: "Modo Experiente",
      worldChallengeTeaser: "Identifique as 195 bandeiras antes de perder suas cinco vidas.",
      worldChallengeRestored: "Partida restaurada neste dispositivo.",
      worldChallengeStatusLabel: "Status do Desafio Mundial",
      worldChallengeIdentified: "Países identificados",
      worldChallengeIdentifiedShort: "Identificados",
      worldChallengeQuestion: "A qual país pertence esta bandeira?",
      worldChallengeOptionsLabel: "Alternativas de resposta",
      worldChallengeSkip: "Não sei",
      worldChallengeLivesRemaining: "Vidas restantes: {count} de {total}",
      worldChallengeFeedbackCorrect: "Correto! Você manteve suas vidas.",
      worldChallengeFeedbackIncorrect: "Errado. A resposta correta é {country}. Você perdeu 1 vida.",
      worldChallengeFeedbackSkip: "Pulado. A resposta correta é {country}. Você perdeu 1 vida.",
      worldChallengeFinished: "Desafio Mundial concluído",
      worldChallengeFinishedSubtitle: "Você identificou corretamente as 195 bandeiras.",
      worldChallengeGameOver: "Fim de jogo",
      worldChallengeGameOverSubtitle: "Você identificou {count} de {total} países.",
      worldChallengeNoRecord: "Nenhum recorde pessoal ainda",
      worldChallengeRecordPreview: "Recorde: {progress}/{total} • melhor tempo: {bestTime}",
      worldChallengeFinishButton: "Ver resultado",
      worldChallengeContinuationUsed: "Continuação",
      worldChallengeRankingEligibility: "Ranking futuro",
      worldChallengeRankingEligible: "Elegível",
      worldChallengeRankingNotEligible: "Não elegível",
      worldChallengeRankingUnavailable: "Indisponível",
      worldChallengeYes: "Sim",
      worldChallengeNo: "Não",
      rankingsTitle: "Rankings globais",
      myProfile: "Meu perfil",
      account: "Minha conta",
      privacySettings: "Privacidade do perfil",
      showDetailedStats: "Mostrar estatísticas detalhadas",
      showRecentActivity: "Mostrar atividade recente",
      saveNickname: "Salvar nome",
      logout: "Sair da conta",
      confirmLogout: "Deseja realmente sair?",
      nameSaved: "Nome salvo!",
      connectionError: "Erro de conexão",
      noInternet: "Sem conexão com a internet.",
      rankingAuthRequired: "Entre novamente para acessar o ranking.",
      rankingLoadError: "Não foi possível carregar o ranking.",
      noResults: "Nenhum resultado encontrado.",
      noResultsRanking: "Nenhum resultado neste ranking ainda.",
      loadMore: "Carregar mais",
      you: "Você",
      resultRegistered: "Resultado registrado no ranking!",
      resultNotValidated: "Não foi possível validar para o ranking.",
      rankedIndicator: "Classificada",
      rankedMatchToggle: "Valer para o ranking",
      loginSuccess: "Logado com sucesso!",
      loginError: "Erro no login: ",
      androidDisclosureMessage: "Dispute o ranking global e mantenha seu progresso salvo no aplicativo Android.",
      androidDisclosureInstall: "Instalar aplicativo Android",
      cloudSaveLocal: "Salvo localmente",
      cloudSaveSyncing: "Sincronizando",
      cloudSaveSynced: "Salvo com Google Play",
      cloudSavePending: "Sincronização pendente",
      cloudSaveError: "Erro de sincronização",
      playGamesStatusTitle: "Google Play Games",
      playGamesStatusChecking: "Verificando status...",
      playGamesStatusAuthenticated: "Conectado ao Google Play Games",
      playGamesStatusUnavailable: "Google Play Games indisponível",
      playGamesStatusPending: "Sincronização do Play Games pendente",
      playGamesStatusSubmitted: "Play Games atualizado",
      openPlayGamesLeaderboards: "Abrir ranking",
      openPlayGamesAchievements: "Abrir conquistas",
      onboardingLoginDesc: "Conecte sua conta para salvar seu progresso e entrar no ranking global.",
      onboardingFinish: "Começar",
      challengeFriendsDescription: "Insira o código recebido para jogar o desafio de um amigo.",
      challengeCodePlaceholder: "FG-XXXXXXXX",
      challengeRankedResultMissing: "A partida classificada nao possui confirmacao no ranking. Aguarde alguns segundos e tente novamente.",
      challengeRankedSequenceMissing: "Esta partida classificada não possui uma sequência protegida. Inicie uma nova partida classificada conectado à internet.",
      challengeRankedSubmitFailed: "O resultado classificado nao foi validado. Nao foi possivel criar o desafio.",
      challengeWaitingRankedSubmit: "Aguardando validacao do ranking...",
      challengeFriendAction: "Desafiar um amigo",
      shareChallenge: "Compartilhar desafio",
      copyCode: "Copiar código",
      creatingChallenge: "Criando desafio...",
      challengeCreated: "Código do desafio criado.",
      challengeCreateError: "Não foi possível criar o desafio.",
      challengeLoginRequired: "Entre com sua conta para usar desafios.",
      challengeNetworkError: "Falha de conexão. Tente novamente sem apagar o código.",
      challengeUnavailable: "Este desafio está indisponível.",
      challengeUnsupportedMode: "Este modo ainda não pode ser desafiado.",
      challengeAlreadyUsed: "Este desafio já foi utilizado.",
      challengeExpired: "Este desafio expirou.",
      challengeValid: "Código válido.",
      validatingChallenge: "Validando código...",
      challengeResultSubmitted: "Resultado do desafio enviado.",
      challengeResultSubmitError: "Não foi possível enviar o resultado do desafio.",
      challengeShareError: "Não foi possível compartilhar agora.",
      challengeCopyError: "Não foi possível copiar agora.",
      bestSequence: "Melhor sequência",
      correctAnswers: "Acertos",
      timeLabel: "Tempo",
      playerFallbackName: "Jogador",
      profileSaveError: "Não foi possível salvar agora.",
      nicknameTooShort: "Use pelo menos 3 caracteres.",
      loginWithGoogle: "Entrar com Google",
      onboardingLoginTitle: "Boas-vindas!",
      onboardingSkip: "Pular por agora",
      onboardingLanguageTitle: "Escolha o idioma",
      onboardingLanguageDesc: "Selecione o idioma preferido para jogar.",
      onboardingNicknameDesc: "Escolha seu nome para o ranking global.",
      createProfileTitle: "Criar perfil",
      openMenu: "Abrir menu",
      close: "Fechar",
      perfectResult: "Perfeito!",
      greatResult: "Muito bem!",
      nicknamePlaceholder: "Apelido",
      continue: "Continuar",
      cancel: "Cancelar",
      accountSecurityTitle: "Conta e segurança",
      accountDeleteProfileHint: "Exclua sua conta e os dados pessoais vinculados ao Flag Game.",
      deleteMyAccount: "Excluir minha conta",
      accountDeletionTitle: "Exclusão de conta",
      accountDeleteIrreversible: "Esta ação é irreversível.",
      accountDeleteDataRemoved: "Seu perfil, login, ranking, resultados e vínculos pessoais serão excluídos ou anonimizados.",
      accountDeleteRecordsRetained: "Registros mínimos de transação podem ser preservados para suporte, prevenção de fraude, estorno e obrigações legais.",
      accountDeleteLocalProgressRemoved: "O progresso local vinculado à conta também será removido deste dispositivo.",
      accountDeleteUnderstand: "Confirmo que compreendo que esta ação não pode ser desfeita.",
      accountDeleteTypeWord: "Digite a palavra de confirmação",
      accountDeleteConfirmWord: "EXCLUIR",
      accountDeleteConfirmPlaceholder: "Digite a palavra",
      accountDeleteReauthenticate: "Escolha a mesma Conta Google para continuar.",
      accountDeleteChooseSameGoogle: "Escolha a mesma Conta Google usada neste perfil.",
      accountDeleteDeleting: "Excluindo sua conta...",
      accountDeleted: "Sua conta foi excluída.",
      accountDeleteFailed: "Não foi possível excluir a conta.",
      accountDeleteSessionExpired: "Sua sessão expirou. Entre novamente e tente depois.",
      accountDeleteConnectionUnavailable: "Falha de conexão. Verifique sua internet e tente novamente.",
      accountDeleteTryAgain: "Não foi possível excluir a conta. Tente novamente.",
      accountDeleteIncorrectConfirmation: "Complete os campos de confirmação antes de continuar.",
      accountDeleteCancelled: "A reautenticação do Google foi cancelada.",
      accountDeleteTemporaryFailure: "A conta não pôde ser excluída agora. Tente novamente mais tarde.",
      accountDeleteUnexpected: "Resposta inesperada ao excluir a conta.",
      accountDeleteInProgress: "A exclusão da conta já está em andamento.",
      accountDeleteGoogleUnavailable: "A autenticação Google não está disponível neste dispositivo.",
      accountDeleteBackendReauthRequired: "Por segurança, entre com Google novamente e repita a exclusão."
    }
  };

  const supportedLanguages = [
    "pt-BR",
    "en",
    "es",
    "fr",
    "de",
    "it",
    "nl",
    "pl",
    "ru",
    "uk",
    "tr",
    "ar",
    "hi",
    "bn",
    "zh-CN",
    "ja",
    "ko",
    "id",
    "vi",
    "th"
  ];

  const languageOptions = {
    "pt-BR": { label: "Português", file: "pt-BR.json" },
    en: { label: "English", file: "en.json" },
    es: { label: "Español", file: "es.json" },
    fr: { label: "Français", file: "fr.json" },
    de: { label: "Deutsch", file: "de.json" },
    it: { label: "Italiano", file: "it.json" },
    nl: { label: "Nederlands", file: "nl.json" },
    pl: { label: "Polski", file: "pl.json" },
    ru: { label: "Русский", file: "ru.json" },
    uk: { label: "Українська", file: "uk.json" },
    tr: { label: "Türkçe", file: "tr.json" },
    ar: { label: "العربية", file: "ar.json" },
    hi: { label: "हिन्दी", file: "hi.json" },
    bn: { label: "বাংলা", file: "bn.json" },
    "zh-CN": { label: "中文", file: "zh-CN.json" },
    ja: { label: "日本語", file: "ja.json" },
    ko: { label: "한국어", file: "ko.json" },
    id: { label: "Indonesia", file: "id.json" },
    vi: { label: "Tiếng Việt", file: "vi.json" },
    th: { label: "ไทย", file: "th.json" }
  };

  function normalizeLanguage(language) {
    const value = String(language || "")
      .trim()
      .replace("_", "-");

    if (!value) {
      return "";
    }

    if (supportedLanguages.includes(value)) {
      return value;
    }

    const lowerValue = value.toLowerCase();
    const exactMatch = supportedLanguages.find(
      supported => supported.toLowerCase() === lowerValue
    );

    if (exactMatch) {
      return exactMatch;
    }

    const shortLanguage = lowerValue.split("-")[0];

    if (shortLanguage === "pt") {
      return "pt-BR";
    }

    if (shortLanguage === "zh") {
      return "zh-CN";
    }

    return supportedLanguages.includes(shortLanguage)
      ? shortLanguage
      : "";
  }

  function detectBrowserLanguage() {
    let browserLanguage = navigator.language || "en";
    return normalizeLanguage(browserLanguage) || "en";
  }

  function getRuntimeAssetUrl(path) {
    if (
      typeof chrome !== "undefined" &&
      chrome.runtime &&
      typeof chrome.runtime.getURL === "function"
    ) {
      return chrome.runtime.getURL(path);
    }

    if (
      typeof browser !== "undefined" &&
      browser.runtime &&
      typeof browser.runtime.getURL === "function"
    ) {
      return browser.runtime.getURL(path);
    }

    return "";
  }

  function getTranslationUrls(language) {
    const option = languageOptions[language];
    const file = option ? option.file : `${language}.json`;
    const path = `locales/${file}`;
    const urls = [
      getRuntimeAssetUrl(path),
      new URL(path, document.baseURI).href,
      path
    ].filter(Boolean);

    return [...new Set(urls)];
  }

  async function fetchTranslations(language) {
    if (
      typeof window !== "undefined" &&
      window.FlagGameLocales &&
      window.FlagGameLocales[language]
    ) {
      return window.FlagGameLocales[language];
    }

    let lastError = null;

    for (const url of getTranslationUrls(language)) {
      try {
        const response = await fetch(url);

        if (!response.ok) {
          throw new Error(
            `Não foi possível carregar ${url}: ${response.status}`
          );
        }

        return response.json();

      } catch (error) {
        lastError = error;
      }
    }

    throw lastError || new Error("Não foi possível carregar o idioma.");
  }

  function getStoredLanguage() {
    if (root.FlagGameStorage) {
      return root.FlagGameStorage.getString("language", "");
    }

    return localStorage.getItem("language") || "";
  }

  function setStoredLanguage(language) {
    if (root.FlagGameStorage) {
      root.FlagGameStorage.setString("language", language);
      return;
    }

    localStorage.setItem("language", language);
  }

  function finishLanguageLoad(language) {
    setStoredLanguage(language);

    document.documentElement.lang = language;
    document.documentElement.dir =
      language === "ar" ? "rtl" : "ltr";

    applyTranslations();

    document
      .querySelectorAll("#profile-idioma, #onboarding-idioma")
      .forEach(languageSelect => {
        languageSelect.value = language;
      });
  }

  async function loadLanguage(language) {
    const requestId = ++languageLoadRequestId;
    const normalizedLanguage =
      normalizeLanguage(language) || detectBrowserLanguage();

    currentLanguage = normalizedLanguage;

    try {
      const loadedTranslations =
        await fetchTranslations(normalizedLanguage);

      if (requestId !== languageLoadRequestId) {
        return;
      }

      translations = loadedTranslations;
      finishLanguageLoad(normalizedLanguage);

    } catch (error) {
      if (requestId !== languageLoadRequestId) {
        return;
      }

      console.error("Erro ao carregar idioma:", error);
      translations =
        fallbackTranslations[normalizedLanguage] ||
        fallbackTranslations.en;
      finishLanguageLoad(normalizedLanguage);
    }
  }

  function interpolate(template, variables) {
    if (!variables) {
      return template;
    }

    return String(template).replace(
      /\{(\w+)\}/g,
      (match, name) => (
        Object.prototype.hasOwnProperty.call(variables, name)
          ? String(variables[name])
          : match
      )
    );
  }

  function hasTranslation(key) {
    return (
      Object.prototype.hasOwnProperty.call(translations, key) ||
      Object.prototype.hasOwnProperty.call(
        fallbackTranslations[currentLanguage] || {},
        key
      ) ||
      Object.prototype.hasOwnProperty.call(fallbackTranslations.en, key)
    );
  }

  function t(key, variables) {
    const languageFallback =
      fallbackTranslations[currentLanguage] || {};
    const template = Object.prototype.hasOwnProperty.call(
      translations,
      key
    )
      ? translations[key]
      : Object.prototype.hasOwnProperty.call(languageFallback, key)
        ? languageFallback[key]
        : Object.prototype.hasOwnProperty.call(fallbackTranslations.en, key)
          ? fallbackTranslations.en[key]
          : key;

    return interpolate(template, variables);
  }

  function tPlural(baseKey, count, variables) {
    const category = Number(count) === 1 ? "one" : "other";
    const pluralKey = `${baseKey}_${category}`;
    const fallbackKey = `${baseKey}_other`;
    const oneKey = `${baseKey}_one`;
    const key = hasTranslation(pluralKey)
      ? pluralKey
      : category === "one" && hasTranslation(oneKey)
        ? oneKey
        : fallbackKey;

    return t(key, {
      count,
      ...(variables || {})
    });
  }

  function getCountryName(countryCode) {
    const code = String(countryCode || "").toUpperCase();
    if (code === "VA" && currentLanguage === "pt-BR") {
      return "Vaticano";
    }

    try {
      const displayNames = new Intl.DisplayNames(
        [currentLanguage],
        { type: "region" }
      );

      return displayNames.of(code);

    } catch (error) {
      const country = (root.countries || []).find(
        pais => pais.code === code
      );

      return country ? country.name : code;
    }
  }

  function applyTranslations() {
    document
      .querySelectorAll("[data-i18n]")
      .forEach(element => {
        const key = element.dataset.i18n;

        if (hasTranslation(key)) {
          element.textContent = t(key);
        }
      });

    document
      .querySelectorAll("[data-i18n-placeholder]")
      .forEach(element => {
        const key = element.dataset.i18nPlaceholder;

        if (hasTranslation(key)) {
          element.placeholder = t(key);
        }
      });

    document
      .querySelectorAll("[data-i18n-aria-label]")
      .forEach(element => {
        const key = element.dataset.i18nAriaLabel;

        if (hasTranslation(key)) {
          element.setAttribute("aria-label", t(key));
        }
      });

    document
      .querySelectorAll("[data-i18n-title]")
      .forEach(element => {
        const key = element.dataset.i18nTitle;

        if (hasTranslation(key)) {
          element.title = t(key);
        }
      });

    document
      .querySelectorAll("[data-i18n-alt]")
      .forEach(element => {
        const key = element.dataset.i18nAlt;

        if (hasTranslation(key)) {
          element.alt = t(key);
        }
      });

    if (hasTranslation("appName")) {
      document.title = t("appName");
    }

    if (typeof root.atualizarContadoresContinentes === "function") {
      root.atualizarContadoresContinentes();
    }

    // Adapt logic for dynamic points if present
    const pontosTexto = document.querySelector("#pontos-valor");
    if (pontosTexto && typeof root.pontos !== "undefined") {
      pontosTexto.textContent = tPlural("pointCount", root.pontos);
    }

    document
      .querySelectorAll(".alternativa")
      .forEach(botao => {
        const countryCode =
          botao.dataset.countryCode;

        if (countryCode) {
          botao.textContent =
            getCountryName(countryCode);
        }
      });

    if (typeof root.atualizarBotaoSom === "function") {
      root.atualizarBotaoSom();
    }

    if (typeof root.refreshDynamicTranslations === "function") {
      root.refreshDynamicTranslations();
    }
  }

  async function initializeLanguage() {
    const savedLanguage = getStoredLanguage();
    const initialLanguage =
      normalizeLanguage(savedLanguage) || detectBrowserLanguage();

    await loadLanguage(initialLanguage);
  }

  return {
    initializeLanguage,
    loadLanguage,
    t,
    tPlural,
    getCountryName,
    languageOptions,
    supportedLanguages,
    detectBrowserLanguage,
    applyTranslations,
    get currentLanguage() { return currentLanguage; }
  };
});
