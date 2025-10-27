import UIKit
import CoreHaptics

enum HapticKind {
    case light
    case medium
    case rigid
    case heavy
    case selection

    func generator() -> UIFeedbackGenerator {
        switch self {
        case .light:
            return UIImpactFeedbackGenerator(style: .light)
        case .medium:
            return UIImpactFeedbackGenerator(style: .medium)
        case .rigid:
            return UIImpactFeedbackGenerator(style: .rigid)
        case .heavy:
            return UIImpactFeedbackGenerator(style: .rigid)
        case .selection:
            return UISelectionFeedbackGenerator()
        }
    }
}

struct Haptic {
    static func trigger(_ kind: HapticKind) {
        DispatchQueue.main.async {
            switch kind {
            case .light:
                let generator = UIImpactFeedbackGenerator(style: .light)
                generator.prepare()
                generator.impactOccurred(intensity: 0.45)
            case .medium:
                let generator = UIImpactFeedbackGenerator(style: .medium)
                generator.prepare()
                generator.impactOccurred(intensity: 0.75)
            case .rigid:
                if #available(iOS 13.0, *) {
                    let generator = UIImpactFeedbackGenerator(style: .rigid)
                    generator.prepare()
                    generator.impactOccurred(intensity: 0.9)
                } else {
                    let generator = UIImpactFeedbackGenerator(style: .heavy)
                    generator.prepare()
                    generator.impactOccurred()
                }
            case .heavy:
                let generator = UIImpactFeedbackGenerator(style: .heavy)
                generator.prepare()
                generator.impactOccurred(intensity: 1.0)
            case .selection:
                let generator = UISelectionFeedbackGenerator()
                generator.prepare()
                generator.selectionChanged()
            }
        }
    }
}
