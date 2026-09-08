package dev.varn.gui

/**
 * A view that reads the props of a whole batch at once rather than one at a time.
 *
 * A centre, a zoom and a set of marks describe one region between them, so the renderer applies a
 * batch and then settles it, and what a commit asked for is drawn once.
 */
interface VarnSettling {
    fun settle()
}

/**
 * Something a node opened that has to be given back when the node goes.
 *
 * Detaching is not that: a cell that scrolls out of a list detaches and comes back, so a player closed
 * there is a sound that never plays again and a map whose fetchers were shut down never draws a tile
 * again. The renderer says when a node has gone, which is the one moment this is right.
 */
interface VarnReleasing {
    fun release()
}
