# Security

Only the latest release of NepalKit and the latest release of the NepalKitCore package get security fixes.

To report a security problem, don't open a public issue. Email **dibas.sigdel@gmail.com** with the NepalKit version, your macOS version, and the steps to reproduce. Expect a reply within a few days.

NepalKit runs in the App Sandbox, holds no credentials, and goes online only to check for updates. The most valuable finding is a way to make NepalKit install an update that fails Sparkle's EdDSA signature check.

To check that a download is genuine, see [How to verify a NepalKit download](docs/release-verification.md).
