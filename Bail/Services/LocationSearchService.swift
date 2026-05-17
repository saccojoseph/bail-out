import Combine
@preconcurrency import MapKit

/// Wraps MKLocalSearchCompleter for SwiftUI place autocomplete.
@MainActor
final class LocationSearchService: ObservableObject {
    @Published var query: String = "" {
        didSet { completer.queryFragment = query }
    }
    @Published var results: [MKLocalSearchCompletion] = []

    private let completer = MKLocalSearchCompleter()
    private let coordinator: Coordinator

    init() {
        coordinator = Coordinator()
        completer.delegate = coordinator
        completer.resultTypes = [.pointOfInterest, .address]

        // Bridge delegate → published property
        coordinator.onResults = { [weak self] completions in
            Task { @MainActor [weak self] in
                self?.results = completions
            }
        }
    }

    /// Resolve a completion into a full place name + address.
    func resolve(_ completion: MKLocalSearchCompletion) async -> (name: String, address: String)? {
        let request = MKLocalSearch.Request(completion: completion)
        request.resultTypes = [.pointOfInterest, .address]

        do {
            let response = try await MKLocalSearch(request: request).start()
            guard let item = response.mapItems.first else { return nil }
            let name = item.name ?? completion.title
            let address = [
                item.placemark.subThoroughfare,
                item.placemark.thoroughfare,
                item.placemark.locality,
                item.placemark.administrativeArea
            ]
            .compactMap { $0 }
            .joined(separator: " ")
            return (name: name, address: address.isEmpty ? completion.subtitle : address)
        } catch {
            print("[LocationSearch] resolve error: \(error.localizedDescription)")
            return nil
        }
    }

    func clear() {
        query = ""
        results = []
    }

    // MARK: - Delegate bridge (non-MainActor)

    private final class Coordinator: NSObject, MKLocalSearchCompleterDelegate, @unchecked Sendable {
        var onResults: (([MKLocalSearchCompletion]) -> Void)?

        func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
            onResults?(completer.results)
        }

        func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
            print("[LocationSearch] completer error: \(error.localizedDescription)")
        }
    }
}
