import { AppState, Linking, NativeEventEmitter } from 'react-native';
import Native, { type NativeLink } from './NativeCodelloy';
import { version } from './version';

export type MatchType = 'exact' | 'signal';
export type Confidence = 'low' | 'medium' | 'high';
/** The `code` of the error when `match` fails. */
export type CodelloyErrorCode = 'NOT_CONFIGURED' | 'NETWORK' | 'SERVER';

/** A link that the SDK delivers to `onLink`. */
export interface CodelloyLink {
  /** A random id of this link. */
  id: string;
  /** The deep link of the app, for example `shop://product/42`. */
  url: string;
  /** The Codelloy link that the user opened. */
  shortUrl: string;
  /** `true` for the link of the first launch after the install, `false` for a direct open. */
  isDeferred: boolean;
  matchType: MatchType;
  confidence: Confidence;
}

export interface CodelloyOptions {
  /** The SDK key: `pk_live_...` or `pk_test_...`. */
  key: string;
  /** iOS: read the click token from the clipboard at the first launch. Default `true`. */
  clipboard?: boolean;
  /**
   * Send the screen size for a signal match, on iOS only. It has no effect on Android.
   * With `false`, iOS delivers only exact matches. Default `true`.
   */
  signalMatching?: boolean;
  /** Run the first-launch match at `init`. With `false`, the SDK reads and sends nothing until `match`. Default `true`. */
  autoMatch?: boolean;
  /** `'medium'` also delivers medium signal matches. Default `'high'`. */
  minConfidence?: 'high' | 'medium';
  /** Write SDK lines to the native log. Default `false`. */
  debug?: boolean;
  /** The SDK server. Set it only for a local backend. */
  baseUrl?: string;
}

const EVENT = 'CodelloyLink';
const emitter = new NativeEventEmitter(Native);
const listeners = new Set<(link: CodelloyLink) => void>();
// The ids of the delivered links. The core can give a link from getPendingLink and again as an event.
const delivered = new Set<string>();
let subscription: { remove(): void } | undefined;
let initialized = false;
// True when the core takes links: from init with autoMatch, else from the first match.
let readsInitialUrl = false;
// The URLs of url events before that. The core refuses each link until then.
const waitingUrls: string[] = [];
// The URLs that went to handleLink. getInitialURL gives the same URL again while the JavaScript runtime lives.
const handledUrls = new Set<string>();

function deliver(link: NativeLink | null) {
  if (!link || delivered.has(link.id)) return;
  delivered.add(link.id);
  for (const listener of listeners) listener(link as CodelloyLink);
}

function handleUrl(url: string) {
  handledUrls.add(url);
  Native.handleLink(url);
}

function readInitialUrl() {
  readsInitialUrl = true;
  for (const url of waitingUrls.splice(0)) handleUrl(url);
  Linking.getInitialURL()
    .then((url) => {
      if (!url || handledUrls.has(url)) return;
      handledUrls.add(url);
      // The record dies with the JavaScript runtime. The native side stops a second resolve after a reload: Android
      // gives the core the intent of the activity, and iOS records the launch URL of the process.
      Native.handleInitialLink(url);
    })
    // The app did not ask for this read, so a failed read is not its error.
    .catch(() => undefined);
}

/**
 * Starts the SDK. Call it one time at launch. The SDK gets each link of React Native `Linking` by itself.
 */
export function init(options: CodelloyOptions): void {
  const autoMatch = options.autoMatch ?? true;
  Native.configure(
    options.key,
    options.clipboard ?? true,
    options.signalMatching ?? true,
    autoMatch,
    options.minConfidence ?? 'high',
    options.debug ?? false,
    options.baseUrl ?? null,
    `react-native/${version}`
  );
  if (initialized) return;
  initialized = true;
  Linking.addEventListener('url', ({ url }) => {
    if (readsInitialUrl) handleUrl(url);
    else waitingUrls.push(url);
  });
  // Android 11 and lower: Back ends the activity but not the runtime. A link then starts a new activity, and React
  // Native sends no url event for it. Only getInitialURL gives that link.
  AppState.addEventListener('change', (state) => {
    if (state === 'active' && readsInitialUrl) readInitialUrl();
  });
  // With autoMatch false, the core refuses each link until match.
  if (autoMatch) readInitialUrl();
}

/**
 * Runs the first-launch match, and starts the SDK if it did not start. Call it after consent when `autoMatch` is
 * `false`. Gives the delivered link or `null`. `onLink` gets the same link, so route the app only there.
 */
export async function match(): Promise<CodelloyLink | null> {
  try {
    // iOS resolves no link as undefined.
    return ((await Native.match()) ?? null) as CodelloyLink | null;
  } finally {
    if (initialized) readInitialUrl();
  }
}

/**
 * Adds a listener that gets each link one time: the deferred link of the first launch and each direct open.
 * A link that arrived before the first listener goes to that listener, also before `onLink` returns. Returns a
 * function that removes the listener. Keep one listener for the life of the app: a link that arrives while the last
 * listener is being removed can be lost.
 */
export function onLink(listener: (link: CodelloyLink) => void): () => void {
  listeners.add(listener);
  if (!subscription) {
    subscription = emitter.addListener(EVENT, deliver);
    deliver(Native.getPendingLink());
  }
  return () => {
    listeners.delete(listener);
    if (listeners.size === 0 && subscription) {
      // The core keeps the next link as pending until a new listener.
      subscription.remove();
      subscription = undefined;
    }
  };
}

/**
 * Gives a URL to the SDK. The SDK already gets each URL of React Native `Linking`, so do not give it such a URL: each
 * call resolves the link again. Returns `true` when the URL is on a link domain of the organisation, and the link then
 * goes to `onLink`.
 */
export function handleLink(url: string): boolean {
  return Native.handleLink(url);
}

/** The random id of this install. `null` on Android before `init`. */
export function installId(): string | null {
  return Native.installId();
}

/** Deletes the install state, so the next match runs as on a fresh install. Works only with a `pk_test_` key. */
export function resetForTesting(): boolean {
  return Native.resetForTesting();
}
