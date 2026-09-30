// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
import NepalKitCore
import SwiftUI

/// The native Settings surface: a sidebar of three destinations.
///
/// The relocation from the popover added no new setting. The models passed in are
/// the ones the popover already read, so there is exactly one source of truth and
/// no value is writable from two places. Persistence stays in `SettingsStore`
/// keyed by bundle identifier, so settings survive relaunch and updates.
///
/// Control types are carried over unchanged from the popover deliberately: a
/// user who knows the segmented pickers should not have to relearn them.
/// Gregorian month names stay English — the month-name setting governs Bikram
/// Sambat and weekday names only, so a date may carry a Devanagari day and
/// year, an English Gregorian month name, and a weekday in either language at
/// once. That combination is intended (CONTEXT.md).
///
/// The selected destination is ephemeral for the same reason the popover's is:
/// Settings is not where anyone begins a task, so remembering the last one would
/// open a window onto a page the user did not ask for. `SettingsTab.landingTab`
/// is the resting state.
struct SettingsView: View {
    @Bindable var settings: DisplaySettingsModel
    @Bindable var loginItem: LoginItemModel
    /// The updater is constructed and started at launch (NepalKitApp), so the About
    /// tab always has a model to read; its outcome state comes from the same
    /// instance the background check reports into.
    @Bindable var updates: UpdateCheckModel
    /// Read by the Menu Bar preview so that tab cannot disagree with the real
    /// menu-bar label. Deliberately not `@Bindable`: the preview shows the label,
    /// it does not drive it, and a binding would invite writing to it here.
    let menuBar: MenuBarModel
    /// Read once, lazily, and cached — see `DeferredAppMetadata` for why the
    /// bundled LICENSE is not read at launch.
    let metadata: AppMetadata
    /// Injected so the calendar facts are the same dataset the rest of the app
    /// converts with, and so a test can control them.
    let dataset: CalendarDataset

    @State private var tab: SettingsTab = SettingsTab.landingTab

    var body: some View {
        // A split view rather than a `TabView`, and the reason is the footer: a
        // `TabView` owns its whole sidebar column, so there is nowhere to put the
        // identity strip below the destinations. A split-view sidebar is a `List`
        // this view builds, so the last row can be anything.
        //
        // Worth recording that the sidebar styles were not a free choice here. On
        // this SDK the available `TabViewStyle` statics are `automatic`, `carousel`,
        // `grouped`, `page`, `sidebarAdaptable`, `tabBarOnly` and `verticalPage` —
        // there is no `sidebarTabViewStyle`. `sidebarAdaptable` is the sidebar one,
        // and it adapts to a tab bar in compact layouts, which a fixed-width
        // preferences window never is.
        NavigationSplitView {
            sidebar
        } detail: {
            detail
        }
        // Wide enough for the longest detail (About's Devanagari range line and a
        // full URL) beside the sidebar without clipping, and tall enough that the
        // General form's three sections do not need to scroll to reach Startup.
        // A minimum, not a fixed size: the window still opens at whatever the
        // user last set, it just refuses to go below the point where the content
        // stops fitting.
        .frame(minWidth: 640, minHeight: 440)
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        List(selection: $tab) {
            ForEach(SettingsTab.allCases) { destination in
                Label(destination.title, systemImage: destination.symbol)
                    .tag(destination)
            }
        }
        .listStyle(.sidebar)
        // A fixed-ish width, in the range System Settings uses. The floor is what
        // keeps "Menu Bar" on one line at large accessibility text sizes; the
        // ideal is what it opens at on a default display.
        .navigationSplitViewColumnWidth(min: 180, ideal: 200)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            // Below the destinations rather than inside the list: this is the
            // window's own identity, not a destination, and making it selectable
            // would put "NepalKit 1.3.0" in the tab order next to real tabs.
            SettingsSidebarFooter(metadata: metadata)
        }
    }

    // MARK: - Detail

    @ViewBuilder
    private var detail: some View {
        switch tab {
        case .menuBar:
            MenuBarSettingsView(
                menuBar: menuBar,
                settings: settings.settings,
                updateAvailable: updates.isShowingReminder
            )
        case .general:
            GeneralSettingsView(
                settings: settings,
                loginItem: loginItem
            )
        case .about:
            AboutSettingsView(
                updates: updates,
                metadata: metadata,
                dataset: dataset
            )
        }
    }
}

