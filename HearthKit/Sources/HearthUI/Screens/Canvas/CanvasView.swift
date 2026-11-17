import HearthDomain
import SwiftUI

/// The canvas: one piece of a reply shown on its own, as it is meant to be seen or as it was written.
struct CanvasView: View {
    private static let switchWidth: CGFloat = 190
    private static let disabledOpacity = 0.35

    let presenter: CanvasPresenter

    @State private var isPreviewUnavailable = false

    var body: some View {
        let viewModel = presenter.viewModel
        let content = presenter.content
        VStack(spacing: 0) {
            header(content)
            controls(content)
            Hairline()
            ZStack {
                preview(content)
                    .opacity(content?.mode == .preview ? 1 : 0)
                    .allowsHitTesting(content?.mode == .preview)
                    .accessibilityHidden(content?.mode != .preview)
                CanvasCodeSection(code: content?.text ?? "", isWriting: content?.isWriting == true)
                    .opacity(content?.mode == .code ? 1 : 0)
                    .allowsHitTesting(content?.mode == .code)
                    .accessibilityHidden(content?.mode != .code)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(HearthColor.paper.ignoresSafeArea())
        .haptic(.success, trigger: viewModel.copyCount)
    }

    // MARK: Header

    /// The title and what it is, then copy, share and close.
    private func header(_ content: CanvasViewConfiguration?) -> some View {
        HStack(spacing: HearthSpacing.s4) {
            VStack(alignment: .leading, spacing: HearthSpacing.s2) {
                Text(content?.title ?? Strings.canvas)
                    .font(.hearth(.headline))
                    .foregroundStyle(HearthColor.ink)
                    .lineLimit(1)
                    .accessibilityAddTraits(.isHeader)
                Text(content?.isWriting == true ? Strings.canvasWriting : content?.detail ?? "")
                    .font(.hearth(.caption))
                    .foregroundStyle(HearthColor.mute)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            IconButton(systemImage: "doc.on.doc", label: Strings.canvasCopy, action: presenter.copyAction)
            ShareLink(item: content?.text ?? "") {
                Image(systemName: "square.and.arrow.up")
                    .font(HearthFont.icon)
                    .foregroundStyle(HearthColor.ink)
                    .frame(width: HearthSize.iconButton, height: HearthSize.iconButton)
                    .minimumHitTarget()
            }
            .accessibilityLabel(Strings.canvasShare)
            IconButton(systemImage: "xmark", label: Strings.canvasClose, action: presenter.closeAction)
        }
        .padding(.leading, HearthSpacing.s16)
        .padding(.trailing, HearthSpacing.s8)
        .padding(.top, HearthSpacing.s8)
    }

    /// The switch between the preview and the code, for a piece that has both, and the stepper between versions.
    private func controls(_ content: CanvasViewConfiguration?) -> some View {
        let hasPreview = content?.kind.hasPreview == true
        let hasVersions = (content?.versionCount ?? 1) > 1
        return HStack(spacing: HearthSpacing.s8) {
            Picker(Strings.canvasShowAs, selection: Bindable(presenter.viewModel).mode) {
                Text(Strings.canvasPreview).tag(CanvasModeKind.preview)
                Text(Strings.canvasCode).tag(CanvasModeKind.code)
            }
            .pickerStyle(.segmented)
            .frame(width: Self.switchWidth)
            // A piece still being written is shown as code whatever is chosen, so the switch waits for it.
            .disabled(content?.isWriting == true)
            .opacity(hasPreview ? 1 : 0)
            .allowsHitTesting(hasPreview)
            .accessibilityHidden(!hasPreview)
            .frame(maxWidth: .infinity, alignment: .leading)
            versionStepper(content)
                .opacity(hasVersions ? 1 : 0)
                .allowsHitTesting(hasVersions)
                .accessibilityHidden(!hasVersions)
        }
        .padding(.leading, HearthSpacing.s16)
        .padding(.trailing, HearthSpacing.s8)
        .padding(.vertical, HearthSpacing.s8)
    }

    /// Steps to an earlier or a later version, with the place of the one shown between the arrows.
    private func versionStepper(_ content: CanvasViewConfiguration?) -> some View {
        let number = content?.versionNumber ?? 1
        let total = content?.versionCount ?? 1
        return HStack(spacing: 0) {
            IconButton(systemImage: "chevron.left", label: Strings.canvasEarlier) {
                Haptics.play(.selection)
                presenter.stepAction(by: -1)
            }
            .disabled(content?.hasEarlier != true)
            .opacity(content?.hasEarlier == true ? 1 : Self.disabledOpacity)
            Text(Strings.canvasVersion(number: number, total: total))
                .font(.hearth(.footnote).monospacedDigit())
                .foregroundStyle(HearthColor.mute)
                .accessibilityLabel(Strings.versionPosition(number: number, total: total))
            IconButton(systemImage: "chevron.right", label: Strings.canvasLater) {
                Haptics.play(.selection)
                presenter.stepAction(by: 1)
            }
            .disabled(content?.hasLater != true)
            .opacity(content?.hasLater == true ? 1 : Self.disabledOpacity)
        }
    }

    // MARK: Preview

    /// A document laid out as a reply is; a page or a drawing in a web view shut off from the network.
    private func preview(_ content: CanvasViewConfiguration?) -> some View {
        let isDocument = content?.kind == .markdown
        // A page is handed over only once it is finished, so the web view is not loaded afresh with every word.
        let document = content.flatMap { $0.isWriting ? nil : CanvasWebPolicy().document(for: $0.kind, text: $0.text) }
        return ZStack {
            CanvasWebPreview(document: document, isUnavailable: $isPreviewUnavailable)
                .opacity(isDocument || isPreviewUnavailable ? 0 : 1)
                .accessibilityHidden(isDocument || isPreviewUnavailable)
            ScrollView {
                MarkdownSection(markdown: isDocument ? content?.text ?? "" : "")
                    .textSelection(.enabled)
                    .padding(HearthSpacing.s16)
                    .frame(maxWidth: HearthSize.readingWidth)
                    .frame(maxWidth: .infinity)
            }
            .opacity(isDocument ? 1 : 0)
            .allowsHitTesting(isDocument)
            .accessibilityHidden(!isDocument)
            Text(Strings.canvasPreviewUnavailable)
                .font(.hearth(.subheadline))
                .foregroundStyle(HearthColor.mute)
                .multilineTextAlignment(.center)
                .padding(HearthSpacing.s24)
                .opacity(isPreviewUnavailable && !isDocument ? 1 : 0)
                .accessibilityHidden(!isPreviewUnavailable || isDocument)
        }
    }
}
