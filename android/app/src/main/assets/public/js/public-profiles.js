(function (root, factory) {
  if (typeof module === "object" && module.exports) {
    module.exports = factory(root);
  } else {
    root.FlagGamePublicProfiles = factory(root);
  }
})(typeof globalThis !== "undefined" ? globalThis : window, function (root) {
  "use strict";

  function getSupabase() {
    return root.FlagGameSupabase ? root.FlagGameSupabase.client : null;
  }

  /**
   * Busca dados básicos de um perfil.
   */
  async function getBasicProfile(userId) {
    const supabase = getSupabase();
    if (!supabase) return null;

    try {
      const { data, error } = await supabase.rpc('get_public_profile', {
        p_target_user_id: userId
      });
      if (error) throw error;
      return data;
    } catch (err) {
      console.error("Public Profile Error:", err);
      return null;
    }
  }

  /**
   * Busca detalhes avançados (requer ser apoiador).
   */
  async function getAdvancedDetails(userId) {
    const supabase = getSupabase();
    if (!supabase) return null;

    try {
      const { data, error } = await supabase.rpc('get_supporter_profile_details', {
        p_target_user_id: userId
      });
      if (error) throw error;
      return data;
    } catch (err) {
      // Se o erro for 403 (Unauthorized/Forbidden), o backend já bloqueou por privacidade ou falta de entitlement.
      console.warn("Advanced details blocked:", err.message);
      return { blocked: true, reason: err.message };
    }
  }

  return {
    getBasicProfile,
    getAdvancedDetails
  };
});
