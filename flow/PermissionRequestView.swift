import SwiftUI

struct PermissionRequestView: View {
    let request: PermissionRequest
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        VStack(spacing: 20) {
            Text("Permission Request")
                .font(.title)

            Text(
                "The extension \"\(request.extensionName)\" is requesting the following permissions:"
            )
            .multilineTextAlignment(.center)

            VStack(alignment: .leading, spacing: 8) {
                ForEach(request.permissions, id: \.self) { permission in
                    Text("• \(permission)")
                }
            }
            .padding()
            .background(Color(NSColor.windowBackgroundColor))
            .cornerRadius(8)

            HStack(spacing: 20) {
                Button("Deny") {
                    request.onComplete(false)
                    presentationMode.wrappedValue.dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Button("Allow") {
                    request.onComplete(true)
                    presentationMode.wrappedValue.dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
        .frame(minWidth: 300, idealWidth: 400)
    }
}
