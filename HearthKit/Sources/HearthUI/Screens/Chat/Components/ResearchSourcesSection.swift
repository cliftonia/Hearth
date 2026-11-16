import HearthDomain
import SwiftUI

/// One source of a report as it is listed: the number the report cites it by, its title and its site.
struct ResearchSourceViewConfiguration: Hashable, Identifiable {
    let id: URL
    let number: Int
    let title: String
    let host: String
    let isLast: Bool

    /// The sources of a report, numbered from one in the order the report cites them.
    static func list(from sources: [SearchSource]) -> [ResearchSourceViewConfiguration] {
        sources.enumerated().map { index, source in
            let host = source.url.host()?.replacingOccurrences(of: "www.", with: "") ?? ""
            let title = source.title.split(whereSeparator: \.isWhitespace).joined(separator: " ")
            return ResearchSourceViewConfiguration(
                id: source.url,
                number: index + 1,
                title: title.isEmpty ? host : title,
                host: host,
                isLast: index == sources.count - 1
            )
        }
    }
}

/// The pages a report was written from, under the report: each with its number, title and site, and each a link.
///
/// It is the full-length form of the pills under an ordinary reply that searched the web, drawn from the same
/// tokens; a report has more sources, and each is cited by number, so the titles are worth the room.
struct ResearchSourcesSection: View {
    /// Wide enough for a two-digit number, so that the titles line up.
    private static let numberWidth: CGFloat = 22

    let sources: [ResearchSourceViewConfiguration]

    var body: some View {
        VStack(alignment: .leading, spacing: HearthSpacing.s6) {
            Text(Strings.researchSources)
                .font(.hearth(.caption).weight(.medium))
                .textCase(.uppercase)
                .foregroundStyle(HearthColor.mute)
                .padding(.horizontal, HearthSpacing.s4)
                .accessibilityAddTraits(.isHeader)
            VStack(spacing: 0) {
                ForEach(sources) { source in
                    row(source)
                    Hairline(axis: .horizontal)
                        .padding(.leading, HearthSpacing.s12)
                        .opacity(source.isLast ? 0 : 1)
                }
            }
            .cardSurface()
        }
    }

    private func row(_ source: ResearchSourceViewConfiguration) -> some View {
        Link(destination: source.id) {
            HStack(alignment: .firstTextBaseline, spacing: HearthSpacing.s8) {
                Text(verbatim: "\(source.number)")
                    .font(.hearth(.footnote).monospacedDigit().weight(.medium))
                    .foregroundStyle(HearthColor.pine)
                    .frame(width: Self.numberWidth, alignment: .trailing)
                VStack(alignment: .leading, spacing: HearthSpacing.s2) {
                    Text(source.title)
                        .font(.hearth(.footnote))
                        .foregroundStyle(HearthColor.ink)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    Text(source.host)
                        .font(.hearth(.caption))
                        .foregroundStyle(HearthColor.mute)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, HearthSpacing.s12)
            .padding(.vertical, HearthSpacing.s10)
            .contentShape(Rectangle())
        }
        .accessibilityLabel(Strings.researchSource(number: source.number, title: source.title, host: source.host))
    }
}
