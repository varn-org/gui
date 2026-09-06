import UIKit

/// The scrolling surface a list, a grid and a carousel are all drawn on.
///
/// The engine decides which entries exist, which cell serves each one and where every cell sits, so
/// this holds the scrollable extent and reports the offset back. Reuse happens on the other side of
/// the bridge, where a cell that leaves the window is handed to the entry that takes its place.
final class VarnCollectionView: UIScrollView {
    private let content = VarnContentView()
    private var horizontal = false
    private var extent: CGFloat = 0

    var onScroll: ((Any) -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        addSubview(content)
        delegate = self
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    /// Answers the view the engine parents its cells to, which is the layer that scrolls.
    var contentView: UIView { content }

    /// Records the axis the surface scrolls along, which decides what the extent measures.
    func setHorizontal(_ value: Bool) {
        horizontal = value
        resize()
    }

    /// Records how far the surface scrolls, which is every entry the engine knows about.
    func setContentExtent(_ value: CGFloat) {
        extent = value
        resize()
    }

    /// Moves an index into view, which the engine has already turned into an offset.
    func scroll(to offset: CGPoint, animated: Bool) {
        setContentOffset(offset, animated: animated)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        resize()
    }

    private func resize() {
        let size = horizontal
            ? CGSize(width: max(extent, bounds.width), height: bounds.height)
            : CGSize(width: bounds.width, height: max(extent, bounds.height))

        contentSize = size
        content.frame = CGRect(origin: .zero, size: size)
    }
}

extension VarnCollectionView: UIScrollViewDelegate {
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        onScroll?(["x": scrollView.contentOffset.x, "y": scrollView.contentOffset.y])
    }
}
