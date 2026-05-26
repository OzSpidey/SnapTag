import SwiftUI

/// Canvas-based bounding box renderer. A single `drawingGroup()` draw call
/// for all boxes avoids the layout overhead of a `ZStack` of `Rectangle` views.
///
/// Coordinate conversion:
/// Vision normalises bounding boxes with origin at the *bottom-left* of the image.
/// SwiftUI's coordinate system has origin at the *top-left*.
/// Conversion: `swiftUIY = (1 - visionBox.maxY) * viewHeight`
struct BoundingBoxOverlay: View {
    let objects: [DetectedObject]
    /// The rect of the displayed image *within* the parent view,
    /// used to map Vision normalised coordinates to screen points.
    let imageFrame: CGRect

    var body: some View {
        Canvas { context, _ in
            for object in objects {
                let rect = visionToView(box: object.boundingBox)
                guard rect.width > 0, rect.height > 0 else { continue }

                // Box stroke
                let path = Path(roundedRect: rect, cornerRadius: 4)
                context.stroke(path,
                               with: .color(object.color),
                               style: StrokeStyle(lineWidth: 2.5, lineCap: .round))

                // Label badge
                drawLabel(context: context, text: object.label, confidence: object.confidencePercent, rect: rect, color: object.color)
            }
        }
        .allowsHitTesting(false)  // transparent to gestures below
    }

    // MARK: - Coordinate mapping

    private func visionToView(box: CGRect) -> CGRect {
        CGRect(
            x:      imageFrame.minX + box.minX  * imageFrame.width,
            y:      imageFrame.minY + (1 - box.maxY) * imageFrame.height,
            width:  box.width  * imageFrame.width,
            height: box.height * imageFrame.height
        )
    }

    // MARK: - Label drawing

    private func drawLabel(context: GraphicsContext, text: String, confidence: Int, rect: CGRect, color: Color) {
        let label = "\(text) \(confidence)%"
        let font = Font.system(size: 11, weight: .semibold)
        let resolved = context.resolve(Text(label).font(font).foregroundColor(.white))
        let textSize = resolved.measure(in: CGSize(width: 200, height: 30))
        let padding: CGFloat = 4
        let badgeRect = CGRect(
            x:      rect.minX,
            y:      max(0, rect.minY - textSize.height - padding * 2),
            width:  textSize.width + padding * 2,
            height: textSize.height + padding * 2
        )
        // Badge background
        let bgCtx = context
        bgCtx.fill(Path(roundedRect: badgeRect, cornerRadius: 3), with: .color(color))
        // Badge text
        context.draw(resolved, at: CGPoint(
            x: badgeRect.minX + padding,
            y: badgeRect.minY + padding
        ), anchor: .topLeading)
    }
}
