/// <reference types="node" />
import { readFileSync } from 'fs';
import { join } from 'path';
import { codelloyNative } from '../../package.json';

describe('codelloyNative', () => {
  it('pins a native SDK version and the SHA-256 of its iOS zip', () => {
    expect(codelloyNative.version).toMatch(/^\d+\.\d+\.\d+$/);
    expect(codelloyNative.sha256).toMatch(/^[0-9a-f]{64}$/);
  });

  // A version in one of these files would disagree with the pin after the next release.
  it.each([
    'CodelloyReactNative.podspec',
    'android/build.gradle',
    'scripts/fetch-native.sh',
  ])('is the only native SDK version that %s reads', (file) => {
    const text = readFileSync(join(__dirname, '../..', file), 'utf8');

    expect(text).toContain('codelloyNative');
    expect(text).not.toMatch(/\d+\.\d+\.\d+/);
  });
});
