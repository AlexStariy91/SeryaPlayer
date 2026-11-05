import SwiftUI

public extension View {
    /// Confirms a destructive action started from a swipe action, a context menu or a menu, where no button
    /// stays on screen to anchor a dialog. Pass the actions without a Cancel button: the system adds one.
    ///
    /// - iOS 26: an alert. A confirmation dialog there is a popover anchored to the view it is attached to; on
    ///   a whole screen it floats mid-screen with no Cancel button.
    /// - iOS 18: a confirmation dialog (an action sheet) with the title visible.
    @ViewBuilder
    func destructiveConfirmation(
        _ title: String,
        isPresented: Binding<Bool>,
        @ViewBuilder actions: () -> some View,
        @ViewBuilder message: () -> some View
    ) -> some View {
        #if compiler(>=6.2)
            if #available(iOS 26, *) {
                alert(title, isPresented: isPresented) {
                    actions()
                    Button(role: .cancel) {}
                } message: {
                    message()
                }
            } else {
                confirmationDialog(title, isPresented: isPresented, titleVisibility: .visible, actions: actions, message: message)
            }
        #else
            confirmationDialog(title, isPresented: isPresented, titleVisibility: .visible, actions: actions, message: message)
        #endif
    }

    /// `destructiveConfirmation` without a message.
    @ViewBuilder
    func destructiveConfirmation(_ title: String, isPresented: Binding<Bool>, @ViewBuilder actions: () -> some View) -> some View {
        #if compiler(>=6.2)
            if #available(iOS 26, *) {
                alert(title, isPresented: isPresented) {
                    actions()
                    Button(role: .cancel) {}
                }
            } else {
                confirmationDialog(title, isPresented: isPresented, titleVisibility: .visible, actions: actions)
            }
        #else
            confirmationDialog(title, isPresented: isPresented, titleVisibility: .visible, actions: actions)
        #endif
    }

    /// `destructiveConfirmation` for data that exists only while the confirmation is shown.
    @ViewBuilder
    func destructiveConfirmation<T>(
        _ title: String,
        isPresented: Binding<Bool>,
        presenting data: T?,
        @ViewBuilder actions: (T) -> some View,
        @ViewBuilder message: (T) -> some View
    ) -> some View {
        #if compiler(>=6.2)
            if #available(iOS 26, *) {
                alert(title, isPresented: isPresented, presenting: data) { data in
                    actions(data)
                    Button(role: .cancel) {}
                } message: { data in
                    message(data)
                }
            } else {
                confirmationDialog(
                    title, isPresented: isPresented, titleVisibility: .visible, presenting: data, actions: actions, message: message
                )
            }
        #else
            confirmationDialog(
                title, isPresented: isPresented, titleVisibility: .visible, presenting: data, actions: actions, message: message
            )
        #endif
    }
}
