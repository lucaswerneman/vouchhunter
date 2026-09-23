import SwiftUI
import RealityKit
import ARKit
import AVFoundation
import HuntCore

struct CaptureView:View {
    let stop:Stop
    let collect:() async throws -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var allowed=false
    @State private var ready=false
    @State private var busy=false
    @State private var success=false
    @State private var error=""
    var body:some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if allowed {PizzaARView(ready:$ready).ignoresSafeArea()}
            VStack(spacing:18){
                HStack{Button{dismiss()}label:{Image(systemName:"xmark").padding(14).background(.ultraThinMaterial,in:Circle())}.accessibilityLabel("Stäng kameran");Spacer();Text(stop.name).font(.headline).padding(12).background(.ultraThinMaterial,in:Capsule())}
                Spacer()
                if success {Label("Insamlad!",systemImage:"checkmark.circle.fill").font(.largeTitle.bold()).foregroundStyle(.white)}
                else {Text(ready ? "Där är din pizza." : "Rikta kameran mot en öppen yta.").font(.title2.bold()).foregroundStyle(.white);Text(ready ? "Tryck för att lägga den till din samling." : "Rör telefonen långsamt så hittar vi marken.").foregroundStyle(.white)}
                if !error.isEmpty{Text(error).foregroundStyle(.white).padding().background(.red.opacity(0.8),in:RoundedRectangle(cornerRadius:12))}
                if !allowed && !error.isEmpty {Button("Öppna inställningar"){if let url=URL(string:UIApplication.openSettingsURLString){UIApplication.shared.open(url)}}.buttonStyle(.borderedProminent)}
                Button{Task{await capture()}}label:{HStack{Spacer();if busy{ProgressView().tint(.black)}else{Label(success ? "Fortsätt jakten" : "Samla pizzan",systemImage:success ? "arrow.right" : "hand.tap.fill")};Spacer()}.font(.headline).padding(18).foregroundStyle(.black).background(Color(red:0.85,green:0.95,blue:0.45),in:Capsule())}.disabled((!ready && !success)||busy)
            }.padding(24)
        }.task{
            guard ARWorldTrackingConfiguration.isSupported else {error="Den här enheten stöder inte AR. Öppna jakten på en kompatibel iPhone.";return}
            allowed=await AVCaptureDevice.requestAccess(for:.video)
            if !allowed{error="Kameraåtkomst behövs för att visa föremålet i din omgivning."}
        }
    }
    private func capture() async {
        if success {dismiss();return}
        busy=true;defer{busy=false}
        do{try await collect();success=true;error="";UINotificationFeedbackGenerator().notificationOccurred(.success)}catch{self.error=error.localizedDescription}
    }
}
struct PizzaARView:UIViewRepresentable {
    @Binding var ready:Bool
    func makeCoordinator()->Coordinator{Coordinator(self)}
    func makeUIView(context:Context)->ARView {
        let view=ARView(frame:.zero,cameraMode:.ar,automaticallyConfigureSession:false)
        let configuration=ARWorldTrackingConfiguration();configuration.planeDetection=[.horizontal]
        view.session.delegate=context.coordinator;context.coordinator.view=view
        view.session.run(configuration)
        let coaching=ARCoachingOverlayView();coaching.session=view.session;coaching.goal = .horizontalPlane;coaching.autoresizingMask=[.flexibleWidth,.flexibleHeight];coaching.frame=view.bounds;view.addSubview(coaching)
        return view
    }
    func updateUIView(_ view:ARView,context:Context){}
    static func dismantleUIView(_ view:ARView,coordinator:Coordinator){view.session.pause()}
    @MainActor final class Coordinator:NSObject,ARSessionDelegate {
        let parent:PizzaARView
        weak var view:ARView?
        var placed=false
        init(_ parent:PizzaARView){self.parent=parent}
        func session(_ session:ARSession,didAdd anchors:[ARAnchor]){
            guard !placed,let plane=anchors.compactMap({$0 as? ARPlaneAnchor}).first,let view else{return}
            let anchor=AnchorEntity(anchor:plane)
            let pizza=Entity();pizza.position=[0,0.8,0]
            let crust=ModelEntity(mesh:.generateCylinder(height:0.10,radius:0.72),materials:[SimpleMaterial(color:.init(red:0.82,green:0.53,blue:0.20,alpha:1),roughness:0.8,isMetallic:false)])
            pizza.addChild(crust)
            let cheese=ModelEntity(mesh:.generateCylinder(height:0.025,radius:0.65),materials:[SimpleMaterial(color:.init(red:1,green:0.80,blue:0.23,alpha:1),roughness:0.7,isMetallic:false)])
            cheese.position.y=0.062;pizza.addChild(cheese)
            for index in 0..<9 {
                let angle=Float(index)*Float.pi*2/9
                let topping=ModelEntity(mesh:.generateCylinder(height:0.016,radius:0.09),materials:[SimpleMaterial(color:.init(red:0.73,green:0.16,blue:0.08,alpha:1),roughness:0.8,isMetallic:false)])
                topping.position=[cos(angle)*0.43,0.085,sin(angle)*0.43];pizza.addChild(topping)
            }
            let center=ModelEntity(mesh:.generateCylinder(height:0.016,radius:0.10),materials:[SimpleMaterial(color:.red,roughness:0.8,isMetallic:false)]);center.position.y=0.085;pizza.addChild(center)
            pizza.orientation=simd_quatf(angle:Float.pi/7,axis:[1,0,0]);anchor.addChild(pizza);view.scene.addAnchor(anchor)
            placed=true;parent.ready=true
        }
        func session(_ session:ARSession,cameraDidChangeTrackingState camera:ARCamera){
            if case .normal=camera.trackingState{parent.ready=placed}else{parent.ready=false}
        }
        func sessionWasInterrupted(_ session:ARSession){parent.ready=false}
        func session(_ session:ARSession,didFailWithError error:Error){parent.ready=false}
    }
}
