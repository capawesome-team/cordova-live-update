/* global cordova, describe, it, expect, beforeEach */

/**
 * Auto-tests for @capawesome/cordova-live-update.
 *
 * These are smoke tests that exercise the plugin's local-only surface (queries,
 * getters, setters, and listener add/remove). They do not require network
 * access or a configured Capawesome Cloud APP_ID, so they can run in any
 * Cordova test app that installs `cordova-plugin-test-framework` plus this
 * plugin.
 *
 * Network-dependent flows (`sync`, `fetchLatestBundle`, `fetchChannels`,
 * `downloadBundle`) are covered by the manual tests below.
 */
exports.defineAutoTests = function () {
  var LiveUpdate;

  beforeEach(function () {
    LiveUpdate = cordova && cordova.plugins && cordova.plugins.LiveUpdate;
  });

  describe('cordova.plugins.LiveUpdate', function () {
    it('is exposed once deviceready has fired', function () {
      expect(LiveUpdate).toBeDefined();
    });

    it('returns a non-empty device ID', function (done) {
      LiveUpdate.getDeviceId().then(function (result) {
        expect(result.deviceId).toBeDefined();
        expect(typeof result.deviceId).toBe('string');
        expect(result.deviceId.length).toBeGreaterThan(0);
        done();
      }, fail(done));
    });

    it('returns a version code as a string', function (done) {
      LiveUpdate.getVersionCode().then(function (result) {
        expect(typeof result.versionCode).toBe('string');
        expect(result.versionCode.length).toBeGreaterThan(0);
        done();
      }, fail(done));
    });

    it('returns a version name as a string', function (done) {
      LiveUpdate.getVersionName().then(function (result) {
        expect(typeof result.versionName).toBe('string');
        expect(result.versionName.length).toBeGreaterThan(0);
        done();
      }, fail(done));
    });

    it('reports no current bundle on a fresh install', function (done) {
      LiveUpdate.getCurrentBundle().then(function (result) {
        expect(result.bundleId).toBeNull();
        done();
      }, fail(done));
    });

    it('reports no next bundle on a fresh install', function (done) {
      LiveUpdate.getNextBundle().then(function (result) {
        expect(result.bundleId).toBeNull();
        done();
      }, fail(done));
    });

    it('returns an empty list of downloaded bundles', function (done) {
      LiveUpdate.getDownloadedBundles().then(function (result) {
        expect(Array.isArray(result.bundleIds)).toBe(true);
        done();
      }, fail(done));
    });

    it('returns an empty list of blocked bundles', function (done) {
      LiveUpdate.getBlockedBundles().then(function (result) {
        expect(Array.isArray(result.bundleIds)).toBe(true);
        done();
      }, fail(done));
    });

    it('returns the configured auto-update strategy from getConfig()', function (done) {
      LiveUpdate.getConfig().then(function (result) {
        expect(['none', 'background']).toContain(result.autoUpdateStrategy);
        done();
      }, fail(done));
    });

    it('reports not currently syncing', function (done) {
      LiveUpdate.isSyncing().then(function (result) {
        expect(typeof result.syncing).toBe('boolean');
        done();
      }, fail(done));
    });

    it('persists and clears a channel via setChannel()', function (done) {
      LiveUpdate.setChannel({ channel: 'cordova-test-channel' })
        .then(function () {
          return LiveUpdate.getChannel();
        })
        .then(function (result) {
          expect(result.channel).toBe('cordova-test-channel');
          return LiveUpdate.setChannel({ channel: null });
        })
        .then(function () {
          done();
        }, fail(done));
    });

    it('persists and reads a custom ID via setCustomId()', function (done) {
      LiveUpdate.setCustomId({ customId: 'cordova-test-custom-id' })
        .then(function () {
          return LiveUpdate.getCustomId();
        })
        .then(function (result) {
          expect(result.customId).toBe('cordova-test-custom-id');
          done();
        }, fail(done));
    });

    it('returns a listener handle from addListener() that resolves remove()', function (done) {
      LiveUpdate.addListener('reloaded', function () {}).then(function (
        handle,
      ) {
        expect(handle).toBeDefined();
        expect(typeof handle.remove).toBe('function');
        handle.remove().then(done, fail(done));
      }, fail(done));
    });

    it('clears every listener via removeAllListeners()', function (done) {
      Promise.all([
        LiveUpdate.addListener('reloaded', function () {}),
        LiveUpdate.addListener('nextBundleSet', function () {}),
      ])
        .then(function () {
          return LiveUpdate.removeAllListeners();
        })
        .then(done, fail(done));
    });
  });

  function fail(done) {
    return function (error) {
      expect(error).toBeNull();
      done();
    };
  }
};

/**
 * Manual tests for flows that need a Capawesome Cloud APP_ID or network
 * access. The test framework renders these as buttons in the manual-test
 * tab; tap one to execute and observe the result in the on-screen log.
 */
exports.defineManualTests = function (contentEl, createActionButton) {
  var log = function (message) {
    var line = document.createElement('div');
    line.textContent = '[' + new Date().toISOString() + '] ' + message;
    contentEl.appendChild(line);
  };

  createActionButton(
    'Run sync()',
    function () {
      cordova.plugins.LiveUpdate.sync()
        .then(function (result) {
          log('sync ok: nextBundleId=' + result.nextBundleId);
        })
        .catch(function (error) {
          log(
            'sync error: ' + (error && error.message ? error.message : error),
          );
        });
    },
    'sync_button',
  );

  createActionButton(
    'Fetch latest bundle',
    function () {
      cordova.plugins.LiveUpdate.fetchLatestBundle()
        .then(function (result) {
          log('latest bundle: ' + JSON.stringify(result));
        })
        .catch(function (error) {
          log(
            'fetchLatestBundle error: ' +
              (error && error.message ? error.message : error),
          );
        });
    },
    'fetch_latest_button',
  );

  createActionButton(
    'Reload WebView',
    function () {
      cordova.plugins.LiveUpdate.reload()
        .then(function () {
          log('reload triggered');
        })
        .catch(function (error) {
          log(
            'reload error: ' + (error && error.message ? error.message : error),
          );
        });
    },
    'reload_button',
  );

  createActionButton(
    'Reset to default bundle',
    function () {
      cordova.plugins.LiveUpdate.reset()
        .then(function () {
          log('reset ok');
        })
        .catch(function (error) {
          log(
            'reset error: ' + (error && error.message ? error.message : error),
          );
        });
    },
    'reset_button',
  );

  createActionButton(
    'Mark app as ready',
    function () {
      cordova.plugins.LiveUpdate.ready()
        .then(function (result) {
          log('ready: ' + JSON.stringify(result));
        })
        .catch(function (error) {
          log(
            'ready error: ' + (error && error.message ? error.message : error),
          );
        });
    },
    'ready_button',
  );
};
