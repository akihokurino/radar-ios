import MultipeerConnectivity
import NearbyInteraction
import SwiftUI

// MultipeerConnectivityを使ったNI実装
class MCUWB: NSObject, UWB {
    private var _niSession: NISession!
    private var _mcSession: MCSession!
    private var _mcPeerID: MCPeerID!
    private var _mcAdvertiser: MCNearbyServiceAdvertiser!
    private var _mcBrowser: MCNearbyServiceBrowser!

    @Published var discoveredPeers = [DiscoveredPeer]()

    override init() {
        super.init()

        _niSession = NISession()
        _niSession.delegate = self

        _mcPeerID = MCPeerID(displayName: UIDevice.current.name)
        _mcSession = MCSession(peer: _mcPeerID, securityIdentity: nil, encryptionPreference: .required)
        _mcSession.delegate = self

        // 検索されるためのサービス
        _mcAdvertiser = MCNearbyServiceAdvertiser(peer: _mcPeerID, discoveryInfo: nil, serviceType: "radar")
        _mcAdvertiser.delegate = self
        _mcAdvertiser.startAdvertisingPeer()

        // 検索するためのサービス
        _mcBrowser = MCNearbyServiceBrowser(peer: _mcPeerID, serviceType: "radar")
        _mcBrowser.delegate = self
        _mcBrowser.startBrowsingForPeers()
    }

    private func sendDiscoveryToken() {
        guard let discoveryToken = _niSession.discoveryToken else {
            return
        }

        let data = try! NSKeyedArchiver.archivedData(withRootObject: discoveryToken, requiringSecureCoding: true)

        try! _mcSession.send(data, toPeers: _mcSession.connectedPeers, with: .reliable)
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
    
    // データを受け取った時に呼ばれる
    // ここで相手のdiscoveryTokenを手にいれる
    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        do {
            guard let discoveryToken = try NSKeyedUnarchiver.unarchivedObject(ofClass: NIDiscoveryToken.self, from: data) else {
                return
            }

            let config = NINearbyPeerConfiguration(peerToken: discoveryToken)
            _niSession.run(config)
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
    func browser(_ browser: MCNearbyServiceBrowser, didNotStartBrowsingForPeers error: Error) {}
}
