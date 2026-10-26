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
// Objective-C method init: is an initializer.
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
  ): void;
  match(): Promise<NativeLink | null>;
  getPendingLink(): NativeLink | null;
  handleLink(url: string): boolean;
  installId(): string | null;
  resetForTesting(): boolean;
  addListener(eventName: string): void;
  removeListeners(count: number): void;
}

export default TurboModuleRegistry.getEnforcing<Spec>('RNCodelloy');
