import SwiftUI

struct SignatureCaptureView: View {
    @Binding var signatureData: Data?
    @State private var lines: [[CGPoint]] = []
    @State private var currentLine: [CGPoint] = []
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack {
                Text("Bitte unterschreiben Sie im Feld unten")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.top)

                Canvas { context, size in
                    for line in lines {
                        drawLine(context: context, points: line)
                    }
                    if !currentLine.isEmpty {
                        drawLine(context: context, points: currentLine)
                    }
                }
                .background(Color.white)
                .border(Color.gray.opacity(0.3), width: 1)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            currentLine.append(value.location)
                        }
                        .onEnded { _ in
                            lines.append(currentLine)
                            currentLine = []
                        }
                )
                .padding()

                HStack(spacing: 20) {
                    Button("Löschen") {
                        lines = []
                        currentLine = []
                    }
                    .foregroundStyle(.red)

                    Spacer()

                    Button("Speichern") {
                        saveSignature()
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color.appPrimary)
                }
                .padding(.horizontal)
                .padding(.bottom)
            }
            .navigationTitle("Unterschrift")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
            }
        }
    }

    private func drawLine(context: GraphicsContext, points: [CGPoint]) {
        guard points.count > 1 else { return }
        var path = Path()
        path.move(to: points[0])
        for point in points.dropFirst() {
            path.addLine(to: point)
        }
        context.stroke(path, with: .color(.black), lineWidth: 2.5)
    }

    @MainActor
    private func saveSignature() {
        let renderer = ImageRenderer(content:
            Canvas { context, size in
                for line in lines {
                    drawLine(context: context, points: line)
                }
            }
            .frame(width: 300, height: 150)
            .background(Color.white)
        )

        renderer.scale = 2.0
        if let image = renderer.uiImage {
            signatureData = image.pngData()
        }
    }
}

struct SignatureDisplayView: View {
    let signatureData: Data?
    let label: String
    var onTapCapture: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)

            if let data = signatureData, let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 60)
                    .background(Color.white)
                    .border(Color.gray.opacity(0.3), width: 1)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .onTapGesture(perform: onTapCapture)
            } else {
                Button(action: onTapCapture) {
                    HStack {
                        Image(systemName: "pencil.and.scribble")
                        Text("Unterschrift erfassen")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(Color.gray.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
        }
    }
}
