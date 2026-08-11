(function (root, factory) {
  if (typeof module === "object" && module.exports) {
    module.exports = factory(root);
  } else {
    root.FlagGameProfileMigration = factory(root);
  }
})(typeof globalThis !== "undefined" ? globalThis : window, function (root) {
  "use strict";

  async function checkAndMigrate() {
    const auth = root.FlagGameAuth;
    if (!auth) return;

    const user = await auth.getCurrentUser();
    if (!user) return;

    const localProfile = root.FlagGameProfile ? root.FlagGameProfile.readProfile() : null;
    if (!localProfile) return;

    // Check if migration was already done
    if (root.FlagGameStorage.getString("profile_migrated", "") === "true") return;

    const supabase = root.FlagGameSupabase.client;
    const { data: cloudProfile } = await supabase.from('profiles').select('*').eq('id', user.id).single();

    if (cloudProfile) {
       // Conflict: Cloud already has a profile.
       // For now, we compare and if they are different, we might want to ask.
       // If cloud is "Player", we can overwrite with local.
       if (cloudProfile.nickname === "Player" && localProfile.nickname && localProfile.nickname !== "Player") {
           await performMigration(user.id, localProfile);
       } else {
           // Show conflict UI (To be implemented in app.js or here)
       }
    } else {
       // Cloud empty: Just migrate
       await performMigration(user.id, localProfile);
    }
  }

  async function performMigration(userId, localData) {
    const supabase = root.FlagGameSupabase.client;

    const { error } = await supabase.from('profiles').update({
        nickname: localData.nickname,
        country_code: localData.country_code
    }).eq('id', userId);

    if (!error) {
        root.FlagGameStorage.setString("profile_migrated", "true");
    } else {
        console.error("Migration failed:", error);
    }
  }

  return {
    checkAndMigrate
  };
});
