import Combine
import SwiftUI
import NearbyInteraction

protocol UWB: ObservableObject {
    var discoveredPeers: [DiscoveredPeer] { get set }
}

struct DiscoveredPeer {
    let token: NIDiscoveryToken
    let distance: Float
    let direction: SIMD3<Float>?
}
