import UIKit
import CoreImage

/// Draws a picture through the colour matrix a filter came to.
///
/// The engine sends the matrix rather than the amounts it was written from, so what a caller asked for is
/// worked out once and three platforms cannot each round their own way. Twenty numbers, read as four rows
/// of five: how much of each channel a channel is made of, and what is added to it.
enum VarnFilter {
    static let width = 5
    static let rows = 4

    /// Answers the picture drawn through a matrix, or the picture itself when there is nothing to apply.
    static func apply(_ matrix: [Double]?, to image: UIImage?) -> UIImage? {
        guard let image, let matrix else {
            return image
        }

        guard let source = CIImage(image: image) ?? image.cgImage.map({ CIImage(cgImage: $0) }),
              let output = filtered(matrix, source),
              let drawn = rendered(output) else {
            return image
        }

        return UIImage(cgImage: drawn, scale: image.scale, orientation: image.imageOrientation)
    }

    /// Answers one drawing seen through a matrix, which is what a preview and a photograph both need.
    static func filtered(_ matrix: [Double], _ image: CIImage) -> CIImage? {
        guard matrix.count == rows * width else {
            return nil
        }

        let filter = CIFilter(name: "CIColorMatrix")
        filter?.setValue(image, forKey: kCIInputImageKey)
        filter?.setValue(vector(matrix, 0), forKey: "inputRVector")
        filter?.setValue(vector(matrix, 1), forKey: "inputGVector")
        filter?.setValue(vector(matrix, 2), forKey: "inputBVector")
        filter?.setValue(vector(matrix, 3), forKey: "inputAVector")
        filter?.setValue(bias(matrix), forKey: "inputBiasVector")

        return filter?.outputImage
    }

    /// Draws what a filter answered into pixels, which is the one step that costs anything.
    static func rendered(_ image: CIImage?) -> CGImage? {
        guard let image else {
            return nil
        }

        return context.createCGImage(image, from: image.extent)
    }

    /// One context for every picture, since building one per filter builds a renderer per picture.
    ///
    /// It is told to manage no colour at all, which is what makes one filter one picture on all three:
    /// Core Image works in linear light unless it is asked not to, so the matrix would have been applied
    /// to something other than the numbers the browser and Android each apply it to, and a picture in
    /// black and white came out twice as bright on the phone as on the page.
    private static let context = CIContext(options: [
        .useSoftwareRenderer: false,
        .workingColorSpace: NSNull(),
    ])

    /// How much of each channel one channel is made of, which is a row of the matrix without its offset.
    private static func vector(_ matrix: [Double], _ row: Int) -> CIVector {
        CIVector(
            x: CGFloat(matrix[row * width]),
            y: CGFloat(matrix[row * width + 1]),
            z: CGFloat(matrix[row * width + 2]),
            w: CGFloat(matrix[row * width + 3])
        )
    }

    /// What is added to each channel, which is the last column of the matrix.
    private static func bias(_ matrix: [Double]) -> CIVector {
        CIVector(
            x: CGFloat(matrix[width - 1]),
            y: CGFloat(matrix[width * 2 - 1]),
            z: CGFloat(matrix[width * 3 - 1]),
            w: CGFloat(matrix[width * 4 - 1])
        )
    }
}
