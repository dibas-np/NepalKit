import NepalKitCore
import SwiftUI

/// The About surface: what you are running, what it is based on, and under what
/// terms. Deliberately not a help system — no troubleshooting, no links to
/// documentation that does not exist yet.
///
/// Every value comes from somewhere authoritative. Versions and the icon come
/// from the bundle via `AppMetadata`; the dataset version and supported range
/// come from the dataset itself. Nothing is a literal, because a literal here
/// goes stale at the next release with nothing failing — the supported range has
/// already been narrowed once (ADR-0010), and a hardcoded copy would have
/// survived it silently.
///
/// The attribution line is worded to be exactly as strong as the evidence. The
/// shipped table is cross-checked month-by-month against a second community
/// table, but it is derived from one base table across its entire range, so this
/// must not imply independent licensing.
struct AboutView: View {
    let metadata: AppMetadata
    /// Injected so the calendar facts are the same dataset the rest of the app
    /// converts with, and so a test can control them.
    let dataset: CalendarDataset

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            details
        }
        .frame(width: 380)
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 6) {
            if let icon = metadata.applicationIcon {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 64, height: 64)
            }
            Text(metadata.name)
                .font(.title2.weight(.medium))
            Text(Strings.versionLabel(metadata.versionDescription))
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Details

    private var details: some View {
        VStack(alignment: .leading, spacing: 8) {
            row(Strings.calendarDataLabel, Strings.datasetVersionLabel(dataset.version))
            row(Strings.supportedRangeLabel, Strings.supportedRange(dataset.supportedRange))

            Text(Strings.calendarDataAttribution)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if let copyright = metadata.copyright {
                Text(copyright)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            // Real links, never text styled to look like a link. The repository
            // URL comes from the build's metadata, so it cannot drift from the
            // remote the app was actually published from.
            if let repository = metadata.repositoryURL {
                Link(Strings.repositoryLabel, destination: repository)
                    .font(.footnote)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer(minLength: 12)
            Text(value)
                .monospacedDigit()
        }
        .font(.callout)
    }
}
