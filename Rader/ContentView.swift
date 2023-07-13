import NearbyInteraction
import SwiftUI

struct ContentView: View {
    @ObservedObject var handsfreeUWB = HandsfreeUWB()
    @State var lastValidDirections = [NIDiscoveryToken: SIMD3<Float>]()

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Circle()
                    .stroke(Color.gray, lineWidth: 1)
                    .frame(width: 300, height: 300)
                    .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
                
                ForEach(handsfreeUWB.discoveredPeers, id: \.token) { peer in
                    Circle()
                        .fill(Color.red)
                        .frame(width: 10, height: 10)
                        .offset(offset(for: peer))
                        .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
                }
                
                VStack {
                    ForEach(handsfreeUWB.discoveredPeers, id: \.token) { peer in
                        Text("距離: \(peer.distance)m").padding()
                        Text("方向: x=\(peer.direction?.x ?? 0.0) y=\(peer.direction?.y ?? 0.0) z=\(peer.direction?.z ?? 0.0)")
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        handsfreeUWB.sendDiscoveryToken()
                    }) {
                        HStack {
                            Spacer()
                            Text("セッション開始")
                                .foregroundColor(Color.white)
                                .fontWeight(.bold)
                            Spacer()
                        }
                    }
                    .padding(.horizontal, 5)
                    .padding(.vertical, 15)
                    .background(Color.blue)
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
        .onReceive(handsfreeUWB.$discoveredPeers) { peers in
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
