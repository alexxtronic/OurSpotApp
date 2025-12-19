import SwiftUI
import MapKit
import Combine

/// Observable class that handles address autocomplete using MKLocalSearchCompleter
@MainActor
class AddressCompleter: NSObject, ObservableObject, MKLocalSearchCompleterDelegate {
    @Published var suggestions: [MKLocalSearchCompletion] = []
    
    private let completer: MKLocalSearchCompleter
    
    override init() {
        completer = MKLocalSearchCompleter()
        super.init()
        completer.delegate = self
        completer.resultTypes = [.address, .pointOfInterest]
        
        // Default to global search, region update helps prioritization but isn't strict
    }
    
    func search(query: String) {
        guard query.count >= 2 else {
            suggestions = []
            return
        }
        completer.queryFragment = query
    }
    
    nonisolated func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        Task { @MainActor in
            // Limit to 5 suggestions for cleaner UI
            self.suggestions = Array(completer.results.prefix(5))
        }
    }
    
    nonisolated func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        Task { @MainActor in
            print("Address completer error: \(error.localizedDescription)")
            self.suggestions = []
        }
    }
}
