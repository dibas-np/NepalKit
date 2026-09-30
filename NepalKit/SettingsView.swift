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
        // No sidebar toggle. Three destinations in a column the window already
        // sizes — there is nothing to collapse *to*, and the button only ever
        // produced a one-destination-wide window with no way back that was not the
        // button itself. Removed rather than hidden so it does not come back with
        // a future toolbar default.
        .toolbar(removing: .sidebarToggle)
        // Liquid Glass behind the whole window, so the sidebar and the detail are
        // one surface rather than two materials meeting at a seam. `.rect` rather
        // than a rounded shape: the window already clips its own corners, so a
        // radius here would only risk a sliver of unglassed background at the
        // corners when the user resizes.
        //
        // Applied after the frame, because glass wraps whatever layout it is given
        // and sampling bounds taken before layout are the ones that render wrong.
        .glassEffect(.regular, in: .rect)
        // Wide enough for the longest detail (About's Devanagari range line and a
        // full URL) beside the sidebar without clipping, and tall enough that the
        // General form's two sections do not need to scroll.
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
/// It repeats the version the About tab shows on purpose. That tab is where you go
/// to read it deliberately; this is the always-visible strip. A version number
/// that is only findable on one tab is not findable when you are trying to read it
/// off a screenshot.
private struct SettingsSidebarFooter: View {
    let metadata: AppMetadata

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
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
                SourceLink(repository: repository)
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

/// The repository link, labelled "Source".
///
/// Text, not a bare glyph. The earlier ghost treatment — a glyph that only
/// appeared on hover — was the wrong call twice over: it hid the only control
/// that takes you out of the app behind a pointer gesture, and a glyph that
/// appears on hover gives a keyboard user nothing to see. Naming it means it is
/// discoverable without a mouse, and it matches the popover footer, which shows
/// its "Quit" text for the same reason.
///
/// `.glass` like the popover footer's buttons, so the two surfaces' controls are
/// the same kind of object. The word is the short one because the row is narrow and
/// "Source repository" wraps; the announcement keeps the full phrase, because
/// "Source" alone does not say what it points at.
private struct SourceLink: View {
    let repository: URL

    var body: some View {
        Link(destination: repository) {
            // An explicit HStack, not a `Label`.
            //
            // `Label("Source", systemImage:)` under `.buttonStyle(.glass)` rendered
            // as the bare glyph: the word was simply not there. Whether the glass
            // style collapses a Label or the sidebar clipped it, `Label` leaves that
            // ambiguous — a Label is *allowed* to show only its icon, so the failure
            // is silent and looks intentional. `Text` beside `Image` has no such
            // mode: if the word is missing now, something is actually broken rather
            // than the label doing its job.
            HStack(spacing: 4) {
                Image(systemName: Symbols.repository)
                    .symbolRenderingMode(.monochrome)
                Text(Strings.sourceLinkTitle)
            }
            .font(.caption)
        }
        .buttonStyle(.glass)
        .lineLimit(1)
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
