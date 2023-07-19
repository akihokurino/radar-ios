import NearbyInteraction
import SwiftUI

struct ContentView: View {
    @ObservedObject var uwb = CBUWB()
    @State var lastValidDirections = [NIDiscoveryToken: SIMD3<Float>]()

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Circle()
                    .stroke(Color.gray, lineWidth: 1)
                    .frame(width: 300, height: 300)
                    .position(x: geometry.size.width / 2, y: geometry.size.height / 2)

                if uwb.discoveredPeers.count > 0 {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 10, height: 10)
                        .offset(offset(for: uwb.discoveredPeers.last!))
                        .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
                }

                VStack(alignment: .leading) {
                    if uwb.discoveredPeers.count > 0 {
                        Text("距離: \(uwb.discoveredPeers.last!.distance)m").font(.caption)
                        Text("方向: x=\(uwb.discoveredPeers.last!.direction?.x ?? 0.0) y=\(uwb.discoveredPeers.last!.direction?.y ?? 0.0) z=\(uwb.discoveredPeers.last!.direction?.z ?? 0.0)").font(.caption)
                        Spacer().frame(height: 5)
                    }
                }.frame(maxWidth: .infinity)
            }
        }
        .onReceive(uwb.$discoveredPeers) { peers in
            for peer in peers {
                if let direction = peer.direction {
                    self.lastValidDirections[peer.token] = direction
                }
            }
        }
    }

    private func offset(for peer: DiscoveredPeer) -> CGSize {
        guard let direction = peer.direction ?? lastValidDirections[peer.token] else {
            return CGSize.zero
        }

        let x = CGFloat(direction.x * 150)
        let y = CGFloat(direction.y * 150)

        return CGSize(width: x, height: -y)
    }
}
