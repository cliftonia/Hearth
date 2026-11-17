import SwiftUI

// The menu a chat in the list offers, and the dot on the settings button that says whether the server can be reached.
extension SidebarView {
    /// The width of the ring of paper that sets the dot apart from the button's edge.
    static let statusDotRingWidth: CGFloat = 2
    /// The width of the ring drawn while the server cannot be reached.
    static let offlineRingWidth: CGFloat = 2

    /// What a long press on a chat offers, in the same order and words as the chat's own menu: pin; rename, a project
    /// to file it in or leave, share; delete.
    @ViewBuilder
    func conversationMenu(for row: SidebarRowViewConfiguration) -> some View {
        Section {
            Button(action: {
                Haptics.play(.light)
                Task { await presenter.pinAction(row) }
            }, label: {
                Label(row.isPinned ? Strings.unpin : Strings.pin, systemImage: row.isPinned ? "pin.slash" : "pin")
            })
        }
        Section {
            Button(action: { presenter.renameAction(row) }, label: {
                Label(Strings.renameEllipsis, systemImage: "pencil")
            })
            Button(action: { presenter.addToProjectAction(row) }, label: {
                Label(
                    row.isInProject ? Strings.moveToProjectEllipsis : Strings.addToProjectEllipsis,
                    systemImage: row.isInProject ? "folder" : "folder.badge.plus"
                )
            })
            if row.isInProject {
                Button(action: { Task { await presenter.removeFromProjectAction(row) } }, label: {
                    Label(Strings.removeFromProject, systemImage: "folder.badge.minus")
                })
            }
            ShareLink(item: presenter.exportText(for: row.id)) {
                Label(Strings.share, systemImage: "square.and.arrow.up")
            }
        }
        Section {
            // Deleting is asked about first, since it cannot be undone and reaches every synced device.
            Button(role: .destructive, action: { presenter.requestDeleteAction(row.id) }, label: {
                Label(Strings.delete, systemImage: "trash")
            })
        }
    }

    /// Whether the server can be reached, told by shape as well as colour: a filled dot when it can, an empty ring
    /// when it cannot. VoiceOver reads it from the button's value.
    func statusDot(isOnline: Bool) -> some View {
        Circle()
            .fill(isOnline ? HearthColor.online : HearthColor.paper)
            .overlay {
                Circle().strokeBorder(HearthColor.mute, lineWidth: SidebarView.offlineRingWidth).opacity(isOnline ? 0 : 1)
            }
            .frame(width: HearthSize.statusDot, height: HearthSize.statusDot)
            // A ring of paper sets the dot apart from the button's edge.
            .padding(SidebarView.statusDotRingWidth)
            .background(HearthColor.paper, in: Circle())
            .accessibilityHidden(true)
    }
}
