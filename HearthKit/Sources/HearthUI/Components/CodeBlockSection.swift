import SwiftUI
import UIKit

/// A block of code under a bar naming its language, coloured by its keywords, strings, comments and numbers, with
/// buttons that copy it and open it on a page of its own.
struct CodeBlockSection: View {
    let language: String?
    let code: String

    @State private var copyCount = 0
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 0) {
                Text(language ?? Strings.code)
                    .font(.hearth(.caption))
                    .foregroundStyle(HearthColor.mute)
                    .frame(maxWidth: .infinity, alignment: .leading)
                CodeBarButton(systemImage: "doc.on.doc", label: Strings.copyCode, action: copyAction)
                CodeBarButton(systemImage: "arrow.up.left.and.arrow.down.right", label: Strings.expandCode) { isExpanded = true }
            }
            .padding(.leading, HearthSpacing.s12)
            .padding(.trailing, HearthSpacing.s4)
            Hairline()
            ScrollView(.horizontal, showsIndicators: false) {
                Text(ParsedMarkdown.code(code, language: language))
                    .font(HearthFont.code)
                    .textSelection(.enabled)
                    .padding(HearthSpacing.s12)
            }
        }
        .cardSurface()
        .haptic(.success, trigger: copyCount)
        .sheet(isPresented: $isExpanded) {
            CodeSheet(language: language, code: code)
        }
    }

    private func copyAction() {
        UIPasteboard.general.string = code
        copyCount += 1
    }
}

/// One of the small buttons in the bar above a block of code.
private struct CodeBarButton: View {
    private static let size = CGSize(width: 32, height: 28)

    let systemImage: String
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.hearth(.caption))
                .foregroundStyle(HearthColor.mute)
                .frame(size: Self.size)
                .contentShape(Rectangle())
                .hoverHighlight(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .largeContentLabel(label, systemImage: systemImage)
    }
}

/// A block of code on a page of its own, where long lines and many of them can be read by scrolling either way.
private struct CodeSheet: View {
    let language: String?
    let code: String

    @State private var copyCount = 0
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            SheetHeader(title: language ?? Strings.code) { dismiss() }
            ScrollView([.horizontal, .vertical]) {
                Text(ParsedMarkdown.code(code, language: language))
                    .font(HearthFont.code)
                    .textSelection(.enabled)
                    .padding(HearthSpacing.s16)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .cardSurface()
            .padding(.horizontal, HearthSpacing.s16)
            Button(action: copyAction) {
                Label(Strings.copyCode, systemImage: "doc.on.doc")
                    .font(.hearth(.subheadline).weight(.semibold))
                    .foregroundStyle(HearthColor.onPine)
                    .frame(maxWidth: .infinity, minHeight: HearthSize.minimumHitTarget)
                    .background(HearthColor.pine, in: Capsule())
                    .hoverHighlight(Capsule())
            }
            .buttonStyle(.plain)
            .padding(HearthSpacing.s16)
        }
        .background(HearthColor.paper.ignoresSafeArea())
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .haptic(.success, trigger: copyCount)
    }

    private func copyAction() {
        UIPasteboard.general.string = code
        copyCount += 1
    }
}
