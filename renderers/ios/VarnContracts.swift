import UIKit

/// A view that reads the props of a whole batch at once rather than one at a time.
///
/// A centre, a zoom and a set of marks describe one region between them, and a map told each of them
/// separately moves three times for one change. The renderer applies a batch and then settles it, so
/// what a commit asked for is done once.
protocol VarnSettling {
    func settle()
}
