import HearthDomain
import SwiftUI
import UIKit

/// The web pages a reply was written from, under its words: a heading and a list of their titles, each a link.
struct ReplySourcesSection: View {
    /// A reply lists only its first few pages; the button beside its actions opens them all.
    static let listedCount = 8

    let sources: [SourceViewConfiguration]

    var body: some View {
        VStack(alignment: .leading, spacing: HearthSpacing.s10) {
            Text(Strings.sourcesHeading)
                .font(.hearth(.body))
                .foregroundStyle(HearthColor.ink)
                .accessibilityAddTraits(.isHeader)
            ForEach(sources.prefix(Self.listedCount)) { source in
                HStack(alignment: .firstTextBaseline, spacing: HearthSpacing.s8) {
                    Text(verbatim: "•")
                        .font(.hearth(.body))
                        .foregroundStyle(HearthColor.ink)
                        .accessibilityHidden(true)
                    Link(destination: source.id) {
                        Text(source.title)
                            .font(.hearth(.body))
                            .underline()
                            .foregroundStyle(HearthColor.ink)
                            .lineSpacing(MarkdownSection.paragraphLineSpacing)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .accessibilityLabel(Strings.researchSource(number: source.number, title: source.title, host: source.host))
                }
                .padding(.leading, HearthSpacing.s8)
            }
        }
    }
}

/// Above a reply that searched the web: a quiet line that says so, and lists the pages it found when tapped.
struct ReplySearchedLine: View {
    let sources: [SourceViewConfiguration]

    @State private var isPresented = false

    var body: some View {
        Button(action: { isPresented = true }, label: {
            HStack(spacing: HearthSpacing.s6) {
                Image(systemName: "globe")
                    .accessibilityHidden(true)
                Text(Strings.searchedTheWeb)
                Image(systemName: "chevron.right")
                    .font(.hearth(.caption2).weight(.semibold))
                    .accessibilityHidden(true)
            }
            .font(.hearth(.footnote))
            .foregroundStyle(HearthColor.mute)
            .contentShape(Rectangle())
            .minimumHitTarget()
            .hoverHighlight(Capsule())
        })
        .buttonStyle(.plain)
        .accessibilityLabel(Strings.searchedTheWeb)
        .accessibilityHint(sources.count == 1 ? Strings.sourcesCountOne : Strings.sourcesCount(sources.count))
        .sheet(isPresented: $isPresented) {
            ReplySourcesSheet(sources: sources)
        }
    }
}

/// Beside a reply's actions: the marks of its first few sources and how many there are. Tapping it lists them all.
struct ReplySourcesButton: View {
    private static let markCount = 3
    /// How far each mark lies over the one before it.
    private static let markOverlap: CGFloat = -6

    let sources: [SourceViewConfiguration]

    @State private var isPresented = false

    var body: some View {
        let title = sources.count == 1 ? Strings.sourcesCountOne : Strings.sourcesCount(sources.count)
        Button(action: { isPresented = true }, label: {
            HStack(spacing: HearthSpacing.s6) {
                HStack(spacing: Self.markOverlap) {
                    ForEach(sources.prefix(Self.markCount)) { source in
                        SourceMark(host: source.host, address: source.id)
                            .overlay { Circle().strokeBorder(HearthColor.paper, lineWidth: HearthSize.hairline) }
                    }
                }
                .accessibilityHidden(true)
                Text(title)
                    .font(.hearth(.footnote))
                    .foregroundStyle(HearthColor.mute)
                    .lineLimit(1)
            }
            .padding(.horizontal, HearthSpacing.s6)
            .frame(minHeight: HearthSize.messageAction.height)
            .contentShape(Rectangle())
            .minimumHitTarget()
            .hoverHighlight(Capsule())
        })
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .sheet(isPresented: $isPresented) {
            ReplySourcesSheet(sources: sources)
        }
    }
}

/// Every page a reply was written from: its mark, its title and its site, each a link.
private struct ReplySourcesSheet: View {
    let sources: [SourceViewConfiguration]

    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(spacing: 0) {
            SheetHeader(title: Strings.researchSources) { dismiss() }
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(sources) { source in
                        row(source)
                        Hairline(axis: .horizontal)
                            .padding(.leading, HearthSpacing.s12 + SourceMark.side + HearthSpacing.s10)
                            .opacity(source.isLast ? 0 : 1)
                    }
                }
                .cardSurface()
                .padding(.horizontal, HearthSpacing.s16)
                .padding(.bottom, HearthSpacing.s24)
            }
        }
        .background(HearthColor.paper.ignoresSafeArea())
        .presentationDetents(dynamicTypeSize.isAccessibilitySize ? [.large] : [.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private func row(_ source: SourceViewConfiguration) -> some View {
        Link(destination: source.id) {
            HStack(alignment: .top, spacing: HearthSpacing.s10) {
                SourceMark(host: source.host, address: source.id)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: HearthSpacing.s2) {
                    Text(source.title)
                        .font(.hearth(.body))
                        .foregroundStyle(HearthColor.ink)
                        .lineLimit(dynamicTypeSize.isAccessibilitySize ? 3 : 1)
                        .multilineTextAlignment(.leading)
                    Text(source.host)
                        .font(.hearth(.footnote))
                        .foregroundStyle(HearthColor.mute)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, HearthSpacing.s12)
            .padding(.vertical, HearthSpacing.s12)
            .contentShape(Rectangle())
        }
        .accessibilityLabel(Strings.researchSource(number: source.number, title: source.title, host: source.host))
    }
}

/// A site's mark in a small circle: the icon the site shows for itself, fetched from the site once and then kept, or
/// the first letter of its name until that comes, and for a site that has none.
private struct SourceMark: View {
    static let side: CGFloat = 20

    /// The site's name as it is shown, whose first letter stands in for the icon.
    let host: String
    /// The page's address, whose host is asked for the icon.
    let address: URL

    @State private var icon: UIImage?
    @Environment(\.siteIcons) private var siteIcons

    var body: some View {
        ZStack {
            Text(verbatim: host.first.map { String($0).uppercased() } ?? "•")
                .font(.hearth(.caption2).weight(.semibold))
                .iconGlyphSize()
                .foregroundStyle(HearthColor.mute)
                .opacity(icon == nil ? 1 : 0)
            Image(uiImage: icon ?? UIImage())
                .resizable()
                .scaledToFill()
                .opacity(icon == nil ? 0 : 1)
        }
        .frame(width: Self.side, height: Self.side)
        .background(icon == nil ? HearthColor.bubble : HearthColor.card, in: Circle())
        .clipShape(Circle())
        .task(id: address.host()) {
            guard let name = address.host(), let data = await siteIcons.load(name) else {
                return
            }
            icon = UIImage(data: data)
        }
    }
}

extension EnvironmentValues {
    /// Where the icons of the sources' sites come from. Asks for nothing by default.
    @Entry var siteIcons: SiteIconProvider = .none
}
