import { registerPlugin } from "@capacitor/core";
import type { FlagGameGoogleAuthPlugin } from "./definitions";

const FlagGameGoogleAuth = registerPlugin<FlagGameGoogleAuthPlugin>(
  "FlagGameGoogleAuth"
);

export * from "./definitions";
export { FlagGameGoogleAuth };
