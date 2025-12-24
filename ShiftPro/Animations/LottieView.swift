import SwiftUI

#if canImport(Lottie)
import Lottie

struct LottieView: UIViewRepresentable {
    let name: String
    var loopMode: LottieLoopMode = .loop

    func makeUIView(context: Context) -> LottieAnimationView {
        let view = LottieAnimationView(name: name)
        view.contentMode = .scaleAspectFit
        view.loopMode = loopMode
        view.play()
        return view
    }

    func updateUIView(_ uiView: LottieAnimationView, context: Context) {
        if uiView.animation?.name != name {
            uiView.animation = LottieAnimation.named(name)
            uiView.play()
        }
        uiView.loopMode = loopMode
    }
}
#endif
