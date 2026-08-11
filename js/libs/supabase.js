/*
 * Supabase JavaScript Client (Universal Bundle)
 * This file should contain the pre-compiled @supabase/supabase-js library.
 * For development, please ensure the real library is placed here.
 */
console.warn("Supabase library placeholder loaded. Please replace with actual @supabase/supabase-js bundle.");
window.supabase = {
  createClient: (url, key, options) => {
    console.warn("Supabase placeholder client created. Replace this file with the real @supabase/supabase-js bundle before production.");
    return {
      auth: {
        signInWithIdToken: async () => ({ data: { session: null, user: null }, error: new Error("Library placeholder") }),
        getSession: async () => ({ data: { session: null }, error: null }),
        onAuthStateChange: (cb) => ({ data: { subscription: { unsubscribe: () => {} } } }),
        signOut: async () => ({ error: null })
      },
      rpc: async () => ({ data: null, error: new Error("Library placeholder") }),
      from: (table) => ({
          select: () => ({ eq: () => ({ single: async () => ({ data: null, error: null }) }) }),
          insert: async () => ({ error: null }),
          update: async () => ({ error: null })
      }),
      functions: {
          invoke: async () => ({ data: null, error: null })
      }
    };
  }
};
