//
//  ConfettiView.swift
//  CreditCardBenefits
//
//  Full-screen falling confetti (CAEmitterLayer), in the spirit of iMessage's
//  "send with confetti". Used to celebrate a card's captured benefits passing
//  its annual fee.
//

import SwiftUI
import UIKit

/// Drop-in SwiftUI confetti overlay. Emits for `emitDuration` seconds, then
/// lets the remaining particles fall out naturally.
struct ConfettiView: UIViewRepresentable {
    var emitDuration: TimeInterval = 4

    func makeUIView(context: Context) -> ConfettiUIView {
        let view = ConfettiUIView()
        view.emitDuration = emitDuration
        view.isUserInteractionEnabled = false
        view.backgroundColor = .clear
        return view
    }

    func updateUIView(_ uiView: ConfettiUIView, context: Context) {}
}

final class ConfettiUIView: UIView {

    var emitDuration: TimeInterval = 4
    private var emitter: CAEmitterLayer?

    override func layoutSubviews() {
        super.layoutSubviews()
        guard bounds.width > 0 else { return }

        if let emitter {
            // Keep the emitter spanning the top edge on rotation/resize.
            emitter.emitterPosition = CGPoint(x: bounds.midX, y: -20)
            emitter.emitterSize = CGSize(width: bounds.width, height: 1)
            return
        }
        startEmitting()
    }

    private func startEmitting() {
        let layer = CAEmitterLayer()
        layer.emitterShape = .line
        layer.emitterPosition = CGPoint(x: bounds.midX, y: -20)
        layer.emitterSize = CGSize(width: bounds.width, height: 1)
        layer.emitterCells = Self.makeCells()

        self.layer.addSublayer(layer)
        emitter = layer

        // Taper off after the emit window; particles already in flight keep
        // falling until their lifetime ends.
        DispatchQueue.main.asyncAfter(deadline: .now() + emitDuration) { [weak layer] in
            layer?.birthRate = 0
        }
    }

    // MARK: - Cells

    private static let confettiColors: [UIColor] = [
        UIColor(red: 0.10, green: 0.35, blue: 0.24, alpha: 1),  // forest
        UIColor(red: 0.42, green: 0.82, blue: 0.64, alpha: 1),  // mint
        UIColor(red: 0.98, green: 0.79, blue: 0.29, alpha: 1),  // gold
        UIColor(red: 0.95, green: 0.45, blue: 0.40, alpha: 1),  // coral
        UIColor(red: 0.38, green: 0.58, blue: 0.95, alpha: 1),  // blue
        UIColor(red: 0.72, green: 0.49, blue: 0.92, alpha: 1),  // purple
    ]

    private static func makeCells() -> [CAEmitterCell] {
        var cells: [CAEmitterCell] = []
        for color in confettiColors {
            // Rectangles (classic confetti strips)…
            if let rect = particleImage(color: color, size: CGSize(width: 8, height: 12), cornerRadius: 2) {
                cells.append(cell(with: rect))
            }
            // …plus some circles for variety.
            if let dot = particleImage(color: color, size: CGSize(width: 7, height: 7), cornerRadius: 3.5) {
                cells.append(cell(with: dot, birthRate: 3))
            }
        }
        return cells
    }

    private static func cell(with image: CGImage, birthRate: Float = 6) -> CAEmitterCell {
        let cell = CAEmitterCell()
        cell.contents = image
        cell.birthRate = birthRate
        cell.lifetime = 7
        cell.velocity = 220
        cell.velocityRange = 120
        cell.emissionLongitude = .pi          // straight down
        cell.emissionRange = 0.6
        cell.yAcceleration = 140              // gravity
        cell.spin = 3
        cell.spinRange = 4
        cell.scale = 0.6
        cell.scaleRange = 0.3
        return cell
    }

    private static func particleImage(
        color: UIColor,
        size: CGSize,
        cornerRadius: CGFloat
    ) -> CGImage? {
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { _ in
            color.setFill()
            UIBezierPath(
                roundedRect: CGRect(origin: .zero, size: size),
                cornerRadius: cornerRadius
            ).fill()
        }
        return image.cgImage
    }
}
