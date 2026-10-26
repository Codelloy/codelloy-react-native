import { version as packageVersion } from '../../package.json';
import type { NativeLink, Spec } from '../NativeCodelloy';

const link: NativeLink = {
  id: 'link-1',
  url: 'shop://product/42',
  shortUrl: 'https://links.example.com/abc',
  isDeferred: true,
  matchType: 'exact',
  confidence: 'high',
};

// Each test loads a fresh copy of the module, because the module keeps its listeners and delivered ids.
async function load() {
  jest.resetModules();
  const native = {
    configure: jest.fn<boolean, Parameters<Spec['configure']>>(() => true),
    // iOS resolves a nil result as undefined.
    match: jest.fn<Promise<NativeLink | null | undefined>, []>(),
    getPendingLink: jest.fn<NativeLink | null, []>(() => null),
    handleLink: jest.fn<boolean, [string]>(() => true),
    handleInitialLink: jest.fn<boolean, [string]>(() => true),
    installId: jest.fn<string | null, []>(() => 'install-1'),
    resetForTesting: jest.fn<boolean, []>(() => true),
    addListener: jest.fn<undefined, [string]>(),
    removeListeners: jest.fn<undefined, [number]>(),
  };
  jest.doMock('../NativeCodelloy', () => ({
    __esModule: true,
    default: native,
  }));
  const { AppState, DeviceEventEmitter, Linking } =
    await import('react-native');
  const api = await import('../index');
  const emit = (value: NativeLink) => {
    DeviceEventEmitter.emit('CodelloyLink', value);
  };
  const urlListener = () => {
    const call = jest.mocked(Linking.addEventListener).mock.calls[0];
    if (!call) throw new Error('init did not subscribe to Linking');
    return call[1];
  };
  const becomeActive = () => {
    const call = jest.mocked(AppState.addEventListener).mock.calls[0];
    if (!call) throw new Error('init did not subscribe to AppState');
    call[1]('active');
  };
  return { api, native, Linking, emit, urlListener, becomeActive };
}

const flush = () =>
  new Promise<void>((resolve) => {
    setImmediate(resolve);
  });

describe('init', () => {
  it('gives the core the defaults and the wrapper token', async () => {
    const { api, native } = await load();

    api.init({ key: 'pk_test_x' });

    expect(native.configure).toHaveBeenCalledWith(
      'pk_test_x',
      true,
      true,
      true,
      'high',
      false,
      null,
      `react-native/${packageVersion}`
    );
  });

  it('gives the core each option', async () => {
    const { api, native } = await load();

    api.init({
      key: 'pk_test_x',
      clipboard: false,
      signalMatching: false,
      autoMatch: false,
      minConfidence: 'medium',
      debug: true,
      baseUrl: 'http://localhost:8080/link',
    });

    expect(native.configure).toHaveBeenCalledWith(
      'pk_test_x',
      false,
      false,
      false,
      'medium',
      true,
      'http://localhost:8080/link',
      `react-native/${packageVersion}`
    );
  });

  it('has the version of package.json in source', async () => {
    const { version } = await import('../version');

    expect(version).toBe(packageVersion);
  });
});

