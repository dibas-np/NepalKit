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
        // A minimum, not a fixed width. Pinned at 380 the window clips its
        // contents once the user increases text size, and the widest content
        // here is a long Devanagari-supported range plus a full URL — the exact
        // combination most likely to overflow. The window still opens at the
        // same size; it just no longer refuses to grow.
        .frame(minWidth: 380)
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 6) {
            if let icon = metadata.applicationIcon {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 64, height: 64)
                    // Decorative: the app name is the next element down and is
                    // already announced. Exposed, this is a stop that only
                    // says "image" before the name that identifies the app.
                    .accessibilityHidden(true)
            }
            Text(metadata.name)
                .font(.title2.weight(.medium))
                .accessibilityAddTraits(.isHeader)
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
            row(
                Strings.supportedRangeLabel,
                Strings.supportedRange(dataset.supportedRange),
                spoken: Strings.supportedRangeSpoken(dataset.supportedRange)
            )

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
                    // The title already says what the link is. The
                    // destination is the part a sighted user reads off the
                    // screen and a blind user otherwise never learns, so it
                    // becomes the value.
                    .accessibilityValue(repository.absoluteString)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// A label and its value as one announced element.
    ///
    /// Left as two `Text`s these are two focus stops, and a value is not
    /// meaningful without the label that names it — "2.0.0" alone says nothing.
    /// `spoken` exists for values whose shown punctuation a voice misreads; it
    /// falls back to the shown value when there is nothing to improve.
    private func row(_ label: String, _ value: String, spoken: String? = nil) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer(minLength: 12)
            Text(value)
                .monospacedDigit()
        }
        .font(.callout)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(spoken ?? value)")
    }
}
