# Firefox Setup Reference

A minimal record for rebuilding a Firefox profile by hand. The previous approach
committed a full 40 MB profile (browsing history, tracking identifiers, extension
binaries); that was removed for security and privacy reasons. This note captures
only what is needed to reconstruct the setup.

> Note: extension *identities* and *preferences* are recorded below, but not the
> per-extension internal state (uBlock custom filter lists, LibRedirect instances,
> Multi-Account Container definitions). Those must be reconfigured manually.

## Extensions

Install from `addons.mozilla.org` by name — do not rely on version-pinned `.xpi` URLs.

- **uBlock Origin** — content blocker
- **LastPass Password Manager** — vault is cloud-hosted; a fresh login restores everything
- **Multi-Account Containers** (Mozilla) — recreate container definitions manually
- **LibRedirect** — reconfigure preferred front-end instances
- **Get RSS Feed URL** — RSS helper

## Preferences

A hardened, privacy-first profile. Set via Settings, or paste the `user_pref`
lines into a `user.js` in the new profile for an exact match.

1. **Enhanced Tracking Protection → Strict**, including social and email tracking.
   ```
   user_pref("browser.contentblocking.category", "strict");
   user_pref("privacy.trackingprotection.enabled", true);
   user_pref("privacy.trackingprotection.socialtracking.enabled", true);
   user_pref("privacy.trackingprotection.emailtracking.enabled", true);
   ```
2. **Passwords handled entirely by LastPass** — Firefox login manager disabled.
   ```
   user_pref("signon.rememberSignons", false);
   user_pref("signon.autofillForms", false);
   user_pref("signon.generation.enabled", false);
   user_pref("signon.management.page.breach-alerts.enabled", false);
   user_pref("signon.firefoxRelay.feature", "disabled");
   ```
3. **Autofill off** — no form history, no credit-card autofill.
   ```
   user_pref("browser.formfill.enable", false);
   user_pref("extensions.formautofill.creditCards.enabled", false);
   ```
4. **History disabled**; form data cleared on shutdown.
   ```
   user_pref("places.history.enabled", false);
   user_pref("privacy.clearOnShutdown_v2.formdata", true);
   user_pref("privacy.clearOnShutdown_v2.browsingHistoryAndDownloads", false);
   ```
5. **Containers enabled** (driven by Multi-Account Containers).
   ```
   user_pref("privacy.userContext.enabled", true);
   user_pref("privacy.userContext.ui.enabled", true);
   ```
6. **New Tab / Home** — blank homepage, no top sites, search box, or sponsored content.
   ```
   user_pref("browser.startup.homepage", "chrome://browser/content/blanktab.html");
   user_pref("browser.newtabpage.activity-stream.feeds.topsites", false);
   user_pref("browser.newtabpage.activity-stream.showSearch", false);
   user_pref("browser.newtabpage.activity-stream.showSponsoredCheckboxes", false);
   user_pref("browser.newtabpage.activity-stream.showSponsoredTopSites", false);
   ```