describe('Linking', () => {
  it('gives the initial URL to handleInitialLink', async () => {
    const { api, native, Linking } = await load();
    jest
      .mocked(Linking.getInitialURL)
      .mockResolvedValue('https://links.example.com/abc');

    api.init({ key: 'pk_test_x' });
    await flush();

    expect(native.handleInitialLink).toHaveBeenCalledWith(
      'https://links.example.com/abc'
    );
  });

  it('does not call handleInitialLink when the app did not open from a link', async () => {
    const { api, native, Linking } = await load();
    jest.mocked(Linking.getInitialURL).mockResolvedValue(null);

    api.init({ key: 'pk_test_x' });
    await flush();

    expect(native.handleInitialLink).not.toHaveBeenCalled();
  });

  it('gives each url event to handleLink', async () => {
    const { api, native, urlListener } = await load();

    api.init({ key: 'pk_test_x' });
    urlListener()({ url: 'https://links.example.com/def' });

    expect(native.handleLink).toHaveBeenCalledWith(
      'https://links.example.com/def'
    );
  });

  it('reads the initial URL after the first match when autoMatch is false', async () => {
    const { api, native, Linking } = await load();
    jest
      .mocked(Linking.getInitialURL)
      .mockResolvedValue('https://links.example.com/abc');
    native.match.mockResolvedValue(null);

    api.init({ key: 'pk_test_x', autoMatch: false });
    await flush();
    expect(Linking.getInitialURL).not.toHaveBeenCalled();

    await api.match();
    await flush();
    expect(native.handleInitialLink).toHaveBeenCalledWith(
      'https://links.example.com/abc'
    );
  });

  it('reads the initial URL also after a failed match', async () => {
    const { api, native, Linking } = await load();
    jest
      .mocked(Linking.getInitialURL)
      .mockResolvedValue('https://links.example.com/abc');
    native.match.mockRejectedValue(new Error('network'));

    api.init({ key: 'pk_test_x', autoMatch: false });
    await expect(api.match()).rejects.toThrow('network');
    await flush();

    expect(native.handleInitialLink).toHaveBeenCalledTimes(1);
  });

  it('gives the initial URL to handleInitialLink one time', async () => {
    const { api, native, Linking } = await load();
    jest
      .mocked(Linking.getInitialURL)
      .mockResolvedValue('https://links.example.com/abc');
    native.match.mockResolvedValue(null);

    api.init({ key: 'pk_test_x' });
    await api.match();
    await flush();

    expect(native.handleInitialLink).toHaveBeenCalledTimes(1);
  });

  it('subscribes one time when the app calls init again', async () => {
    const { api, native, Linking } = await load();

    api.init({ key: 'pk_test_x' });
    api.init({ key: 'pk_test_x' });

    expect(Linking.addEventListener).toHaveBeenCalledTimes(1);
    expect(native.configure).toHaveBeenCalledTimes(2);
  });

  // Android 11 and lower: Back ends the activity but not the JavaScript runtime. A new link starts a new activity,
  // and React Native sends no url event for it.
  it('gives a new initial URL to handleInitialLink when the app becomes active', async () => {
    const { api, native, Linking, becomeActive } = await load();
    jest
      .mocked(Linking.getInitialURL)
      .mockResolvedValueOnce('https://links.example.com/abc')
      .mockResolvedValueOnce('https://links.example.com/def');

    api.init({ key: 'pk_test_x' });
    await flush();
    becomeActive();
    await flush();

    expect(native.handleInitialLink.mock.calls).toEqual([
      ['https://links.example.com/abc'],
      ['https://links.example.com/def'],
    ]);
  });

  // Android: the core marks an intent only when it takes the link, so a refused intent would be resolved later.
  it('does not give the same initial URL again when the app becomes active', async () => {
    const { api, native, Linking, becomeActive } = await load();
    jest
      .mocked(Linking.getInitialURL)
      .mockResolvedValue('https://links.example.com/abc');

    api.init({ key: 'pk_test_x' });
    await flush();
    becomeActive();
    await flush();

    expect(native.handleInitialLink).toHaveBeenCalledTimes(1);
  });

  // Android: an app can call setIntent in onNewIntent, so getInitialURL gives the URL of the last url event.
  it('does not give the URL of a url event again as an initial URL', async () => {
    const { api, native, Linking, urlListener, becomeActive } = await load();
    jest.mocked(Linking.getInitialURL).mockResolvedValueOnce(null);

    api.init({ key: 'pk_test_x' });
    await flush();
    urlListener()({ url: 'https://links.example.com/def' });
    jest
      .mocked(Linking.getInitialURL)
      .mockResolvedValueOnce('https://links.example.com/def');
    becomeActive();
    await flush();

    expect(native.handleLink).toHaveBeenCalledTimes(1);
    expect(native.handleInitialLink).not.toHaveBeenCalled();
  });

  // The core refuses each link until the first match. A link that the user opened before consent must not be lost.
  it('gives a url event before the first match with autoMatch false to handleLink after match', async () => {
    const { api, native, urlListener } = await load();
    native.match.mockResolvedValue(null);

    api.init({ key: 'pk_test_x', autoMatch: false });
    urlListener()({ url: 'https://links.example.com/def' });
    expect(native.handleLink).not.toHaveBeenCalled();

    await api.match();
    expect(native.handleLink).toHaveBeenCalledWith(
      'https://links.example.com/def'
    );
  });

  // Jest fails a test that leaves a rejection unhandled.
  it('leaves no rejection unhandled when the initial URL cannot be read', async () => {
    const { api, Linking } = await load();
    jest
      .mocked(Linking.getInitialURL)
      .mockRejectedValue(new Error('Could not get the initial URL'));

    api.init({ key: 'pk_test_x' });
    await flush();

    expect(Linking.getInitialURL).toHaveBeenCalled();
  });

  it('does not read the initial URL when the app becomes active before the first match with autoMatch false', async () => {
    const { api, Linking, becomeActive } = await load();

    api.init({ key: 'pk_test_x', autoMatch: false });
    becomeActive();
    await flush();

    expect(Linking.getInitialURL).not.toHaveBeenCalled();
  });

  it('does not read the initial URL for a match before init', async () => {
    const { api, native, Linking } = await load();
    native.match.mockResolvedValue(null);

    await api.match();

    expect(Linking.getInitialURL).not.toHaveBeenCalled();
  });
});

