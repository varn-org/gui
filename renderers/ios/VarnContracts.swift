import UIKit

/// A view that reads the props of a whole batch at once rather than one at a time.
///
/// A centre, a zoom and a set of marks describe one region between them, and a map told each of them
/// separately moves three times for one change. The renderer applies a batch and then settles it, so
/// what a commit asked for is done once.
protocol VarnSettling {
    func settle()
}

/// A view holding something the platform hands out one of, which is given back when the view goes.
///
/// A camera and a microphone are the device's rather than the application's: one left running is the
/// indicator still showing over a screen the reader has already left. Dropping the view would give it
/// back eventually, and eventually is not when a reader is looking at the light.
protocol VarnReleasing {
    func letGo()
}
