//
//  FitWidthImageView.swift
//  Claveo
//

import SwiftUI

struct FitWidthImageView: View {
    let image: UIImage
    let width: CGFloat
    let detections: [OMRBoundingBox]
    let onTap: (OMRBoundingBox?) -> Void

    var body: some View {
        let imgW = image.size.width
        let scale = imgW / width

        ScrollView(.vertical, showsIndicators: true) {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(width: width)
                .contentShape(Rectangle())
                .onTapGesture(count: 1, coordinateSpace: .local) { location in
                    let x = location.x * scale
                    let y = location.y * scale
                    let box = boxAt(point: CGPoint(x: x, y: y), in: detections)
                    onTap(box)
                }
        }
    }

    private func boxAt(point: CGPoint, in detections: [OMRBoundingBox]) -> OMRBoundingBox? {
        let x = Float(point.x), y = Float(point.y)
        let containing = detections.filter { box in
            x >= box.x1 && x <= box.x2 && y >= box.y1 && y <= box.y2
        }
        return containing.min { ($0.x2 - $0.x1) * ($0.y2 - $0.y1) < ($1.x2 - $1.x1) * ($1.y2 - $1.y1) }
    }
}