/// The window's own identity, below the sidebar's destinations.
///
/// Icon, name, version and a link to the source. This is the answer to "what am I
/// running, and where do I go to tell someone?" — the two questions a person opens
/// Settings with most often, answered without hunting for the About tab.
///
/// It duplicates what the About tab says on purpose. That tab is the full record
/// (licence text, dataset provenance, the range boundary in words); this is the
/// always-visible strip. A version number that is only findable on one tab is not
/// findable when you are trying to read it off a screenshot.
private struct SettingsSidebarFooter: View {
    let metadata: AppMetadata

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 8) {
                if let icon = metadata.applicationIcon {
                    Image(nsImage: icon)
                        .resizable()
                        .frame(width: 32, height: 32)
                        // Decorative: the name is beside it and is what identifies
                        // the build. Exposed, this is a stop that only says
                        // "image" before the name that carries the meaning.
                        .accessibilityHidden(true)
                }
                VStack(alignment: .leading, spacing: 0) {
                    Text(metadata.name)
                        .font(.callout.weight(.medium))
                        .lineLimit(1)
                    Text(Strings.versionLabel(metadata.versionDescription))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
            }

            // A real link, never text styled to look like one. The repository URL
            // comes from the build's metadata, so it cannot drift from the remote
            // the app was published from.
            if let repository = metadata.repositoryURL {
                RepositoryGhostLink(repository: repository)
                    // Trailing, so it sits against the sidebar's right edge the way
                    // a window's toolbar accessory does rather than starting a row
                    // of its own under the version.
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        // Above the footer is the destination list, and a Divider is what stops
        // the identity strip reading as a fourth, unselectable destination.
        .background(.bar)
        .overlay(alignment: .top) { Divider() }
    }
}

/// The repository link, as a glyph that only becomes a button when you point at it.
///
/// Ghost treatment: invisible at rest, `.clear` glass on hover, `.regular`
/// interactive glass while hovered. The three states matter separately — `.clear`
/// keeps the shape sampling but shows no material, so the resting strip has no
/// visual weight at all, and `.interactive()` on the hovered state is what makes
/// it respond to the pointer rather than only to the cursor's position.
///
/// A square hit target around a small glyph: 22pt is under the 28pt minimum
/// comfortable target, so the frame is what makes it reliably clickable rather
/// than an icon you have to aim at.
///
/// The title is kept on the label and hidden with `.iconOnly`, so the accessible
/// name survives — the same reason the popover's gear does it that way. A bare
/// `Image` here would be announced as nothing at all, and this is the one control
/// in the window whose entire job is to be identified.
private struct RepositoryGhostLink: View {
    let repository: URL
    @State private var hovering = false

    var body: some View {
        Link(destination: repository) {
            Label(Strings.repositoryLabel, systemImage: Symbols.repository)
                .labelStyle(.iconOnly)
                .font(.caption)
                .symbolRenderingMode(.monochrome)
                .frame(width: 22, height: 22)
        }
        .buttonStyle(.plain)
        // Ghost: `.clear` at rest so nothing shows until the pointer arrives, then
        // real glass. Applied after the frame and the label style, because glass
        // wraps whatever layout it is given and sampling the wrong bounds is what
        // makes it look detached from its content.
        .glassEffect(hovering ? .regular.interactive() : .clear, in: .rect(cornerRadius: 6))
        .onHover { hovering = $0 }
        .accessibilityLabel(Strings.repositoryLabel)
        // The label says what the link is; the destination is the part a sighted
        // user reads off the screen and a blind user otherwise never learns, so it
        // becomes the value.
        .accessibilityValue(repository.absoluteString)
    }
}

#if DEBUG
/// Preview stand-ins so the canvas renders without Sparkle, the login-item
/// service, or persistence side effects. Nothing else may use these: the
/// production seams live in NepalKitApp, and a mock that leaked past #if DEBUG
/// would silently replace the real services. `PreviewUpdateService` is
/// MainActor because `UpdateServicing` requires it; `PreviewLoginService` stays
/// nonisolated because `LoginItemServicing` is nonisolated, and a MainActor
/// conformance only satisfies that protocol where default isolation agrees.
@MainActor private final class PreviewUpdateService: UpdateServicing {
    var onOutcome: (@MainActor (UpdateOutcome) -> Void)?
    var onReminder: (@MainActor (Bool) -> Void)?
    var automaticallyChecksForUpdates = true
    func start() {}
    func checkForUpdates() {}
}

private final class PreviewLoginService: LoginItemServicing {
    var isRegistered = true
    func register() throws {}
    func unregister() throws {}
}

#Preview("Settings window") {
    SettingsView(
        settings: .preview,
        loginItem: LoginItemModel(service: PreviewLoginService()),
        updates: UpdateCheckModel(service: PreviewUpdateService()),
        menuBar: MenuBarModel(now: AppData.previewInstant, refreshes: false),
        metadata: .current(),
        dataset: AppData.dataset
    )
    .frame(width: 700, height: 460)
}
#endif
