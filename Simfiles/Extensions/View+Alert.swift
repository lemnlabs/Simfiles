//
//  View+Alert.swift
//  Simfiles
//
//  Copyright © 2026 Huigyun Jeong. All rights reserved.
//

import SwiftUI

extension View {
    func alert(
        item: Binding<AlertItem?>,
        @ViewBuilder actions: (AlertItem) -> some View = { _ in Button(.commonOk, role: .cancel) {}
        }
    ) -> some View {
        self.alert(
            item.wrappedValue.map { Text($0.title) } ?? Text(verbatim: ""),
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
