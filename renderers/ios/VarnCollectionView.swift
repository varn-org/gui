import UIKit

/// The scrolling surface a list, a grid and a carousel are all drawn on.
///
/// The engine decides which entries exist, which cell serves each one and where every cell sits, so
/// this holds the scrollable extent and reports the offset back. Reuse happens on the other side of
/// the bridge, where a cell that leaves the window is handed to the entry that takes its place.
final class VarnCollectionView: UIScrollView {
    private let content = VarnContentView()
    private var horizontal = false
    private var indicated = true
    private var extent: CGFloat = 0

    var onScroll: ((Any) -> Void)?
    var onScrollEnd: ((Any) -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        addSubview(content)
        delegate = self

        // A scroll view holds a touch back to see whether it is a scroll, so a quick press on something
        // inside it is delivered late and a quick one is swallowed altogether. The platform's own lists
        // hand the touch straight through and take it back when a scroll actually starts, which is why
        // a table row answers a finger on the first press rather than the second.
        delaysContentTouches = false
        canCancelContentTouches = true
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    /// Answers the view the engine parents its cells to, which is the layer that scrolls.
    var contentView: UIView { content }

    /// Takes the touch back from a row that is being dragged rather than pressed.
    ///
    /// A scroll view will not cancel a touch that landed on a `UIControl`, which is what protects a
    /// slider from being scrolled instead of dragged, and every pressable row is one of those — so a
    /// finger that landed on a row scrolled nothing at all. What is dragged keeps its touch, and
    /// everything else gives it up the way a table's rows do.
    override func touchesShouldCancel(in view: UIView) -> Bool {
        !(view is UISlider) && !(view is UISwitch)
    }

    /// Records the axis the surface scrolls along, which decides what the extent measures.
    func setHorizontal(_ value: Bool) {
        horizontal = value
        indicate()
        resize()
    }

    /// Records whether the surface draws a bar for the offset it is at.
    func setShowsIndicator(_ value: Bool) {
        indicated = value
        indicate()
    }

    /// A surface draws a bar only for the axis it scrolls, and the props deciding that arrive in no
    /// order, so both are held and the pair is worked out again whenever either lands.
    private func indicate() {
        showsVerticalScrollIndicator = indicated && !horizontal
        showsHorizontalScrollIndicator = indicated && horizontal
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
        let ended = atEnd
        let had = bounds.size

        super.layoutSubviews()
        resize()

        // A surface showing its last row goes on showing it when the room it has shrinks, which is what
        // the keyboard coming up does to a conversation: the composer rises with it and the message
        // being answered would otherwise slide away under the keyboard rather than staying in view.
        guard ended, bounds.height < had.height || bounds.width < had.width else {
            return
        }

        toEnd()
    }

    /// Whether the surface is showing the end of what it holds, within a point of it.
    ///
    /// A surface with nothing to scroll is not at its end, it is simply all there: reading it as one
    /// takes a list that fits and, the moment it grows past its box, throws it to the bottom.
    private var atEnd: Bool {
        let room = horizontal ? contentSize.width - bounds.width : contentSize.height - bounds.height

        guard room > 1 else {
            return false
        }

        return (horizontal ? contentOffset.x : contentOffset.y) >= room - 1
    }

    private func toEnd() {
        let offset = horizontal
            ? CGPoint(x: max(0, contentSize.width - bounds.width), y: contentOffset.y)
            : CGPoint(x: contentOffset.x, y: max(0, contentSize.height - bounds.height))

        guard offset != contentOffset else {
            return
        }

        setContentOffset(offset, animated: false)
    }

    /// Sizes the content layer, leaving the scroll view alone when nothing about it has changed.
    ///
    /// A scroll view lays out on every change of its offset, and writing `contentSize` makes UIKit clamp
    /// the offset again. Past the end that clamp fights the rubber band on every frame, which is a list
    /// that trembles wherever it is pulled beyond its last row.
    private func resize() {
        let size = horizontal
            ? CGSize(width: max(extent, bounds.width), height: bounds.height)
            : CGSize(width: bounds.width, height: max(extent, bounds.height))

        guard size != contentSize else {
            return
        }

        contentSize = size
        content.frame = CGRect(origin: .zero, size: size)
    }

    /// Keeps every box the tree pinned against the leading edge as the surface moves under it, and over
    /// whatever arrives beneath it.
    ///
    /// The tree cannot do the first: a commit follows a finger rather than leading it, so a header
    /// placed from there drifts across the rows it is meant to cover on every flick. It cannot do the
    /// second either: a row realised while the surface scrolls is inserted where the tree puts it, which
    /// is under the header it belongs to and over it on the screen. Raising one costs a reordering, so
    /// it is done when something loose has landed above it rather than on every frame.
    func hold() {
        let offset = horizontal ? contentOffset.x : contentOffset.y
        var covered: [VarnView] = []
        var loose = false

        for view in content.subviews.reversed() {
            guard let box = view as? VarnView, box.pinned != nil else {
                loose = true
                continue
            }

            let along = box.held(at: offset)

            if horizontal {
                box.frame.origin.x = along
            } else {
                box.frame.origin.y = along
            }

            if loose {
                covered.append(box)
            }
        }

        for box in covered.reversed() {
            content.bringSubviewToFront(box)
        }
    }
}

extension VarnCollectionView: UIScrollViewDelegate {
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        onScrollEnd?(["x": scrollView.contentOffset.x, "y": scrollView.contentOffset.y])
    }

    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate: Bool) {
        if !willDecelerate {
            onScrollEnd?(["x": scrollView.contentOffset.x, "y": scrollView.contentOffset.y])
        }
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        hold()
        reportOffset()
    }

    /// Says where the surface is now, which is what the engine asks for the moment it starts listening.
    ///
    /// A surface only ever reported the next time a finger moved it, so an engine that had just been
    /// told to care took the surface to be at the top: a field was lifted from the wrong place and the
    /// surface was put back somewhere it had never been.
    func reportOffset() {
        onScroll?(["x": contentOffset.x, "y": contentOffset.y])
    }
}
