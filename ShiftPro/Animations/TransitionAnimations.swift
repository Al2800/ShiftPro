import SwiftUI

enum ShiftProTransitions {
    static let cardExpand: AnyTransition = .opacity.combined(with: .move(edge: .bottom))
    static let modal: AnyTransition = .move(edge: .bottom).combined(with: .opacity)
    static let slideForward: AnyTransition = .move(edge: .trailing).combined(with: .opacity)
    static let slideBackward: AnyTransition = .move(edge: .leading).combined(with: .opacity)
    static let scaleFade: AnyTransition = .scale(scale: 0.96).combined(with: .opacity)
}

enum ShiftProTransition {
    static let cardReveal: AnyTransition = ShiftProTransitions.cardExpand
    static let modal: AnyTransition = ShiftProTransitions.modal
    static let slideForward: AnyTransition = ShiftProTransitions.slideForward
    static let slideBackward: AnyTransition = ShiftProTransitions.slideBackward
    static let scaleFade: AnyTransition = ShiftProTransitions.scaleFade
}
