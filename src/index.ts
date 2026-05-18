/// <reference types="cordova" />

import type {
  DeleteBundleOptions,
  DownloadBundleOptions,
  FetchChannelsOptions,
  FetchChannelsResult,
  FetchLatestBundleOptions,
  FetchLatestBundleResult,
  GetBlockedBundlesResult,
  GetBundlesResult,
  GetChannelResult,
  GetConfigResult,
  GetCurrentBundleResult,
  GetCustomIdResult,
  GetDeviceIdResult,
  GetDownloadedBundlesResult,
  GetNextBundleResult,
  GetVersionCodeResult,
  GetVersionNameResult,
  IsSyncingResult,
  LiveUpdatePlugin,
  PluginListenerHandle,
  ReadyResult,
  SetChannelOptions,
  SetConfigOptions,
  SetCustomIdOptions,
  SetNextBundleOptions,
  SyncOptions,
  SyncResult,
} from './definitions';
import { exec } from './exec';

const SERVICE_NAME = 'LiveUpdate';

function nextListenerId(): string {
  return `${Date.now().toString(36)}-${Math.random().toString(36).slice(2, 11)}`;
}

const LiveUpdate: LiveUpdatePlugin = {
  clearBlockedBundles: () => exec('clearBlockedBundles'),
  deleteBundle: (options: DeleteBundleOptions) =>
    exec('deleteBundle', [options]),
  downloadBundle: (options: DownloadBundleOptions) =>
    exec('downloadBundle', [options]),
  fetchChannels: (options?: FetchChannelsOptions) =>
    exec<FetchChannelsResult>('fetchChannels', [options ?? {}]),
  fetchLatestBundle: (options?: FetchLatestBundleOptions) =>
    exec<FetchLatestBundleResult>('fetchLatestBundle', [options ?? {}]),
  getBlockedBundles: () => exec<GetBlockedBundlesResult>('getBlockedBundles'),
  getBundles: () => exec<GetBundlesResult>('getBundles'),
  getChannel: () => exec<GetChannelResult>('getChannel'),
  getConfig: () => exec<GetConfigResult>('getConfig'),
  getCurrentBundle: () => exec<GetCurrentBundleResult>('getCurrentBundle'),
  getCustomId: () => exec<GetCustomIdResult>('getCustomId'),
  getDeviceId: () => exec<GetDeviceIdResult>('getDeviceId'),
  getDownloadedBundles: () =>
    exec<GetDownloadedBundlesResult>('getDownloadedBundles'),
  getNextBundle: () => exec<GetNextBundleResult>('getNextBundle'),
  getVersionCode: () => exec<GetVersionCodeResult>('getVersionCode'),
  getVersionName: () => exec<GetVersionNameResult>('getVersionName'),
  isSyncing: () => exec<IsSyncingResult>('isSyncing'),
  ready: () => exec<ReadyResult>('ready'),
  reload: () => exec('reload'),
  reset: () => exec('reset'),
  resetConfig: () => exec('resetConfig'),
  setChannel: (options: SetChannelOptions) => exec('setChannel', [options]),
  setConfig: (options: SetConfigOptions) => exec('setConfig', [options]),
  setCustomId: (options: SetCustomIdOptions) => exec('setCustomId', [options]),
  setNextBundle: (options: SetNextBundleOptions) =>
    exec('setNextBundle', [options]),
  sync: (options?: SyncOptions) => exec<SyncResult>('sync', [options ?? {}]),
  addListener(
    eventName: string,
    listenerFunc: (event: any) => void,
  ): Promise<PluginListenerHandle> {
    const listenerId = nextListenerId();
    cordova.exec(
      (event: unknown) => listenerFunc(event),
      (error: unknown) => {
        console.warn(
          `[LiveUpdate] listener "${eventName}" reported an error:`,
          error,
        );
      },
      SERVICE_NAME,
      'addListener',
      [eventName, listenerId],
    );
    return Promise.resolve({
      remove: () => exec('removeListener', [{ listenerId }]),
    });
  },
  removeAllListeners: () => exec('removeAllListeners'),
};

export type * from './definitions';
export default LiveUpdate;
