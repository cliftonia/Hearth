import SwiftUI

/// Arranges the composer's field, its leading controls and its trailing controls.
///
/// At rest the three sit in one row. While a message is being written the field takes a row of its own above the
/// controls. The field is the same view in both, so it keeps the keyboard as the arrangement changes.
struct ComposerLayout: Layout {
    let isCompact: Bool
    let spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        guard let parts = Parts(subviews) else { return .zero }
        let width = proposal.width ?? parts.leading.width + parts.trailing.width + Self.restingFieldWidth
        let field = parts.field.sizeThatFits(ProposedViewSize(width: fieldWidth(in: width, parts: parts), height: nil))
        let controlsHeight = max(parts.leading.height, parts.trailing.height)
        let height = isCompact ? max(field.height, controlsHeight) : field.height + spacing + controlsHeight
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        guard let parts = Parts(subviews) else { return }
        let fieldProposal = ProposedViewSize(width: fieldWidth(in: bounds.width, parts: parts), height: nil)
        let leading = ProposedViewSize(parts.leading)
        let trailing = ProposedViewSize(parts.trailing)
        if isCompact {
            parts.field.place(at: CGPoint(x: bounds.minX + parts.leading.width + spacing, y: bounds.midY), anchor: .leading, proposal: fieldProposal)
            parts.leadingView.place(at: CGPoint(x: bounds.minX, y: bounds.midY), anchor: .leading, proposal: leading)
            parts.trailingView.place(at: CGPoint(x: bounds.maxX, y: bounds.midY), anchor: .trailing, proposal: trailing)
        } else {
            let controlsMidY = bounds.maxY - max(parts.leading.height, parts.trailing.height) / 2
            parts.field.place(at: CGPoint(x: bounds.minX, y: bounds.minY), anchor: .topLeading, proposal: fieldProposal)
            parts.leadingView.place(at: CGPoint(x: bounds.minX, y: controlsMidY), anchor: .leading, proposal: leading)
            parts.trailingView.place(at: CGPoint(x: bounds.maxX, y: controlsMidY), anchor: .trailing, proposal: trailing)
        }
    }

    private func fieldWidth(in width: CGFloat, parts: Parts) -> CGFloat {
        isCompact ? max(0, width - parts.leading.width - parts.trailing.width - spacing * 2) : width
    }

    private static let restingFieldWidth: CGFloat = 160

    /// The three views in the order they are given: the field, the leading controls, the trailing controls.
    private struct Parts {
        let field: LayoutSubview
        let leadingView: LayoutSubview
        let trailingView: LayoutSubview
        let leading: CGSize
        let trailing: CGSize

        init?(_ subviews: Subviews) {
            guard subviews.count == 3 else { return nil }
            field = subviews[0]
            leadingView = subviews[1]
            trailingView = subviews[2]
            leading = leadingView.sizeThatFits(.unspecified)
            trailing = trailingView.sizeThatFits(.unspecified)
        }
    }
}
