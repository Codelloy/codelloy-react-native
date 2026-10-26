import { TurboModuleRegistry, type TurboModule } from 'react-native';

// matchType is 'exact' or 'signal'. confidence is 'low', 'medium' or 'high'.
export type NativeLink = {
  id: string;
  url: string;
  shortUrl: string;
  isDeferred: boolean;
  matchType: string;
  confidence: string;
};

// Primitive parameters give the same native signatures on both architectures. The name is not init, because an
// Objective-C method init: is an initializer. configure is sync, so the sync calls after init see a started core.
export interface Spec extends TurboModule {
  configure(
    key: string,
    clipboard: boolean,
    signalMatching: boolean,
    autoMatch: boolean,
    minConfidence: string,
    debug: boolean,
    baseUrl: string | null,
    wrapper: string
  ): boolean;
  match(): Promise<NativeLink | null>;
  getPendingLink(): NativeLink | null;
  handleLink(url: string): boolean;
  // The initial URL of React Native Linking. Android gives the intent of the activity to the core instead, and iOS
  // gives the launch URL one time per process.
  handleInitialLink(url: string): boolean;
  installId(): string | null;
  resetForTesting(): boolean;
  addListener(eventName: string): void;
  removeListeners(count: number): void;
}

export default TurboModuleRegistry.getEnforcing<Spec>('RNCodelloy');
