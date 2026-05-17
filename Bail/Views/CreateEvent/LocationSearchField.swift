import SwiftUI
import MapKit

/// A location text field with MKLocalSearchCompleter-powered autocomplete dropdown.
struct LocationSearchField: View {
    @Binding var locationName: String
    @Binding var locationAddress: String
    var placeholder: String = "Search for a place..."
    var onSelect: ((String, String) -> Void)? = nil   // (name, address)

    @StateObject private var search = LocationSearchService()
    @State private var isExpanded = false
    @State private var isResolving = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Search input
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(BailColor.textSecondary)
                    .font(.system(size: 14))
                TextField(placeholder, text: $search.query)
                    .font(.system(size: 16))
                    .foregroundColor(BailColor.textPrimary)
                    .tint(BailColor.accentStart)
                    .onChange(of: search.query) { _, newValue in
                        isExpanded = !newValue.isEmpty
                    }
                if isResolving {
                    ProgressView()
                        .scaleEffect(0.7)
                } else if !search.query.isEmpty {
                    Button(action: {
                        search.clear()
                        locationName = ""
                        locationAddress = ""
                        isExpanded = false
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(BailColor.textSecondary)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(BailColor.surface)
            .cornerRadius(BailRadius.md)
            .overlay(
                RoundedRectangle(cornerRadius: BailRadius.md)
                    .stroke(BailColor.border, lineWidth: 1)
            )

            // Dropdown results
            if isExpanded && !search.results.isEmpty {
                VStack(spacing: 0) {
                    ForEach(search.results.prefix(5), id: \.self) { completion in
                        Button(action: {
                            selectResult(completion)
                        }) {
                            HStack(spacing: 12) {
                                Image(systemName: "mappin.circle.fill")
                                    .foregroundColor(BailColor.accentStart)
                                    .font(.system(size: 18))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(completion.title)
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(BailColor.textPrimary)
                                        .lineLimit(1)
                                    if !completion.subtitle.isEmpty {
                                        Text(completion.subtitle)
                                            .font(.system(size: 12))
                                            .foregroundColor(BailColor.textSecondary)
                                            .lineLimit(1)
                                    }
                                }
                                Spacer()
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .background(BailColor.surface)
                .cornerRadius(BailRadius.md)
                .overlay(
                    RoundedRectangle(cornerRadius: BailRadius.md)
                        .stroke(BailColor.border, lineWidth: 1)
                )
                .padding(.top, 4)
            }
        }
        .onAppear {
            // Pre-fill search query if location already set
            if !locationName.isEmpty && search.query.isEmpty {
                search.query = locationName
                isExpanded = false
            }
        }
    }

    private func selectResult(_ completion: MKLocalSearchCompletion) {
        isResolving = true
        Task {
            if let result = await search.resolve(completion) {
                locationName = result.name
                locationAddress = result.address
                search.query = result.name
                onSelect?(result.name, result.address)
            } else {
                // Fallback to completion text
                locationName = completion.title
                locationAddress = completion.subtitle
                search.query = completion.title
                onSelect?(completion.title, completion.subtitle)
            }
            isExpanded = false
            isResolving = false
        }
    }
}

#Preview {
    ZStack {
        BailColor.background.ignoresSafeArea()
        VStack {
            LocationSearchField(
                locationName: .constant(""),
                locationAddress: .constant("")
            )
            .padding()
            Spacer()
        }
    }
}
