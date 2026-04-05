import SwiftUI

struct AttachmentChipsView: View {
    let viewModel: RobotDetailViewModel

    static func hasAnyAttachmentInfo(_ viewModel: RobotDetailViewModel) -> Bool {
        DebugConfig.showAllCapabilities
            || viewModel.status?.dustbinAttached != nil
            || viewModel.status?.mopAttached != nil
            || viewModel.status?.waterTankAttached != nil
    }

    var body: some View {
        let hasInfo = Self.hasAnyAttachmentInfo(viewModel)
        if hasInfo {
            HStack(spacing: 4) {
                // Dust bin
                let dustbinAttached = viewModel.status?.dustbinAttached ?? (DebugConfig.showAllCapabilities ? true : nil)
                if let attached = dustbinAttached {
                    attachmentChip(
                        icon: "trash.fill",
                        label: String(localized: "attachment.dustbin_short"),
                        attached: attached
                    )
                }

                // Water tank
                let waterTankAttached = viewModel.status?.waterTankAttached ?? (DebugConfig.showAllCapabilities ? true : nil)
                if let attached = waterTankAttached {
                    attachmentChip(
                        icon: "drop.fill",
                        label: String(localized: "attachment.watertank_short"),
                        attached: attached
                    )
                }

                // Mop
                let mopAttached = viewModel.status?.mopAttached ?? (DebugConfig.showAllCapabilities ? false : nil)
                if let attached = mopAttached {
                    attachmentChip(
                        icon: "rectangle.portrait.bottomhalf.filled",
                        label: String(localized: "attachment.mop_short"),
                        attached: attached
                    )
                }
            }
        }
    }

    @ViewBuilder
    private func attachmentChip(icon: String, label: String, attached: Bool) -> some View {
        let color: Color = attached ? .green : .gray
        HStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 9))
            Text(label)
                .font(.caption2)
                .fontWeight(.medium)
        }
        .foregroundStyle(color)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.12))
        .clipShape(Capsule())
    }
}
