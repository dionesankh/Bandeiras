const FlagGameSync = (() => {
  function createOfflineSyncAdapter() {
    return {
      pushPending(pendingScores) {
        return Promise.resolve({
          ok: false,
          status: "offline",
          pendingScores: pendingScores || []
        });
      },
      pullProfile() {
        return Promise.resolve({
          ok: false,
          status: "offline",
          profile: null
        });
      },
      syncPlayer(player) {
        return Promise.resolve({
          ok: false,
          status: "offline",
          player
        });
      }
    };
  }

  let adapter = createOfflineSyncAdapter();
  let status = {
    online: false,
    state: "offline",
    lastSyncAt: "",
    lastError: ""
  };

  function setAdapter(nextAdapter) {
    adapter = nextAdapter || createOfflineSyncAdapter();
  }

  function getAdapter() {
    return adapter;
  }

  function getStatus() {
    return { ...status };
  }

  function mergeObjectByOldestDate(localValue, remoteValue) {
    return Object.keys({
      ...(localValue || {}),
      ...(remoteValue || {})
    }).reduce((merged, key) => {
      const localDate = localValue && localValue[key];
      const remoteDate = remoteValue && remoteValue[key];

      if (!localDate) {
        merged[key] = remoteDate;
      } else if (!remoteDate) {
        merged[key] = localDate;
      } else {
        merged[key] = localDate <= remoteDate
          ? localDate
          : remoteDate;
      }

      return merged;
    }, {});
  }

  function mergeBooleanMap(localValue, remoteValue) {
    return Object.keys({
      ...(localValue || {}),
      ...(remoteValue || {})
    }).reduce((merged, key) => {
      merged[key] = Boolean(
        (localValue && localValue[key]) ||
        (remoteValue && remoteValue[key])
      );

      return merged;
    }, {});
  }

  function mergeProfile(localProfile, remoteProfile) {
    if (!remoteProfile) {
      return localProfile;
    }

    if (!localProfile) {
      return remoteProfile;
    }

    return {
      ...localProfile,
      ...remoteProfile,
      createdAt: [localProfile.createdAt, remoteProfile.createdAt]
        .filter(Boolean)
        .sort()[0] || localProfile.createdAt || remoteProfile.createdAt,
      updatedAt: [
        localProfile.updatedAt,
        remoteProfile.updatedAt
      ].filter(Boolean).sort().pop() || "",
      totals: {
        ...(localProfile.totals || {}),
        ...(remoteProfile.totals || {}),
        bestStreak: Math.max(
          Number(
            localProfile.totals &&
            localProfile.totals.bestStreak
          ) || 0,
          Number(
            remoteProfile.totals &&
            remoteProfile.totals.bestStreak
          ) || 0
        )
      },
      continentsCompleted: mergeBooleanMap(
        localProfile.continentsCompleted,
        remoteProfile.continentsCompleted
      ),
      continentsPerfect: mergeBooleanMap(
        localProfile.continentsPerfect,
        remoteProfile.continentsPerfect
      ),
      achievements: {
        ...(localProfile.achievements || {}),
        ...(remoteProfile.achievements || {}),
        unlocked: mergeObjectByOldestDate(
          localProfile.achievements &&
          localProfile.achievements.unlocked,
          remoteProfile.achievements &&
          remoteProfile.achievements.unlocked
        )
      }
    };
  }

  async function pushPending() {
    const pendingScores =
      typeof FlagGameRanking !== "undefined"
        ? FlagGameRanking.getPendingScores()
        : [];

    status = {
      ...status,
      state: "syncing",
      lastError: ""
    };

    try {
      const result = await adapter.pushPending(pendingScores);

      status = {
        online: Boolean(result && result.ok),
        state: result && result.ok ? "idle" : "offline",
        lastSyncAt: result && result.ok
          ? new Date().toISOString()
          : status.lastSyncAt,
        lastError: ""
      };

      return result;

    } catch (error) {
      status = {
        ...status,
        online: false,
        state: "error",
        lastError: error && error.message
          ? error.message
          : String(error)
      };

      return {
        ok: false,
        status: "error",
        error
      };
    }
  }

  async function pullProfile() {
    try {
      return await adapter.pullProfile();

    } catch (error) {
      status = {
        ...status,
        online: false,
        state: "error",
        lastError: error && error.message
          ? error.message
          : String(error)
      };

      return {
        ok: false,
        status: "error",
        profile: null,
        error
      };
    }
  }

  async function syncNow() {
    const pushed = await pushPending();
    const pulled = await pullProfile();

    return {
      ok: Boolean(pushed && pushed.ok && pulled && pulled.ok),
      pushed,
      pulled,
      status: getStatus()
    };
  }

  return {
    getAdapter,
    getStatus,
    mergeProfile,
    pullProfile,
    pushPending,
    setAdapter,
    syncNow
  };
})();

window.FlagGameSync = FlagGameSync;
