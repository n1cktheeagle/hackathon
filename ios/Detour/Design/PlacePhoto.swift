import SwiftUI

struct PlacePhoto: View {
    let place: PlaceReference
    let service: any PlaceProviding
    var height: CGFloat = 180
    @State private var image: UIImage?
    @State private var loading = false
    var body: some View {
        GeometryReader { geometry in
            Group {
                if let image {
                    Image(uiImage: image).resizable().scaledToFill()
                } else {
                    ZStack {
                        DetourTheme.muted
                        if loading { ProgressView() }
                        else { Image(systemName: place.category.symbol).font(.system(size: 32, weight: .light)).foregroundStyle(DetourTheme.secondary) }
                    }
                }
            }.frame(width: geometry.size.width, height: height).clipped()
        }
        .frame(height: height)
        .accessibilityLabel("Photo of \(place.name)")
        .task(id: place.photoName) {
            image = nil
            guard let name = place.photoName else { return }
            if name.hasPrefix("asset:") { image = UIImage(named: String(name.dropFirst(6))); return }
            loading = true
            defer { loading = false }
            do {
                guard let url = try await service.photoURL(name) else { return }
                let session = URLSession(configuration: .ephemeral)
                defer { session.invalidateAndCancel() }
                let (data, response) = try await session.data(from: url)
                guard !Task.isCancelled, (response as? HTTPURLResponse)?.statusCode == 200 else { return }
                image = UIImage(data: data)
            } catch { /* Missing images use the category placeholder. */ }
        }
    }
}
