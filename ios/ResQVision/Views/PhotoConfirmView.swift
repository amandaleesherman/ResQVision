import SwiftUI

/// Shows the captured/selected photo and lets the user confirm or retake it
/// before analysis runs.
struct PhotoConfirmView: View {
    let image: UIImage
    let onUse: () -> Void
    let onRetake: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.black)

            VStack(spacing: 12) {
                Text("Use this photo?")
                    .font(.headline)

                HStack(spacing: 16) {
                    Button(role: .cancel, action: onRetake) {
                        Label("Retake", systemImage: "arrow.counterclockwise")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)

                    Button(action: onUse) {
                        Label("Use Photo", systemImage: "checkmark")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding()
            .background(.ultraThinMaterial)
        }
    }
}

#Preview {
    PhotoConfirmView(
        image: UIImage(systemName: "photo") ?? UIImage(),
        onUse: {},
        onRetake: {}
    )
}
