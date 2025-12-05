import SwiftUI
import AVKit

struct AirPlayView: UIViewRepresentable {
    func makeUIView(context: Context) -> AVRoutePickerView {
        let routePickerView = AVRoutePickerView()
        routePickerView.activeTintColor = .systemBlue
        routePickerView.tintColor = .systemGray
        routePickerView.backgroundColor = .clear
        return routePickerView
    }

    func updateUIView(_ uiView: AVRoutePickerView, context: Context) {}
}
