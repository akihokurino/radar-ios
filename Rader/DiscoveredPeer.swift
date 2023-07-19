import Foundation
import NearbyInteraction

struct DiscoveredPeer {
    let token: NIDiscoveryToken
    let distance: Float
    let direction: SIMD3<Float>?
}
