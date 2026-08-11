(function() {
  "use strict";

  const root =
    typeof globalThis !== "undefined"
      ? globalThis
      : typeof window !== "undefined"
        ? window
        : {};

  // --- UI Elements ---
  const get = (id) => document.querySelector(id);
  const getAll = (sel) => document.querySelectorAll(sel);

  // Local helpers for i18n to prevent ReferenceErrors if not yet loaded
  const t = (key, variables) => (root.t ? root.t(key, variables) : key);
  const getCountryName = (code) => (root.getCountryName ? root.getCountryName(code) : code);
  const tFallback = (key, fallback, variables) => {
    const translated = root.t ? root.t(key, variables) : "";
    return translated && translated !== key ? translated : fallback;
  };

  // Initialize controllers lazily or safely
  const screens = {
    inicio: get(".inicio"),
    continentes: get("#tela-continentes"),
    jogo: get("#tela-jogo"),
    mundo: get("#tela-mundo"),
    amigos: get("#tela-desafio-amigos"),
    resultado: get("#tela-resultado"),
    profile: get("#tela-profile"),
    rankings: get("#tela-rankings")
  };

  const ctrls = {
    logo: get("#logo-home-link"),
    somJogo: get("#btn-som-jogo"),
    menuBtn: get("#btn-menu"),
    navMenu: get("#nav-menu"),
    navBackdrop: get("#nav-backdrop"),
    menuUserInfo: get("#menu-user-info"),
    menuLogout: get("#menu-btn-logout"),
    appSplash: get("#appSplash"),
    rankingMode: get("#ranking-filter-mode"),
    rankingVar: get("#ranking-filter-variation"),
    rankingList: get("#ranking-list"),
    rankingUser: get("#ranking-user-pos"),
    loadMoreRankings: get("#btn-load-more-rankings"),
    toggleRankedCont: get("#toggle-ranked-continents"),
    toggleRankedWorld: get("#toggle-ranked-world"),
    privacyCard: get("#privacy-settings-card"),
    privacyDetailed: get("#privacy-detailed"),
    privacyActivity: get("#privacy-activity"),
    accountDeletionCard: get("#account-deletion-card"),
    openDeleteAccount: get("#btn-open-delete-account"),
    accountDeleteFeedback: get("#account-delete-profile-feedback"),
    accountDeleteModal: get("#account-delete-modal"),
    accountDeleteBackdrop: get("#account-delete-modal-backdrop"),
    accountDeleteUnderstand: get("#account-delete-understand"),
    accountDeleteInput: get("#account-delete-confirm-input"),
    accountDeleteConfirmWord: get("#account-delete-confirm-word"),
    accountDeleteStatus: get("#account-delete-status"),
    accountDeleteCancel: get("#btn-cancel-delete-account"),
    accountDeleteConfirm: get("#btn-confirm-delete-account")
  };

  const onboarding = {
    overlay: get("#onboarding-overlay"),
    idioma: get("#onboarding-idioma"),
    nick: get("#onboarding-nickname-input"),
    feedback: get("#onboarding-nickname-feedback")
  };

  // --- State ---
  let curCont = "";
  let questions = [];
  let curIdx = 0;
  let curScore = 0;
  let startTime = Date.now(); // Iniciar contagem para tempo de splash
  let curStreak = 0;
  let bestStreak = 0;
  let curChallenge = null;
  let currentMatchEventId = "";
  let currentChallengeSession = null;
  let currentChallengeBaseSession = null;
  let currentChallengeBaseBlockCode = "";
  let currentRankedSession = null;
  let lastMatchResult = null;
  let createChallengePromise = null;
  let isRankedMatch = false;
  let rankingPage = 0;
  let soundOn = (root.FlagGameStorage && root.FlagGameStorage.getString("sound", "on") === "on");
  let aCtx = null;
  const caps = (root.FlagGamePlatform) ? root.FlagGamePlatform.getCapabilities() : {};
  const CHALLENGE_WORLD_VARIATIONS = new Set(["10", "20", "50", "195"]);
  const CHALLENGE_CONTINENT_VARIATIONS = new Set([
    "south-america",
    "north-america",
    "europe",
    "africa",
    "asia",
    "oceania"
  ]);
  let accountDeleteTrigger = null;
  let accountDeleteProcessing = false;
  let accountDeleteFinished = false;

  // --- Navigation ---
  function showScreen(target) {
    closeMenu();
    const keepRankedSession =
      isRankedMatch && (target === screens.jogo || target === screens.resultado);
    if (root.FlagGameRanked && !keepRankedSession) root.FlagGameRanked.cancelSession();

    Object.values(screens).forEach(s => {
      if (!s) return;
      s.classList.remove("ativa");
      if (s === screens.inicio) s.style.display = "none";
    });
    if (target === screens.inicio) target.style.display = "flex";
    else if (target) target.classList.add("ativa");
  }

  function openMenu() {
    if (ctrls.navMenu) ctrls.navMenu.classList.add("open");
    if (ctrls.navBackdrop) ctrls.navBackdrop.classList.add("visible");
    if (ctrls.menuBtn) ctrls.menuBtn.classList.add("open");
  }

  function closeMenu() {
    if (ctrls.navMenu) ctrls.navMenu.classList.remove("open");
    if (ctrls.navBackdrop) ctrls.navBackdrop.classList.remove("visible");
    if (ctrls.menuBtn) ctrls.menuBtn.classList.remove("open");
  }

  function hideAppSplash() {
    const splash = document.querySelector("#appSplash") || ctrls.appSplash;
    if (!splash) return;

    const minDisplayTime = 2400;
    const timeElapsed = Date.now() - startTime;
    const remainingTime = Math.max(0, minDisplayTime - timeElapsed);

    setTimeout(() => {
        splash.classList.add("is-hidden");
        setTimeout(() => {
            if (splash.parentNode) splash.remove();
        }, 300);
    }, remainingTime);
  }

  function setFeedback(selector, message, isError) {
    const feedback = get(selector);
    if (!feedback) return;

    feedback.textContent = message || "";
    feedback.style.color = isError ? "var(--color-danger)" : "var(--color-success)";
  }

  function setChallengeEntryFeedback(message, isError) {
    setFeedback("#challenge-entry-feedback", message, isError);
  }

  function setResultChallengeFeedback(message, isError) {
    setFeedback("#result-challenge-feedback", message, isError);
  }

  function revealResultChallengeFeedback() {
    const feedback = get("#result-challenge-feedback");
    if (!feedback || !feedback.textContent) return;

    feedback.scrollIntoView({
      behavior: "smooth",
      block: "center"
    });
  }

  function getChallengeShareText(code) {
    return `${tFallback("challengeSharePrompt", "Compartilhe o código para disputar a mesma sequência.")} ${code}`;
  }

  function fallbackCopyText(text) {
    const textarea = document.createElement("textarea");
    textarea.value = text;
    textarea.setAttribute("readonly", "");
    textarea.style.position = "fixed";
    textarea.style.opacity = "0";
    textarea.style.pointerEvents = "none";

    document.body.appendChild(textarea);
    textarea.select();

    let copied = false;
    try {
      copied = document.execCommand("copy");
    } finally {
      textarea.remove();
    }

    return copied;
  }

  async function copyText(text) {
    if (navigator.clipboard && navigator.clipboard.writeText) {
      await navigator.clipboard.writeText(text);
      return true;
    }

    return fallbackCopyText(text);
  }

  async function shareText(text, title) {
    const shareData = {
      title: title || tFallback("challengeFriends", "Desafio entre Amigos"),
      text
    };

    const capacitorShare = root.Capacitor &&
      root.Capacitor.Plugins &&
      root.Capacitor.Plugins.Share;

    if (capacitorShare && capacitorShare.share) {
      await capacitorShare.share(shareData);
      return "shared";
    }

    if (navigator.share) {
      await navigator.share(shareData);
      return "shared";
    }

    await copyText(text);
    return "copied";
  }

  function challengeMessage(code, fallbackKey) {
    if (code === "base_required") {
      return tFallback(
        "challengeBaseRequired",
        "Esta partida nao pode ser transformada em desafio. Inicie uma nova partida conectado a internet."
      );
    }

    const messages = {
      ranked_result_missing: ["challengeRankedResultMissing", "A partida classificada ainda nao foi confirmada no ranking. Aguarde alguns segundos e tente novamente."],
      ranked_sequence_missing: ["challengeRankedSequenceMissing", "Esta partida classificada não possui uma sequência protegida. Inicie uma nova partida classificada conectado à internet."],
      ranked_result_metrics_incomplete: ["challengeRankedResultMetricsIncomplete", "Esta partida classificada nao possui metricas completas para gerar um desafio."],
      ranked_submit_failed: ["challengeRankedSubmitFailed", "O resultado classificado nao foi validado. Nao foi possivel criar o desafio."],
      ranked_session_not_found: ["challengeRankedSessionNotFound", "A sessao classificada nao foi encontrada."],
      challenge_already_created: ["challengeAlreadyCreated", "Esta partida ja gerou um desafio."],
      challenge_permission_denied: ["challengePermissionDenied", "Erro de permissao ao criar o desafio."],
      challenge_response_invalid: ["challengeResponseInvalid", "O servidor nao retornou o codigo do desafio."],
      server_contract_mismatch: ["challengeServerContractMismatch", "O contrato remoto do servidor ainda esta desalinhado."],
      daily_limit: ["challengeDailyLimit", "Limite diario de desafios atingido."],
      received_challenge: ["challengeReceivedBlocked", "Esta partida ja veio de um desafio e nao pode gerar outro codigo."],
      auth: ["challengeLoginRequired", "Entre com sua conta para usar desafios."],
      expired: ["challengeExpired", "Este desafio expirou."],
      invalid: ["invalidChallengeCode", "Código inválido."],
      network: ["challengeNetworkError", "Falha de conexão. Tente novamente sem apagar o código."],
      unavailable: ["challengeUnavailable", "Este desafio está indisponível."],
      unsupported: ["challengeUnsupportedMode", "Este modo ainda não pode ser desafiado."],
      used: ["challengeAlreadyUsed", "Este desafio já foi utilizado."],
      unknown: [fallbackKey || "challengeUnavailable", "Não foi possível validar o desafio."]
    };
    const entry = messages[code] || messages.unknown;

    return tFallback(entry[0], entry[1]);
  }

  function modeVariationFromChallenge(config) {
    if (!config) return null;

    if (config.mode === "world") {
      const variation = String(config.quantity || 0);
      if (!CHALLENGE_WORLD_VARIATIONS.has(variation)) return null;

      return {
        mode: "world",
        variation
      };
    }

    if (config.mode === "continent") {
      const variation = String(config.continent || "");
      if (!CHALLENGE_CONTINENT_VARIATIONS.has(variation)) return null;

      return {
        mode: "continent",
        variation
      };
    }

    return null;
  }

  function challengeSafeSessionId(session) {
    if (!session) return "";
    return session.base_match_session_id || session.baseMatchSessionId || session.session_id || "";
  }

  function logChallengeFlow(event, details) {
    console.info("Challenge flow:", {
      event,
      ...(details || {})
    });
  }

  function getDisplayName(user, cloudProfile) {
    const profileNickname =
      cloudProfile && typeof cloudProfile.nickname === "string"
        ? cloudProfile.nickname.trim()
        : "";
    const meta = user && user.user_metadata ? user.user_metadata : {};
    const googleName =
      typeof meta.full_name === "string" && meta.full_name.trim()
        ? meta.full_name.trim()
        : typeof meta.name === "string"
          ? meta.name.trim()
          : "";

    return profileNickname ||
      googleName ||
      tFallback("playerFallbackName", "Jogador");
  }

  // --- Helpers ---
  function updateUI() {
    if (ctrls.somJogo) ctrls.somJogo.textContent = soundOn ? "🔊" : "🔇";

    // Toggle ranked options visibility
    if (root.FlagGameAuth) {
        root.FlagGameAuth.getCurrentUser().then(sessionUser => {
            const rankedOptions = [get("#ranked-option-continents"), get("#ranked-option-world")];
            rankedOptions.forEach(opt => {
                if (opt) {
                    if (sessionUser) opt.classList.remove("hidden");
                    else opt.classList.add("hidden");
                }
            });
        }).catch(() => {});
    }

    // Atualizar UI de Autenticação
    if (root.FlagGameAuth) {
        root.FlagGameAuth.getCurrentUser().then(sessionUser => {
            const loggedOut = get("#auth-logged-out");
            const loggedIn = get("#auth-logged-in");
            const profileTitle = get(".profile-title");
            const cloudError = get("#cloud-profile-error");

            if (sessionUser) {
                if (loggedOut) loggedOut.classList.add("hidden");
                if (loggedIn) loggedIn.classList.remove("hidden");
                if (ctrls.accountDeletionCard) ctrls.accountDeletionCard.classList.remove("hidden");
                if (profileTitle) profileTitle.textContent = t("myProfile", "Meu perfil");

                const cloudProfile = root.FlagGameAuth.getCloudProfile();
                const meta = sessionUser.user_metadata || {};
                const displayName = getDisplayName(sessionUser, cloudProfile);

                const emailEl = get("#user-email");
                if (emailEl) emailEl.textContent = sessionUser.email;

                const nameEl = get("#user-name");
                if (nameEl) nameEl.textContent = displayName;

                // Update Sidebar Menu
                const mName = get("#menu-user-name");
                if (mName) mName.textContent = displayName;

                const mEmail = get("#menu-user-email");
                if (mEmail) mEmail.textContent = sessionUser.email;

                if (ctrls.menuLogout) ctrls.menuLogout.classList.remove("hidden");

                // Avatar
                if (meta.avatar_url) {
                    const img = get("#user-avatar img");
                    if (img) {
                        img.src = meta.avatar_url;
                        img.classList.remove("hidden");
                    }

                    const mAvatar = get("#menu-avatar");
                    if (mAvatar) {
                        const mImg = document.createElement("img");
                        mImg.src = meta.avatar_url;
                        mAvatar.replaceChildren(mImg);
                    }
                }
            } else {
                if (loggedOut) loggedOut.classList.remove("hidden");
                if (loggedIn) loggedIn.classList.add("hidden");
                if (ctrls.accountDeletionCard) ctrls.accountDeletionCard.classList.add("hidden");
                if (profileTitle) profileTitle.textContent = t("profileLocal", "Perfil local");
                if (cloudError) cloudError.classList.add("hidden");

                const mName = get("#menu-user-name");
                if (mName) mName.textContent = t("profileLocal", "Perfil local");

                const mEmail = get("#menu-user-email");
                if (mEmail) mEmail.textContent = "---";

                const mAvatar = get("#menu-avatar");
                if (mAvatar) mAvatar.replaceChildren();

                if (ctrls.menuLogout) ctrls.menuLogout.classList.add("hidden");
            }
        }).catch(err => console.error("Auth UI Sync Error:", err));
    }

  }

  function playSfx(type) {
    if (!soundOn) return;
    const AC = root.AudioContext || root.webkitAudioContext;
    if (!AC) return;
    aCtx = aCtx || new AC();
    const o = aCtx.createOscillator();
    const g = aCtx.createGain();
    const now = aCtx.currentTime;
    o.frequency.setValueAtTime(type === "erro" ? 180 : type === "recorde" ? 660 : 520, now);
    g.gain.setValueAtTime(0.0001, now);
    g.gain.exponentialRampToValueAtTime(0.08, now + 0.01);
    g.gain.exponentialRampToValueAtTime(0.0001, now + 0.14);
    o.connect(g); g.connect(aCtx.destination);
    o.start(now); o.stop(now + 0.15);
  }

  function embaralhar(l) {
    for (let i = l.length - 1; i > 0; i--) {
      const j = Math.floor(Math.random() * (i + 1));
      [l[i], l[j]] = [l[j], l[i]];
    }
    return l;
  }

  function formatarTempo(s) {
    const min = Math.floor(s / 60);
    const seg = s % 60;
    return `${min.toString().padStart(2, '0')}:${seg.toString().padStart(2, '0')}`;
  }

  // --- Onboarding ---
  function showStep(id) {
    document.querySelectorAll(".onboarding-step").forEach(s => s.classList.remove("ativa"));
    const step = get(`#onboarding-step-${id}`);
    if (step) step.classList.add("ativa");
  }

  async function checkOnboarding() {
    if (root.FlagGameStorage && root.FlagGameStorage.getString("onboarding_v1", "") !== "true") {
      if (onboarding.overlay) onboarding.overlay.classList.add("ativa");
      showStep("login");
      if (onboarding.idioma) onboarding.idioma.value = (root.detectBrowserLanguage ? root.detectBrowserLanguage() : "en");
    }
  }

  if (get("#btn-onboarding-login")) {
      get("#btn-onboarding-login").onclick = async () => {
        try {
          if (root.FlagGameAuth) {
            await root.FlagGameAuth.signInWithGoogle();
            updateUI();
          }
          showStep("language");
        } catch (error) {
          if (onboarding.feedback) {
            onboarding.feedback.textContent = tFallback("loginError", "Erro no login: ") + (error.message || "");
          }
        }
      };
  }
  if (get("#btn-onboarding-skip-login")) get("#btn-onboarding-skip-login").onclick = () => showStep("language");
  if (get("#btn-onboarding-next-lang")) {
      get("#btn-onboarding-next-lang").onclick = async () => {
        if (onboarding.idioma && root.loadLanguage) {
            await root.loadLanguage(onboarding.idioma.value);
            if (typeof updateUI === "function") updateUI();
        }
        showStep("nickname");
      };
  }
  if (get("#btn-onboarding-finish")) {
      get("#btn-onboarding-finish").onclick = () => {
        const nick = onboarding.nick ? onboarding.nick.value.trim() : "";
        if (nick.length < 3) { if (onboarding.feedback) onboarding.feedback.textContent = "Mínimo 3 caracteres"; return; }
        if (caps.supportsGlobalLeaderboards && root.FlagGameRanking) root.FlagGameRanking.updatePlayer({ nickname: nick });
        if (root.FlagGameStorage) root.FlagGameStorage.setString("onboarding_v1", "true");
        if (onboarding.overlay) onboarding.overlay.classList.remove("ativa");
        updateUI();
      };
  }

  // --- Profile Settings ---
  if (get("#btn-save-nick")) {
      get("#btn-save-nick").onclick = async () => {
        const nick = get("#profile-nickname").value.trim();
        if (nick.length >= 3) {
          if (root.FlagGameRanking) root.FlagGameRanking.updatePlayer({ nickname: nick });

          // Update cloud if possible
          if (root.FlagGameAuth && root.FlagGameAuth.getCloudProfile()) {
              try {
                  if (root.FlagGameAuth.updateCloudProfile) {
                    await root.FlagGameAuth.updateCloudProfile({ nickname: nick });
                  } else {
                    const supabase = root.FlagGameSupabase.client;
                    const { error } = await supabase.from('profiles').update({ nickname: nick }).eq('id', (await root.FlagGameAuth.getCurrentUser()).id);
                    if (error) throw error;
                    await root.FlagGameAuth.ensureCloudProfile(true);
                  }
              } catch (e) {
                  console.error("Save nick error:", e);
                  setFeedback("#profile-nickname-feedback", tFallback("profileSaveError", "Não foi possível salvar agora."), true);
                  return;
              }
          }

          setFeedback("#profile-nickname-feedback", tFallback("nameSaved", "Nome salvo!"), false);
          updateUI();
        } else {
          setFeedback("#profile-nickname-feedback", tFallback("nicknameTooShort", "Use pelo menos 3 caracteres."), true);
        }
      };
  }

  const savePrivacy = async () => {
      if (!root.FlagGameAuth || !root.FlagGameAuth.getCloudProfile()) return;
      const settings = {
          show_detailed_stats: ctrls.privacyDetailed ? ctrls.privacyDetailed.checked : false,
          show_recent_activity: ctrls.privacyActivity ? ctrls.privacyActivity.checked : true,
          show_wrong_flags: false,
          show_challenge_history: true
      };
      try {
          const supabase = root.FlagGameSupabase.client;
          await supabase.from('profiles').update({ privacy_settings: settings }).eq('id', (await root.FlagGameAuth.getCurrentUser()).id);
          await root.FlagGameAuth.ensureCloudProfile(); // Refresh
      } catch (e) {
          console.error("Privacy save error:", e);
      }
  };

  if (ctrls.privacyDetailed) ctrls.privacyDetailed.onchange = savePrivacy;
  if (ctrls.privacyActivity) ctrls.privacyActivity.onchange = savePrivacy;
  if (get("#profile-idioma")) {
      get("#profile-idioma").onchange = async (e) => {
          await root.loadLanguage(e.target.value);
          if (typeof updateUI === "function") updateUI();
      };
  }

  function renderizarPerfil() {
    const p = root.FlagGameRanking ? root.FlagGameRanking.getPlayer() : { nickname: "" };
    const cloudProfile = root.FlagGameAuth ? root.FlagGameAuth.getCloudProfile() : null;
    const userPromise = root.FlagGameAuth ? root.FlagGameAuth.getCurrentUser() : Promise.resolve(null);

    userPromise.then(user => {
      const activeNickname = getDisplayName(user, cloudProfile) || p.nickname || "";
      const nickInput = get("#profile-nickname");
      if (nickInput) nickInput.value = activeNickname;
    }).catch(() => {
      const nickInput = get("#profile-nickname");
      if (nickInput) nickInput.value = p.nickname || "";
    });

    const idiomaSelect = get("#profile-idioma");
    if (idiomaSelect) idiomaSelect.value = root.currentLanguage;

    // Privacy logic
    if (root.FlagGameAuth && cloudProfile) {
        if (ctrls.privacyCard) {
            ctrls.privacyCard.classList.remove("hidden");
            const settings = cloudProfile.privacy_settings || {};
            if (ctrls.privacyDetailed) ctrls.privacyDetailed.checked = !!settings.show_detailed_stats;
            if (ctrls.privacyActivity) ctrls.privacyActivity.checked = !!settings.show_recent_activity;
        }
    } else if (ctrls.privacyCard) {
        ctrls.privacyCard.classList.add("hidden");
    }

    updateUI();
  }

  function getAccountDeleteConfirmWord() {
    return String(tFallback("accountDeleteConfirmWord", "DELETE")).trim();
  }

  function setAccountDeleteStatus(message, type) {
    if (!ctrls.accountDeleteStatus) return;
    ctrls.accountDeleteStatus.textContent = message || "";
    ctrls.accountDeleteStatus.classList.toggle("is-error", type === "error");
    ctrls.accountDeleteStatus.classList.toggle("is-success", type === "success");
  }

  function resetAccountDeleteModal() {
    accountDeleteProcessing = false;
    accountDeleteFinished = false;
    if (ctrls.accountDeleteUnderstand) ctrls.accountDeleteUnderstand.checked = false;
    if (ctrls.accountDeleteInput) ctrls.accountDeleteInput.value = "";
    if (ctrls.accountDeleteConfirmWord) ctrls.accountDeleteConfirmWord.textContent = getAccountDeleteConfirmWord();
    if (ctrls.accountDeleteCancel) ctrls.accountDeleteCancel.disabled = false;
    if (ctrls.accountDeleteUnderstand) ctrls.accountDeleteUnderstand.disabled = false;
    if (ctrls.accountDeleteInput) ctrls.accountDeleteInput.disabled = false;
    if (ctrls.accountDeleteConfirm) {
      ctrls.accountDeleteConfirm.disabled = true;
      ctrls.accountDeleteConfirm.textContent = tFallback("continue", "Continue");
    }
    setAccountDeleteStatus("", "");
  }

  function updateAccountDeleteConfirmState() {
    if (!ctrls.accountDeleteConfirm || accountDeleteProcessing || accountDeleteFinished) return;
    const expected = getAccountDeleteConfirmWord().toLocaleUpperCase();
    const typed = String(ctrls.accountDeleteInput ? ctrls.accountDeleteInput.value : "")
      .trim()
      .toLocaleUpperCase();
    const understood = !!(ctrls.accountDeleteUnderstand && ctrls.accountDeleteUnderstand.checked);
    ctrls.accountDeleteConfirm.disabled = !(understood && typed === expected);
  }

  function openAccountDeleteModal() {
    if (!ctrls.accountDeleteModal) return;
    accountDeleteTrigger = document.activeElement;
    resetAccountDeleteModal();
    ctrls.accountDeleteModal.classList.remove("hidden");
    setTimeout(() => {
      if (ctrls.accountDeleteUnderstand) ctrls.accountDeleteUnderstand.focus();
    }, 0);
  }

  function closeAccountDeleteModal(force) {
    if (!ctrls.accountDeleteModal || (accountDeleteProcessing && !force)) return;
    ctrls.accountDeleteModal.classList.add("hidden");
    setAccountDeleteStatus("", "");
    if (accountDeleteTrigger && typeof accountDeleteTrigger.focus === "function") {
      accountDeleteTrigger.focus();
    }
    accountDeleteTrigger = null;
  }

  function setAccountDeleteProcessing(processing) {
    accountDeleteProcessing = processing;
    if (ctrls.accountDeleteCancel) ctrls.accountDeleteCancel.disabled = processing;
    if (ctrls.accountDeleteUnderstand) ctrls.accountDeleteUnderstand.disabled = processing;
    if (ctrls.accountDeleteInput) ctrls.accountDeleteInput.disabled = processing;
    if (ctrls.accountDeleteConfirm) ctrls.accountDeleteConfirm.disabled = processing;
  }

  function getAccountDeleteErrorMessage(error) {
    const code = error && error.code ? error.code : "";
    const messages = {
      account_deletion_in_progress: "accountDeleteInProgress",
      google_reauthentication_cancelled: "accountDeleteCancelled",
      google_auth_unavailable: "accountDeleteGoogleUnavailable",
      google_account_mismatch: "accountDeleteChooseSameGoogle",
      google_account_mismatch_restore_failed: "accountDeleteChooseSameGoogle",
      invalid_session: "accountDeleteSessionExpired",
      authentication_required: "accountDeleteSessionExpired",
      reauthentication_required: "accountDeleteBackendReauthRequired",
      google_auth_required: "accountDeleteChooseSameGoogle",
      temporary_delete_failure: "accountDeleteTemporaryFailure",
      timeout: "accountDeleteTemporaryFailure",
      network: "accountDeleteConnectionUnavailable",
      delete_failure: "accountDeleteFailed",
      unexpected_response: "accountDeleteUnexpected"
    };
    const key = messages[code] || "accountDeleteTryAgain";
    return tFallback(key, "Could not delete the account. Please try again.");
  }

  async function handleDeleteAccount() {
    if (accountDeleteFinished) {
      closeAccountDeleteModal(true);
      return;
    }

    if (!ctrls.accountDeleteConfirm || ctrls.accountDeleteConfirm.disabled) {
      setAccountDeleteStatus(
        tFallback("accountDeleteIncorrectConfirmation", "Complete the confirmation fields before continuing."),
        "error"
      );
      return;
    }

    if (!root.FlagGameAuth || !root.FlagGameAuth.deleteAccount) {
      setAccountDeleteStatus(tFallback("accountDeleteFailed", "Could not delete the account."), "error");
      return;
    }

    setAccountDeleteProcessing(true);
    setAccountDeleteStatus(tFallback("accountDeleteReauthenticate", "Choose the same Google account to continue."), "");

    try {
      setAccountDeleteStatus(tFallback("accountDeleteDeleting", "Deleting your account..."), "");
      await root.FlagGameAuth.deleteAccount();
      accountDeleteFinished = true;
      setAccountDeleteStatus(tFallback("accountDeleted", "Your account was deleted."), "success");
      if (ctrls.accountDeleteConfirm) {
        ctrls.accountDeleteConfirm.disabled = false;
        ctrls.accountDeleteConfirm.textContent = tFallback("continue", "Continue");
      }
      if (ctrls.accountDeleteCancel) ctrls.accountDeleteCancel.disabled = true;
      if (ctrls.accountDeleteFeedback) ctrls.accountDeleteFeedback.textContent = "";
      updateUI();
      renderizarPerfil();
      showScreen(screens.profile);
    } catch (error) {
      setAccountDeleteProcessing(false);
      setAccountDeleteStatus(getAccountDeleteErrorMessage(error), "error");
      updateAccountDeleteConfirmState();
    }
  }

  // --- Rankings UI ---
  function flagCountLabel(count) {
    return `${count} ${tFallback("flags", "Bandeiras")}`;
  }

  const VARIATIONS = {
    world: [
      { v: '10', label: () => flagCountLabel(10) },
      { v: '20', label: () => flagCountLabel(20) },
      { v: '50', label: () => flagCountLabel(50) },
      { v: '195', label: () => tFallback("modeWorld", "Mundo Inteiro") }
    ],
    continent: [
      { v: 'africa', label: () => tFallback("africa", "África") },
      { v: 'asia', label: () => tFallback("asia", "Ásia") },
      { v: 'europe', label: () => tFallback("europe", "Europa") },
      { v: 'north-america', label: () => tFallback("northAmerica", "América do Norte") },
      { v: 'south-america', label: () => tFallback("southAmerica", "América do Sul") },
      { v: 'oceania', label: () => tFallback("oceania", "Oceania") }
    ]
  };

  function updateRankingVariations() {
    if (!ctrls.rankingMode || !ctrls.rankingVar) return;
    const mode = ctrls.rankingMode.value;
    const vars = VARIATIONS[mode] || [];
    const currentVariation = ctrls.rankingVar.value;
    ctrls.rankingVar.replaceChildren();
    vars.forEach(opt => {
        const o = document.createElement("option");
        o.value = opt.v;
        o.textContent = opt.label();
        ctrls.rankingVar.appendChild(o);
    });

    if (vars.some(opt => opt.v === currentVariation)) {
        ctrls.rankingVar.value = currentVariation;
    }
  }

  async function loadRankings(append = false) {
    if (!root.FlagGameRankingsAPI || !ctrls.rankingList) return;

    // 1. Garantir que a sessão Supabase foi restaurada
    if (root.FlagGameAuth && root.FlagGameAuth.isReady) {
        await root.FlagGameAuth.isReady();
    }

    if (!append) {
        rankingPage = 0;
        ctrls.rankingList.replaceChildren();
        const loader = document.createElement("div");
        loader.className = "loading-placeholder";
        loader.textContent = t("loading", "Carregando...");
        ctrls.rankingList.appendChild(loader);
    }

    const currentUser = root.FlagGameAuth && root.FlagGameAuth.getCurrentUser
        ? await root.FlagGameAuth.getCurrentUser()
        : null;
    if (!currentUser) {
        if (ctrls.rankingUser) ctrls.rankingUser.classList.add("hidden");
        if (ctrls.loadMoreRankings) ctrls.loadMoreRankings.classList.add("hidden");
        if (ctrls.rankingList) {
            const authMessage = document.createElement("div");
            authMessage.className = "loading-placeholder";
            authMessage.style.color = "var(--color-danger)";
            authMessage.textContent = tFallback(
                "rankingAuthRequired",
                "Entre novamente para acessar o ranking."
            );
            ctrls.rankingList.replaceChildren(authMessage);
        }
        return;
    }

    const mode = ctrls.rankingMode ? ctrls.rankingMode.value : "world";
    const variation = ctrls.rankingVar ? ctrls.rankingVar.value : "20";

    try {
        const [rankResult, userPos] = await Promise.all([
            root.FlagGameRankingsAPI.getRankings(mode, variation, rankingPage),
            root.FlagGameRankingsAPI.getUserPosition(mode, variation)
        ]);

        if (!append) ctrls.rankingList.replaceChildren();

        // User Position Card
        if (userPos && ctrls.rankingUser) {
            ctrls.rankingUser.classList.remove("hidden");
            const posEl = ctrls.rankingUser.querySelector(".rank-pos");
            if (posEl) posEl.textContent = `${userPos.rank}º`;
            const scoreEl = ctrls.rankingUser.querySelector(".rank-score");
            if (scoreEl) scoreEl.textContent = `${userPos.stats.score} pts`;
        } else if (ctrls.rankingUser) {
            ctrls.rankingUser.classList.add("hidden");
        }

        if (rankResult.items.length === 0 && !append) {
            const empty = document.createElement("div");
            empty.className = "loading-placeholder";
            empty.textContent = t("noResultsRanking", "Nenhum resultado neste ranking ainda.");
            ctrls.rankingList.appendChild(empty);
            if (ctrls.loadMoreRankings) ctrls.loadMoreRankings.classList.add("hidden");
            return;
        }

        rankResult.items.forEach((item, idx) => {
            const row = document.createElement("div");
            row.className = "ranking-item";
            const pos = (rankingPage * 50) + idx + 1;

            row.innerHTML = `
                <span class="rank-num">${pos}</span>
                <div class="rank-avatar">
                   ${item.avatar_url ? `<img src="${item.avatar_url}">` : ''}
                </div>
                <div class="rank-details">
                    <div class="rank-nickname">
                        ${item.nickname}
                        ${item.is_supporter ? '<span class="badge-supporter">✨</span>' : ''}
                    </div>
                    <div class="rank-stats">
                        <span class="rank-val">${item.score} pts</span>
                        <span class="rank-sec">${Math.floor(item.elapsed_time_ms / 1000)}s</span>
                    </div>
                </div>
            `;
            row.onclick = () => showPublicProfile(item.user_id);
            ctrls.rankingList.appendChild(row);
        });

        if (ctrls.loadMoreRankings) {
            if (rankResult.items.length >= 50) ctrls.loadMoreRankings.classList.remove("hidden");
            else ctrls.loadMoreRankings.classList.add("hidden");
        }

    } catch (err) {
        if (ctrls.rankingList) {
            const error = document.createElement("div");
            error.className = "loading-placeholder";
            error.style.color = "var(--color-danger)";
            const messageKey = root.FlagGameRankingsAPI && root.FlagGameRankingsAPI.getUserMessageKey
                ? root.FlagGameRankingsAPI.getUserMessageKey(err)
                : "rankingLoadError";
            error.textContent = tFallback(messageKey, "Não foi possível carregar o ranking.");
            ctrls.rankingList.replaceChildren(error);
        }
    }
  }

  root.refreshDynamicTranslations = () => {
    updateRankingVariations();
  };

  async function showPublicProfile(userId) {
     if (!root.FlagGamePublicProfiles) return;
     const profile = await root.FlagGamePublicProfiles.getBasicProfile(userId);
     if (profile) {
        alert(`${profile.nickname} (${profile.country_code || '--'})\nJogador desde: ${new Date(profile.created_at).toLocaleDateString()}`);
    }
  }

  function setResultChallengeCode(code) {
    const box = get("#result-challenge-box");
    const output = get("#result-challenge-code");

    if (output) output.textContent = code;
    if (box) box.classList.toggle("hidden", !code);
  }

  function setChallengeCodeModal(code) {
    const output = get("#challenge-code-modal-code");
    if (output) output.textContent = code || "";
  }

  function openChallengeCodeModal(code) {
    const modal = get("#challenge-code-modal");
    if (!modal || !code) return;

    setChallengeCodeModal(code);
    modal.classList.remove("hidden");

    const copyButton = get("#btn-copy-challenge-code-modal");
    if (copyButton) copyButton.focus();
  }

  function closeChallengeCodeModal() {
    const modal = get("#challenge-code-modal");
    if (modal) modal.classList.add("hidden");
  }

  function getLastMatchChallengeSupport() {
    if (!lastMatchResult) return null;
    if (lastMatchResult.challengeReceived) return null;
    const supported = modeVariationFromChallenge(lastMatchResult.challengeConfig);
    if (!supported) return null;

      if (lastMatchResult.ranked) {
      if (lastMatchResult.rankedSubmitError) return null;
      if (!lastMatchResult.rankedSessionId) return null;
      if (!lastMatchResult.sequenceHash ||
          !Array.isArray(lastMatchResult.questionCodes) ||
          !lastMatchResult.questionCodes.length) {
        return null;
      }
      if (!root.FlagGamePlayerChallenges ||
          typeof root.FlagGamePlayerChallenges.createFromRankedMatch !== "function") {
        return null;
      }

      return {
        ...supported,
        source: "ranked"
      };
    }

    if (!lastMatchResult.challengeBaseSession || !lastMatchResult.challengeBaseSession.nonce) return null;

    return {
      ...supported,
      source: "base_match"
    };
  }

  function getLastMatchChallengeBlockCode() {
    if (!lastMatchResult) return "";
    if (lastMatchResult.challengeReceived) return "received_challenge";
    if (!modeVariationFromChallenge(lastMatchResult.challengeConfig)) return "unsupported";
    if (lastMatchResult.ranked) {
      if (!lastMatchResult.rankedSessionId || lastMatchResult.rankedSubmitError) {
        return lastMatchResult.rankedSubmitError ? "ranked_submit_failed" : "ranked_result_missing";
      }
      if (!lastMatchResult.sequenceHash ||
          !Array.isArray(lastMatchResult.questionCodes) ||
          !lastMatchResult.questionCodes.length) {
        return "ranked_sequence_missing";
      }
      if (!root.FlagGamePlayerChallenges ||
          typeof root.FlagGamePlayerChallenges.createFromRankedMatch !== "function") {
        return "unavailable";
      }
      return "";
    }
    if (lastMatchResult.challengeBaseBlockCode) return lastMatchResult.challengeBaseBlockCode;
    if (!lastMatchResult.challengeBaseSession || !lastMatchResult.challengeBaseSession.nonce) return "base_required";
    return "";
  }

  function updateResultChallengeButton() {
    const button = get("#btn-create-friend-challenge");
    if (!button) return;

    const supported = getLastMatchChallengeSupport();
    button.disabled = false;

    if (!lastMatchResult) {
      button.classList.add("hidden");
      setResultChallengeFeedback("", false);
    } else if (!supported) {
      button.classList.remove("hidden");
      button.textContent = tFallback("challengeFriendAction", "Desafiar um amigo");
      setResultChallengeFeedback(
        challengeMessage(getLastMatchChallengeBlockCode() || "unsupported"),
        true
      );
    } else if (!lastMatchResult.createdChallenge) {
      button.classList.remove("hidden");
      setResultChallengeFeedback("", false);
    }
  }

  function setCreatingChallenge(isCreating) {
    const button = get("#btn-create-friend-challenge");
    if (!button) return;

    button.disabled = isCreating;
    button.textContent = isCreating
      ? tFallback("creatingChallenge", "Criando desafio...")
      : tFallback("challengeFriendAction", "Desafiar um amigo");
  }

  async function createFriendChallengeFromResult() {
    if (!lastMatchResult) return;

    const button = get("#btn-create-friend-challenge");

    if (!root.FlagGamePlayerChallenges) {
      setResultChallengeFeedback(challengeMessage("unavailable"), true);
      revealResultChallengeFeedback();
      return;
    }

    if (lastMatchResult.createdChallenge) {
      setResultChallengeCode(lastMatchResult.createdChallenge.code);
      openChallengeCodeModal(lastMatchResult.createdChallenge.code);
      setResultChallengeFeedback(tFallback("challengeCreated", "Código criado."), false);
      return;
    }

    if (!getLastMatchChallengeSupport()) {
      const blockMessage = challengeMessage(getLastMatchChallengeBlockCode() || "base_required");
      setResultChallengeFeedback(
        blockMessage,
        true
      );
      if (button) {
        button.textContent = blockMessage;
        setTimeout(() => {
          if (!createChallengePromise) {
            button.textContent = tFallback("challengeFriendAction", "Desafiar um amigo");
          }
        }, 2200);
      }
      revealResultChallengeFeedback();
      return;
    }

    if (createChallengePromise) return createChallengePromise;

    setCreatingChallenge(true);
    setResultChallengeFeedback(tFallback("creatingChallenge", "Criando desafio..."), false);

    createChallengePromise = (async () => {
      try {
        const support = getLastMatchChallengeSupport();
        let created = null;

        if (support && support.source === "ranked") {
          if (lastMatchResult.rankedSubmitPromise) {
            setResultChallengeFeedback(
              tFallback("challengeWaitingRankedSubmit", "Aguardando validacao do ranking..."),
              false
            );
            const rankedSubmit = await lastMatchResult.rankedSubmitPromise;
            lastMatchResult.rankedResultId = rankedSubmit && rankedSubmit.result_id;
            lastMatchResult.rankedSubmitStatus = rankedSubmit && rankedSubmit.status;
            if (lastMatchResult.rankedSubmitError) {
              const error = new Error("Ranked submit failed");
              error.challengeCode = "ranked_submit_failed";
              throw error;
            }
          }
          created = await root.FlagGamePlayerChallenges.createFromRankedMatch(lastMatchResult);
        } else {
          created = await root.FlagGamePlayerChallenges.createFromMatch(lastMatchResult);
        }

        if (!created || !created.code) {
          const error = new Error("Challenge RPC response did not include a code");
          error.challengeCode = "challenge_response_invalid";
          throw error;
        }

        lastMatchResult.createdChallenge = created;
        setResultChallengeCode(created.code);
        openChallengeCodeModal(created.code);
        const box = get("#result-challenge-box");
        if (box) {
          box.scrollIntoView({ behavior: "smooth", block: "center" });
        }
        setResultChallengeFeedback(tFallback("challengeCreated", "Código criado."), false);
      } catch (error) {
        const code = error.challengeCode ||
          (root.FlagGamePlayerChallenges && root.FlagGamePlayerChallenges.errorCode
            ? root.FlagGamePlayerChallenges.errorCode(error)
            : "unknown");
        console.warn("Challenge creation failed:", JSON.stringify({
          rpc: support && support.source === "ranked"
            ? "create_challenge_from_ranked_session"
            : "create_challenge_from_completed_match",
          code,
          message: error && error.message || "",
          details: error && error.details || "",
          hint: error && error.hint || "",
          status: error && (error.status || error.statusCode) || error && error.challengeDiagnostic && error.challengeDiagnostic.status || null,
          rpcError: error && error.challengeDiagnostic || null,
          ranked: Boolean(lastMatchResult && lastMatchResult.ranked),
          rankedSessionId: lastMatchResult && lastMatchResult.rankedSessionId || "",
          hasSequenceHash: Boolean(lastMatchResult && lastMatchResult.sequenceHash),
          rankedSubmitStatus: lastMatchResult && lastMatchResult.rankedSubmitStatus || "",
          rankedResultId: lastMatchResult && lastMatchResult.rankedResultId || ""
        }));
        setResultChallengeFeedback(challengeMessage(code, "challengeCreateError"), true);
        revealResultChallengeFeedback();
      } finally {
        createChallengePromise = null;
        setCreatingChallenge(false);
      }
    })();

    return createChallengePromise;
  }

  async function shareResultChallengeCode() {
    const created = lastMatchResult && lastMatchResult.createdChallenge;

    if (!created || !created.code) {
      await createFriendChallengeFromResult();
      return;
    }

    try {
      const result = await shareText(
        getChallengeShareText(created.code),
        tFallback("shareChallenge", "Compartilhar desafio")
      );
      setResultChallengeFeedback(
        result === "copied"
          ? tFallback("codeCopied", "Código copiado")
          : tFallback("readyToShare", "Pronto para compartilhar."),
        false
      );
    } catch (error) {
      try {
        await copyText(getChallengeShareText(created.code));
        setResultChallengeFeedback(tFallback("codeCopied", "Código copiado"), false);
      } catch (copyError) {
        setResultChallengeFeedback(tFallback("challengeShareError", "Não foi possível compartilhar agora."), true);
      }
    }
  }

  async function copyResultChallengeCode() {
    const created = lastMatchResult && lastMatchResult.createdChallenge;

    if (!created || !created.code) {
      await createFriendChallengeFromResult();
      return;
    }

    try {
      await copyText(created.code);
      setResultChallengeFeedback(tFallback("codeCopied", "Código copiado"), false);
    } catch (error) {
      setResultChallengeFeedback(tFallback("challengeCopyError", "Não foi possível copiar agora."), true);
    }
  }

  async function copyChallengeCodeFromModal() {
    const created = lastMatchResult && lastMatchResult.createdChallenge;
    if (!created || !created.code) return;

    try {
      await copyText(created.code);
      setResultChallengeFeedback(tFallback("codeCopied", "Codigo copiado"), false);
      closeChallengeCodeModal();
    } catch (error) {
      setResultChallengeFeedback(tFallback("challengeCopyError", "Nao foi possivel copiar agora."), true);
      revealResultChallengeFeedback();
    }
  }

  async function shareChallengeCodeFromModal() {
    const created = lastMatchResult && lastMatchResult.createdChallenge;
    if (!created || !created.code) return;

    try {
      const result = await shareText(
        getChallengeShareText(created.code),
        tFallback("shareChallenge", "Compartilhar desafio")
      );
      setResultChallengeFeedback(
        result === "copied"
          ? tFallback("codeCopied", "Codigo copiado")
          : tFallback("readyToShare", "Pronto para compartilhar."),
        false
      );
      closeChallengeCodeModal();
    } catch (error) {
      setResultChallengeFeedback(tFallback("challengeShareError", "Nao foi possivel compartilhar agora."), true);
      revealResultChallengeFeedback();
    }
  }

  async function playReceivedChallenge() {
    const input = get("#challenge-code-input");
    const button = get("#btn-play-challenge");
    const rawCode = input ? input.value : "";
    const normalizedCode = root.FlagGamePlayerChallenges
      ? root.FlagGamePlayerChallenges.displayCode(rawCode)
      : rawCode.trim().toUpperCase();

    if (input) input.value = normalizedCode;

    if (!root.FlagGamePlayerChallenges) {
      setChallengeEntryFeedback(challengeMessage("unavailable"), true);
      return;
    }

    if (!root.FlagGamePlayerChallenges.normalizeCode(rawCode)) {
      setChallengeEntryFeedback(challengeMessage("invalid"), true);
      return;
    }

    try {
      if (button) {
        button.disabled = true;
        button.textContent = tFallback("validatingChallenge", "Validando código...");
      }
      setChallengeEntryFeedback(tFallback("validatingChallenge", "Validando código..."), false);

      const started = await root.FlagGamePlayerChallenges.acceptAndStart(rawCode);
      const cfg = started.localConfig;
      currentChallengeSession = started;
      setChallengeEntryFeedback(tFallback("challengeValid", "Código válido."), false);
      startMatch(cfg.mode === "world" ? "world" : cfg.continent, cfg, {
        challengeSession: started
      });
    } catch (error) {
      const code = error.challengeCode ||
        (root.FlagGamePlayerChallenges.errorCode
          ? root.FlagGamePlayerChallenges.errorCode(error)
          : "unknown");
      setChallengeEntryFeedback(challengeMessage(code), true);
    } finally {
      if (button) {
        button.disabled = false;
        button.textContent = tFallback("playChallenge", "Jogar desafio");
      }
    }
  }

  // --- Match Logic ---
  async function tryStartRanked(mode, variation, startFn) {
    const toggle = mode === "world" ? ctrls.toggleRankedWorld : ctrls.toggleRankedCont;
    if (toggle && toggle.checked) {
        try {
            if (root.FlagGameRanked) {
                const rankedSession = await root.FlagGameRanked.createSession(mode, variation);
                startFn(rankedSession);
            } else {
                throw new Error("Módulo de ranking não carregado.");
            }
        } catch (e) {
            alert("Erro ao iniciar partida classificada: " + e.message);
        }
    } else {
        startFn(null);
    }
  }

  async function startMatch(cont, cfg, options) {
    const matchOptions = options || {};
    curCont = cont;
    isRankedMatch = root.FlagGameRanked && root.FlagGameRanked.isRankedMatchActive();
    currentRankedSession = matchOptions.rankedSession ||
      (isRankedMatch && root.FlagGameRanked ? root.FlagGameRanked.getActiveSession() : null);
    currentChallengeSession = matchOptions.challengeSession || null;
    currentChallengeBaseSession = null;
    currentChallengeBaseBlockCode = "";

    curChallenge = cfg || (root.FlagGameChallenge ? root.FlagGameChallenge.createConfig({
      mode: cont === "world" ? "world" : "continent",
      continent: cont,
      quantity: cont === "world" ? 20 : 0
    }) : {});

    if (isRankedMatch && currentRankedSession && currentRankedSession.localConfig) {
      curChallenge = {
        ...curChallenge,
        ...currentRankedSession.localConfig,
        rankedSession: currentRankedSession
      };
    }

    const shouldUseBackendBase =
      !currentChallengeSession &&
      !isRankedMatch &&
      root.FlagGamePlayerChallenges &&
      typeof root.FlagGamePlayerChallenges.startBaseMatch === "function" &&
      modeVariationFromChallenge(curChallenge);

    logChallengeFlow("match_start", {
      mode: curChallenge && curChallenge.mode,
      variation: curChallenge && (curChallenge.quantity || curChallenge.continent || ""),
      ranked: Boolean(isRankedMatch),
      receivedChallenge: Boolean(currentChallengeSession),
      hasChallengeModule: Boolean(root.FlagGamePlayerChallenges),
      supported: Boolean(modeVariationFromChallenge(curChallenge)),
      ranked_session_id: currentRankedSession && currentRankedSession.rankedSessionId || "",
      hasRankedProtectedSequence: Boolean(currentRankedSession && currentRankedSession.hasProtectedSequence),
      willStartBaseMatch: Boolean(shouldUseBackendBase)
    });

    if (shouldUseBackendBase) {
      try {
        currentChallengeBaseSession =
          await root.FlagGamePlayerChallenges.startBaseMatch(curChallenge);
        logChallengeFlow("base_match_ready", {
          mode: curChallenge && curChallenge.mode,
          variation: curChallenge && (curChallenge.quantity || curChallenge.continent || ""),
          base_match_session_id: challengeSafeSessionId(currentChallengeBaseSession),
          hasBaseSessionId: Boolean(challengeSafeSessionId(currentChallengeBaseSession))
        });
        curChallenge = {
          ...curChallenge,
          ...currentChallengeBaseSession.localConfig,
          challengeBaseSession: currentChallengeBaseSession
        };
      } catch (error) {
        currentChallengeBaseSession = null;
        currentChallengeBaseBlockCode = error.challengeCode ||
          (root.FlagGamePlayerChallenges && root.FlagGamePlayerChallenges.errorCode
            ? root.FlagGamePlayerChallenges.errorCode(error)
            : "base_required");
        logChallengeFlow("base_match_unavailable", {
          mode: curChallenge && curChallenge.mode,
          variation: curChallenge && (curChallenge.quantity || curChallenge.continent || ""),
          reason: currentChallengeBaseBlockCode
        });
        console.warn("Partida-base de desafio indisponivel:", error);
      }
    } else if (!currentChallengeSession && !isRankedMatch) {
      currentChallengeBaseBlockCode = root.FlagGamePlayerChallenges
        ? "unsupported"
        : "unavailable";
      logChallengeFlow("base_match_skipped", {
        mode: curChallenge && curChallenge.mode,
        variation: curChallenge && (curChallenge.quantity || curChallenge.continent || ""),
        reason: currentChallengeBaseBlockCode
      });
    }

    if (root.FlagGameChallenge && root.countries) {
        questions = root.FlagGameChallenge.buildQuestions(root.countries, curChallenge);
    }
    if (!questions.length) {
        console.error("Match start failed:", {
          reason: "empty_questions",
          hasChallengeModule: !!root.FlagGameChallenge,
          countriesCount: root.countries ? root.countries.length : 0,
          challenge: curChallenge
        });
        alert("Não foi possível iniciar a partida. Reabra o aplicativo e tente novamente.");
        return;
    }
    curIdx = 0; curScore = 0; startTime = Date.now(); curStreak = 0; bestStreak = 0;
    currentMatchEventId = root.FlagGameStorage
      ? root.FlagGameStorage.createEventId()
      : `ev_${Date.now()}`;

    // UI Indicator
    const badge = get("#ranked-indicator");
    if (badge) {
        if (isRankedMatch) badge.classList.remove("hidden");
        else badge.classList.add("hidden");
    }

    showScreen(screens.jogo);
    nextQuestion();
  }

  function nextQuestion() {
    const p = questions[curIdx];
    if (!p) { finishMatch(); return; }
    const flagImg = get("#bandeira-atual");
    if (flagImg) flagImg.src = `assets/flags/${p.flagFile}`;
    const progressEl = get("#progresso");
    if (progressEl && root.t) progressEl.textContent = root.t("questionProgress", { current: curIdx + 1, total: questions.length });
    updateUI();

    const todas = (root.countries || []).filter(x => x.code !== p.code);
    const options = embaralhar([...todas]).slice(0, 3);
    const finalOps = embaralhar([p, ...options]);

    const altContainer = get("#alternativas");
    if (altContainer) {
        altContainer.replaceChildren();
        finalOps.forEach(x => {
          const b = document.createElement("button");
          b.className = "btn-option";
          b.textContent = (root.getCountryName ? root.getCountryName(x.code) : x.name);
          b.onclick = () => {
            getAll(".btn-option").forEach(btn => btn.disabled = true);
            if (x.code === p.code) {
              b.classList.add("correct"); curScore++; curStreak++;
              bestStreak = Math.max(bestStreak, curStreak);
              if (navigator.vibrate) navigator.vibrate(35); playSfx("acerto");
            } else {
              b.classList.add("wrong"); curStreak = 0;
              if (navigator.vibrate) navigator.vibrate([35, 25, 35]); playSfx("erro");
            }
            setTimeout(() => {
              curIdx++;
              if (curIdx < questions.length) nextQuestion();
              else finishMatch();
            }, 1200);
          };
          altContainer.appendChild(b);
        });
    }
  }

  function finishMatch() {
    const pct = Math.round((curScore / questions.length) * 100);
    const dur = Math.floor((Date.now() - startTime) / 1000);
    const wrong = questions.length - curScore;
    const matchMode = curChallenge && curChallenge.mode === "world"
      ? "world"
      : "continent";
    const challengeReceived = Boolean(currentChallengeSession && currentChallengeSession.nonce);
    const rankedSessionForResult = isRankedMatch && root.FlagGameRanked
      ? (root.FlagGameRanked.getActiveSession() || currentRankedSession)
      : null;

    lastMatchResult = {
      eventId: currentMatchEventId,
      mode: matchMode,
      continent: curChallenge && curChallenge.mode === "continent"
        ? curChallenge.continent
        : "",
      quantity: questions.length,
      correct: curScore,
      wrong,
      skipped: 0,
      total: questions.length,
      percent: pct,
      bestStreak,
      durationSeconds: dur,
      timeMs: Math.max(1, dur * 1000),
      challengeConfig: curChallenge,
      challengeBaseSession: currentChallengeBaseSession,
      challengeBaseBlockCode: currentChallengeBaseBlockCode,
      questionCodes: questions.map(question => question.code),
      sequenceHash: curChallenge && curChallenge.sequenceHash ? curChallenge.sequenceHash : "",
      challengeReceived,
      ranked: Boolean(isRankedMatch),
      rankedSessionId: rankedSessionForResult && (rankedSessionForResult.rankedSessionId || rankedSessionForResult.sessionId) || "",
      rankedSubmitPromise: null,
      rankedResultId: "",
      rankedSubmitStatus: "",
      rankedSubmitError: null,
      idempotencyKey: currentMatchEventId
    };

    logChallengeFlow("result_ready", {
      mode: lastMatchResult.mode,
      variation: lastMatchResult.quantity || lastMatchResult.continent || "",
      ranked: lastMatchResult.ranked,
      receivedChallenge: lastMatchResult.challengeReceived,
      base_match_session_id: challengeSafeSessionId(lastMatchResult.challengeBaseSession),
      hasBaseSessionId: Boolean(challengeSafeSessionId(lastMatchResult.challengeBaseSession)),
      ranked_session_id: lastMatchResult.rankedSessionId || "",
      hasSequenceHash: Boolean(lastMatchResult.sequenceHash),
      challengeAction: getLastMatchChallengeSupport()
        ? "enabled"
        : (getLastMatchChallengeBlockCode() || "hidden")
    });

    if (get("#resultado-pontos")) get("#resultado-pontos").textContent = curScore;
    if (get("#resultado-total")) get("#resultado-total").textContent = `/ ${questions.length}`;
    if (get("#resultado-percentual")) {
      get("#resultado-percentual").textContent = tFallback("accuracyValue", "{percent}% accuracy", { percent: pct });
    }

    const v = (pct === 100) ? "🏆" : (pct >= 75) ? "🌟" : "👏";
    if (get("#resultado-icone")) get("#resultado-icone").textContent = v;
    if (get("#resultado-mensagem")) {
      get("#resultado-mensagem").textContent = pct === 100
        ? tFallback("perfectResult", "Perfect!")
        : tFallback("greatResult", "Well done!");
    }

    const resResumo = get("#resultado-resumo");
    if (resResumo) {
        resResumo.replaceChildren();
        const items = [
          {l:tFallback("correctAnswers", "Acertos"), v:curScore},
          {l:tFallback("timeLabel", "Tempo"), v:formatarTempo(dur)},
          {l:tFallback("bestSequence", "Melhor sequência"), v:bestStreak},
          {l:tFallback("score", "Pontuação"), v:curScore}
        ];
        items.forEach(i => {
          const div = document.createElement("div"); div.className="res-item";
          const strong = document.createElement("strong");
          strong.textContent = i.v;
          const span = document.createElement("span");
          span.textContent = i.l;
          div.append(strong, span);
          resResumo.appendChild(div);
        });
    }

    if (root.FlagGameProfile) {
        root.FlagGameProfile.recordGame({
          eventId: currentMatchEventId, mode: matchMode,
          continent: lastMatchResult.continent, correct: curScore, total: questions.length,
          percent: pct, bestStreak: bestStreak, durationSeconds: dur
        });
    }

    if (challengeReceived && root.FlagGamePlayerChallenges) {
       root.FlagGamePlayerChallenges.submitResult(currentChallengeSession, lastMatchResult)
         .then(() => setResultChallengeFeedback(tFallback("challengeResultSubmitted", "Resultado do desafio enviado."), false))
         .catch(error => {
            const code = error.challengeCode || root.FlagGamePlayerChallenges.errorCode(error);
            setResultChallengeFeedback(challengeMessage(code, "challengeResultSubmitError"), true);
         });
    }

    if (isRankedMatch && root.FlagGameRanked) {
        const resultPayload = {
            eventId: currentMatchEventId,
            rankedSessionId: lastMatchResult.rankedSessionId,
            correct: curScore,
            wrongAnswers: questions.length - curScore,
            skips: 0,
            total: questions.length,
            durationSeconds: dur,
            bestStreak: bestStreak
        };

        lastMatchResult.rankedSubmitPromise = root.FlagGameRanked.submitResult(resultPayload).then((payload) => {
            lastMatchResult.rankedResultId = payload && payload.result_id;
            lastMatchResult.rankedSubmitStatus = payload && payload.status || "verified";
            alert(t("resultRegistered", "Resultado registrado no ranking!"));
            return payload;
        }).catch(() => {
            lastMatchResult.rankedSubmitError = true;
            updateResultChallengeButton();
            alert(t("resultNotValidated", "Não foi possível validar para o ranking."));
        });
    }

    if (root.FlagGameCloudSave) root.FlagGameCloudSave.scheduleSync("match_finished");
    setResultChallengeCode("");
    updateResultChallengeButton();
    showScreen(screens.resultado);
  }

  // --- Screen Events ---
  if (get("#btn-continentes")) get("#btn-continentes").onclick = () => showScreen(screens.continentes);
  if (get("#btn-voltar")) get("#btn-voltar").onclick = () => showScreen(screens.inicio);
  getAll(".continente").forEach(b => b.onclick = () => {
    const continent = b.dataset.continente;
    tryStartRanked("continent", continent, rankedSession => startMatch(continent, null, { rankedSession }));
  });

  if (get("#btn-mundo")) get("#btn-mundo").onclick = () => showScreen(screens.mundo);
  if (get("#btn-voltar-mundo")) get("#btn-voltar-mundo").onclick = () => showScreen(screens.inicio);
  getAll(".card-quantidade").forEach(b => b.onclick = () => {
    const qty = b.dataset.quantidade;
    tryStartRanked("world", qty, rankedSession => startMatch("world", root.FlagGameChallenge.createConfig({ mode: "world", quantity: Number(qty) }), { rankedSession }));
  });

  if (get("#btn-experiente")) get("#btn-experiente").onclick = () => startMatch("world_challenge");

  if (get("#btn-amigos")) get("#btn-amigos").onclick = () => showScreen(screens.amigos);
  if (get("#btn-voltar-amigos")) get("#btn-voltar-amigos").onclick = () => showScreen(screens.inicio);
  const challengeInput = get("#challenge-code-input");
  if (challengeInput) {
      challengeInput.oninput = () => {
        const cursorAtEnd = challengeInput.selectionStart === challengeInput.value.length;
        challengeInput.value = challengeInput.value
          .toUpperCase()
          .replace(/\s+/g, "");
        if (cursorAtEnd) {
          challengeInput.selectionStart = challengeInput.value.length;
          challengeInput.selectionEnd = challengeInput.value.length;
        }
      };
  }
  if (get("#btn-play-challenge")) {
      get("#btn-play-challenge").onclick = playReceivedChallenge;
  }
  if (get("#btn-create-friend-challenge")) get("#btn-create-friend-challenge").onclick = createFriendChallengeFromResult;
  if (get("#btn-copy-result-challenge-code")) get("#btn-copy-result-challenge-code").onclick = copyResultChallengeCode;
  if (get("#btn-share-result-challenge-code")) get("#btn-share-result-challenge-code").onclick = shareResultChallengeCode;
  if (get("#btn-close-challenge-code-modal")) get("#btn-close-challenge-code-modal").onclick = closeChallengeCodeModal;
  if (get("#challenge-code-modal-backdrop")) get("#challenge-code-modal-backdrop").onclick = closeChallengeCodeModal;
  if (get("#btn-copy-challenge-code-modal")) get("#btn-copy-challenge-code-modal").onclick = copyChallengeCodeFromModal;
  if (get("#btn-share-challenge-code-modal")) get("#btn-share-challenge-code-modal").onclick = shareChallengeCodeFromModal;

  if (get("#btn-sair-jogo")) get("#btn-sair-jogo").onclick = () => showScreen(screens.inicio);
  if (get("#btn-jogar-novamente")) get("#btn-jogar-novamente").onclick = () => startMatch(curCont, curChallenge);
  if (get("#btn-outro-continente")) get("#btn-outro-continente").onclick = () => showScreen(screens.inicio);

  const bFProfile = get("#btn-fechar-profile");
  if (bFProfile) bFProfile.onclick = () => showScreen(screens.inicio);

  const bFRankings = get("#btn-fechar-rankings");
  if (bFRankings) bFRankings.onclick = () => showScreen(screens.inicio);

  if (ctrls.rankingMode) ctrls.rankingMode.onchange = () => { updateRankingVariations(); loadRankings(); };
  if (ctrls.rankingVar) ctrls.rankingVar.onchange = () => loadRankings();
  if (ctrls.loadMoreRankings) ctrls.loadMoreRankings.onclick = () => { rankingPage++; loadRankings(true); };

  if (ctrls.menuBtn) {
    ctrls.menuBtn.onclick = () => {
      if (ctrls.navMenu && ctrls.navMenu.classList.contains("open")) closeMenu();
      else openMenu();
    };
  }
  if (ctrls.navBackdrop) ctrls.navBackdrop.onclick = () => closeMenu();

  if (ctrls.openDeleteAccount) {
    ctrls.openDeleteAccount.onclick = () => {
      if (ctrls.accountDeleteFeedback) ctrls.accountDeleteFeedback.textContent = "";
      openAccountDeleteModal();
    };
  }

  if (ctrls.accountDeleteCancel) {
    ctrls.accountDeleteCancel.onclick = () => closeAccountDeleteModal(false);
  }

  if (ctrls.accountDeleteBackdrop) {
    ctrls.accountDeleteBackdrop.onclick = () => closeAccountDeleteModal(false);
  }

  if (ctrls.accountDeleteUnderstand) {
    ctrls.accountDeleteUnderstand.onchange = updateAccountDeleteConfirmState;
  }

  if (ctrls.accountDeleteInput) {
    ctrls.accountDeleteInput.oninput = updateAccountDeleteConfirmState;
  }

  if (ctrls.accountDeleteConfirm) {
    ctrls.accountDeleteConfirm.onclick = handleDeleteAccount;
  }

  window.addEventListener("keydown", (e) => {
    if (e.key === "Escape") {
      closeAccountDeleteModal(false);
      closeChallengeCodeModal();
      closeMenu();
    }
  });

  const mBtnProfile = get("#menu-btn-profile");
  if (mBtnProfile) mBtnProfile.onclick = () => { renderizarPerfil(); showScreen(screens.profile); };

  const mBtnRankings = get("#menu-btn-rankings");
  if (mBtnRankings) {
    mBtnRankings.onclick = () => {
      showScreen(screens.rankings);
      updateRankingVariations();
      loadRankings();
    };
  }

  const mBtnChallenges = get("#menu-btn-challenges");
  if (mBtnChallenges) mBtnChallenges.onclick = () => showScreen(screens.amigos);

  if (ctrls.menuLogout) {
    ctrls.menuLogout.onclick = () => {
      closeMenu();
      const btnLogout = get("#btn-logout");
      if (btnLogout) btnLogout.click();
    };
  }

  if (ctrls.somJogo) {
    ctrls.somJogo.onclick = () => {
      soundOn = !soundOn; if (root.FlagGameStorage) root.FlagGameStorage.setString("sound", soundOn ? "on" : "off");
      ctrls.somJogo.textContent = soundOn ? "🔊" : "🔇";
    };
  }

  const btnLogoutReal = get("#btn-logout");
  if (btnLogoutReal) {
    btnLogoutReal.onclick = async () => {
      if (confirm(t("confirmLogout", "Deseja realmente sair?"))) {
          if (root.FlagGameAuth) await root.FlagGameAuth.signOut();
          updateUI();
      }
    };
  }

  const btnLoginGoogle = get("#btn-login-google");
  if (btnLoginGoogle) {
    btnLoginGoogle.onclick = async () => {
      try {
          if (root.FlagGameAuth) {
              await root.FlagGameAuth.signInWithGoogle();
              alert(t("loginSuccess", "Logado com sucesso!"));
              updateUI();
          }
      } catch (e) {
          alert(t("loginError", "Erro no login: ") + e.message);
      }
    };
  }

  if (ctrls.logo) ctrls.logo.onclick = (e) => { e.preventDefault(); showScreen(screens.inicio); };

  // --- Init ---
  if (root.initializeLanguage) {
      root.initializeLanguage().finally(async () => {
        try {
            if (root.FlagGameAuth) {
                root.FlagGameAuth.subscribeToAuthChanges(() => updateUI());
                await root.FlagGameAuth.isReady();
            }

            updateUI();
            document.body.classList.remove("app-loading");
            document.body.classList.add("app-ready");
            hideAppSplash();

            setTimeout(() => {
              checkOnboarding();
            }, 100);

            if (root.FlagGameCloudSave) root.FlagGameCloudSave.start();
            if (root.FlagGamePlayGamesCompetitive) root.FlagGamePlayGamesCompetitive.start();
        } catch (e) {
            console.error("Initialization Error:", e);
            document.body.classList.remove("app-loading");
            document.body.classList.add("app-ready");
            hideAppSplash();
        }
      });
  } else {
      document.body.classList.remove("app-loading");
      document.body.classList.add("app-ready");
      hideAppSplash();
  }

  // Safety hide loader (Fallback secundário)
  setTimeout(() => {
    document.body.classList.add("app-ready");
    hideAppSplash();
  }, 4500);

})();
