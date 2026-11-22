# Security

Only the latest release of NepalKit and of the NepalKitCore package is supported.

Please don't open a public issue for a security problem. Email **dibas.sigdel@gmail.com** with the NepalKit version, your macOS version, and steps to reproduce. You should hear back within a few days.

NepalKit is sandboxed, holds no credentials, and only goes online to check for updates. The most valuable finding would be a way to make it install an update that fails Sparkle's EdDSA signature check.

To check that a download is genuine, see [docs/release-verification.md](docs/release-verification.md).
