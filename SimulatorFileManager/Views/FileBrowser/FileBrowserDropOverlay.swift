import SwiftUI

struct FileBrowserDropOverlay: View {
    var body: some View {
        ZStack {
            Rectangle()
                .fill(.tint.quinary)

            RoundedRectangle(cornerRadius: 8)
                .inset(by: 4)
                .strokeBorder(
                    .tint,
                    style: StrokeStyle(lineWidth: 2, dash: [6, 4])
                )

            VStack(spacing: 8) {
                Image(systemName: "arrow.down.doc.fill")
                    .font(.largeTitle)
                    .foregroundStyle(.tint)

                Text("이 폴더로 파일 복사")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.tint)
            }
        }
    }
}
