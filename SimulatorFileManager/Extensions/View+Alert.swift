import SwiftUI

extension View {
    func alert(
        item: Binding<AlertItem?>,
        @ViewBuilder actions: (AlertItem) -> some View = { _ in Button("확인", role: .cancel) {} }
    ) -> some View {
        self.alert(
            item.wrappedValue?.title ?? "",
            isPresented: Binding(
                get: { item.wrappedValue != nil },
                set: { isPresented in
                    if !isPresented {
                        item.wrappedValue = nil
                    }
                }
            ),
            presenting: item.wrappedValue
        ) { alert in
            actions(alert)
        } message: { alert in
            Text(alert.message)
        }
    }
}
