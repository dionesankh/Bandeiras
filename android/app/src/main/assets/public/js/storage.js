const FlagGameStorage = (() => {
  const memoryStore = {};
  let cachedStorage;
  let storageChecked = false;

  function getStorage() {
    if (storageChecked) {
      return cachedStorage;
    }

    storageChecked = true;

    try {
      if (typeof localStorage === "undefined") {
        cachedStorage = null;
        return cachedStorage;
      }

      const testKey = "__flag_game_storage_test__";
      localStorage.setItem(testKey, "1");
      localStorage.removeItem(testKey);

      cachedStorage = localStorage;
      return cachedStorage;

    } catch (error) {
      console.warn("Local storage unavailable:", error);
      cachedStorage = null;
      return cachedStorage;
    }
  }

  function getRaw(key) {
    try {
      const storage = getStorage();

      if (storage) {
        const value = storage.getItem(key);

        if (
          value === null &&
          Object.prototype.hasOwnProperty.call(memoryStore, key)
        ) {
          return memoryStore[key];
        }

        return value;
      }

      return Object.prototype.hasOwnProperty.call(memoryStore, key)
        ? memoryStore[key]
        : null;

    } catch (error) {
      console.warn("Could not read storage key:", key, error);
      return null;
    }
  }

  function setRaw(key, value) {
    try {
      const storage = getStorage();

      if (storage) {
        storage.setItem(key, value);
        return true;
      }

      memoryStore[key] = value;
      return true;

    } catch (error) {
      console.warn("Could not write storage key:", key, error);
      memoryStore[key] = value;
      return false;
    }
  }

  function getJson(key, fallback) {
    const value = getRaw(key);

    if (value === null || value === undefined || value === "") {
      return fallback;
    }

    try {
      return JSON.parse(value);

    } catch (error) {
      console.warn("Invalid JSON in storage key:", key, error);
      return fallback;
    }
  }

  function setJson(key, value) {
    try {
      return setRaw(key, JSON.stringify(value));

    } catch (error) {
      console.warn("Could not serialize storage key:", key, error);
      return false;
    }
  }

  function getString(key, fallback) {
    const value = getRaw(key);

    return value === null || value === undefined
      ? fallback
      : String(value);
  }

  function setString(key, value) {
    return setRaw(key, String(value));
  }

  function remove(key) {
    try {
      const storage = getStorage();

      if (storage) {
        storage.removeItem(key);
      }

      delete memoryStore[key];
      return true;

    } catch (error) {
      console.warn("Could not remove storage key:", key, error);
      delete memoryStore[key];
      return false;
    }
  }

  function has(key) {
    return getRaw(key) !== null;
  }

  function createEventId() {
    const timestamp = Date.now().toString(36);
    let random = "";

    if (typeof crypto !== "undefined" && crypto.getRandomValues) {
      const values = new Uint32Array(2);
      crypto.getRandomValues(values);
      random = Array.from(values)
        .map(value => value.toString(36))
        .join("");
    } else {
      random = Math.random().toString(36).slice(2, 12);
    }

    return `fg_event_${timestamp}_${random}`;
  }

  return {
    createEventId,
    getRaw,
    getJson,
    getString,
    has,
    remove,
    setRaw,
    setJson,
    setString
  };
})();

window.FlagGameStorage = FlagGameStorage;
window.createEventId = FlagGameStorage.createEventId;
