import Foundation

extension Collection {
    /// Safely accesses the element at the specified index.
    /// Returns `nil` if the index is out of bounds.
    /// This prevents runtime crashes (Index Out of Bounds).
    subscript(safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}
