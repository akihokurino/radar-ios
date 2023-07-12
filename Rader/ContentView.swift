import SwiftUI

struct ContentView: View {
    @ObservedObject var handsfreeUWB = HandsfreeUWB()

    var body: some View {
        VStack {
            Text("\(handsfreeUWB.distance)").padding()

            Text("\(handsfreeUWB.receiveTime)").padding()

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
            .cornerRadius(4.0)
            .buttonStyle(PlainButtonStyle())
        }
    }
}
