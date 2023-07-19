import MultipeerConnectivity
import NearbyInteraction
import SwiftUI

class MCUWB: NSObject, ObservableObject {
    private var _niSession: NISession!
    private var _mcSession: MCSession!
    private var _mcPeerID: MCPeerID!
    private var _mcAdvertiser: MCNearbyServiceAdvertiser!
    private var _mcBrowser: MCNearbyServiceBrowser!

    @Published var discoveredPeers = [DiscoveredPeer]()
    @Published var distance: Float = 0.0

    override init() {
        super.init()

        _niSession = NISession()
        _niSession.delegate = self

        _mcPeerID = MCPeerID(displayName: UIDevice.current.name)
        _mcSession = MCSession(peer: _mcPeerID, securityIdentity: nil, encryptionPreference: .required)
        _mcSession.delegate = self

        _mcAdvertiser = MCNearbyServiceAdvertiser(peer: _mcPeerID, discoveryInfo: nil, serviceType: "handsfree-uwb")
        _mcAdvertiser.delegate = self

        _mcBrowser = MCNearbyServiceBrowser(peer: _mcPeerID, serviceType: "handsfree-uwb")
        _mcBrowser.delegate = self
    }

    func sendDiscoveryToken() {
        guard let discoveryToken = _niSession.discoveryToken else {
            return
        }

        let data = try! NSKeyedArchiver.archivedData(withRootObject: discoveryToken, requiringSecureCoding: true)
    }
}

extension MCUWB: NISessionDelegate {
    func session(_ session: NISession, didUpdate nearbyObjects: [NINearbyObject]) {
        for object in nearbyObjects {
            let discoveredPeer = DiscoveredPeer(token: object.discoveryToken, distance: object.distance ?? 0.0, direction: object.direction)

            if let index = discoveredPeers.firstIndex(where: { $0.token == object.discoveryToken }) {
                discoveredPeers[index] = discoveredPeer
            } else {
                discoveredPeers.append(discoveredPeer)
            }
        }
    }
}

extension MCUWB: MCSessionDelegate {
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        guard state == .connected else { return }
        sendDiscoveryToken()
    }

    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        do {
            guard let discoveryToken = try NSKeyedUnarchiver.unarchivedObject(ofClass: NIDiscoveryToken.self, from: data) else {
                return
            }

            let config = NINearbyPeerConfiguration(peerToken: discoveryToken)
            _niSession.run(config)

//            sendDiscoveryToken()
        } catch {}
    }

    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {}

    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {}

    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {}
}

extension MCUWB: MCNearbyServiceAdvertiserDelegate {
    // 相手に検索され接続を要求された時に呼ばれる
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        invitationHandler(true, _mcSession)
    }
}

extension MCUWB: MCNearbyServiceBrowserDelegate {
    // 新しいピアが見つかった時に呼ばれる
    // 見つかったピアへの接続を行う
    func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String: String]?) {
        _mcBrowser.invitePeer(peerID, to: _mcSession, withContext: nil, timeout: 10)
    }

    // 既知のピアが見つからなくなった時に呼ばれる
    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {}

    // ブラウジングが失敗した場合に呼ばれる
    func browser(_ browser: MCNearbyServiceBrowser, didNotStartBrowsingForPeers error: Error) {
        print("Failed to start browsing for peers: \(error.localizedDescription)")
    }
}
