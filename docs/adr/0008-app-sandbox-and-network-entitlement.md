# App sandbox with network-client access, and no Sparkle Downloader service

NepalKit runs sandboxed. The project already set `ENABLE_APP_SANDBOX = YES`, but
shipped no entitlements file, so the signed application carried no sandbox
entitlement at all — the setting and the signature disagreed. Sparkle makes the
decision unavoidable, because a sandboxed Sparkle application must satisfy
entitlement requirements to reach its own XPC services, and a choice between two
paths follows from that.

The application takes `com.apple.security.network.client` together with
`com.apple.security.temporary-exception.mach-lookup.global-name` entries for
`$(PRODUCT_BUNDLE_IDENTIFIER)-spks` and `$(PRODUCT_BUNDLE_IDENTIFIER)-spki`. It
does **not** bundle Sparkle's Downloader XPC service. Upstream Sparkle documents
the Downloader path's own drawbacks: release notes fall back to a deprecated
`WebView` because of a known WKWebView defect, release notes referencing external
content stop working, and since Sparkle 2.6 the service is not sandboxed by
default anyway. Taking the entitlement costs NepalKit nothing it wanted — the
application's conversion, dataset, and settings are all local, so the network
entitlement exists solely to serve the update check.

This means an entitlements file becomes a committed, release-contract artifact
alongside the bundle identifier and the Sparkle public key. That is acceptable
because the decision is made before the first distributed build; changing it
afterwards would mean re-signing, re-notarizing, and re-establishing the update
baseline.

Sandboxing is chosen over the alternative of shipping unsandboxed because it
costs nothing today, matches the build setting the project already declares, and
narrows any future App Store question. It is not a claim of App Store readiness —
distribution is a notarized disk image, not the store.