describe('onLink', () => {
  it('delivers the pending link one time', async () => {
    const { api, native, emit } = await load();
    native.getPendingLink.mockReturnValue(link);
    const listener = jest.fn();

    api.onLink(listener);
    emit(link);

    expect(listener).toHaveBeenCalledTimes(1);
    expect(listener).toHaveBeenCalledWith(link);
  });

  it('delivers each new link from the native event', async () => {
    const { api, native, emit } = await load();
    const listener = jest.fn();

    api.onLink(listener);
    emit(link);
    emit({ ...link, id: 'link-2', isDeferred: false });

    expect(native.addListener).toHaveBeenCalledWith('CodelloyLink');
    expect(listener).toHaveBeenCalledTimes(2);
    expect(listener).toHaveBeenLastCalledWith({
      ...link,
      id: 'link-2',
      isDeferred: false,
    });
  });

  it('gives each link to each listener one time', async () => {
    const { api, native, emit } = await load();
    const first = jest.fn();
    const second = jest.fn();

    api.onLink(first);
    api.onLink(second);
    emit(link);

    expect(native.addListener).toHaveBeenCalledTimes(1);
    expect(first).toHaveBeenCalledTimes(1);
    expect(second).toHaveBeenCalledTimes(1);
  });

  it('does not give an old link to a later listener', async () => {
    const { api, native, emit } = await load();
    native.getPendingLink.mockReturnValue(link);
    const first = jest.fn();
    const second = jest.fn();

    api.onLink(first);
    api.onLink(second);
    emit(link);

    expect(second).not.toHaveBeenCalled();
  });

  it('removes the native subscription with the last listener', async () => {
    const { api, native } = await load();
    const remove = api.onLink(jest.fn());

    remove();
    api.onLink(jest.fn());

    expect(native.removeListeners).toHaveBeenCalledWith(1);
    expect(native.getPendingLink).toHaveBeenCalledTimes(2);
  });

  it('keeps the native subscription while a listener is left', async () => {
    const { api, native, emit } = await load();
    const kept = jest.fn();
    api.onLink(kept);
    const remove = api.onLink(jest.fn());

    remove();
    emit(link);

    expect(native.removeListeners).not.toHaveBeenCalled();
    expect(kept).toHaveBeenCalledWith(link);
  });
});

describe('the other calls', () => {
  it('match gives the link or null', async () => {
    const { api, native } = await load();
    native.match.mockResolvedValueOnce(link).mockResolvedValueOnce(null);

    await expect(api.match()).resolves.toEqual(link);
    await expect(api.match()).resolves.toBeNull();
  });

  it('match gives null when iOS resolves no link as undefined', async () => {
    const { api, native } = await load();
    native.match.mockResolvedValue(undefined);

    await expect(api.match()).resolves.toBeNull();
  });

  it('match rejects with the code of the native error', async () => {
    const { api, native } = await load();
    native.match.mockRejectedValue(
      Object.assign(new Error('The request failed.'), { code: 'NETWORK' })
    );

    await expect(api.match()).rejects.toMatchObject({ code: 'NETWORK' });
  });

  it('handleLink, installId and resetForTesting give the native results', async () => {
    const { api, native } = await load();
    native.handleLink.mockReturnValue(false);
    native.installId.mockReturnValue(null);
    native.resetForTesting.mockReturnValue(false);

    expect(api.handleLink('https://example.com/')).toBe(false);
    expect(native.handleLink).toHaveBeenCalledWith('https://example.com/');
    expect(api.installId()).toBeNull();
    expect(api.resetForTesting()).toBe(false);
  });
});
