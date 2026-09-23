import SwiftUI
import RealityKit
import ARKit
import AVFoundation
import HuntCore

struct CaptureView:View {
    let stop:Stop
    let model:CampaignModel?
    let collect:() async throws -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var allowed=false
    @State private var ready=false
    @State private var busy=false
    @State private var success=false
    @State private var error=""
    @State private var modelURL:URL?
    var body:some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if allowed,let modelURL {PizzaARView(ready:$ready,fileURL:modelURL,onFailure:{error=$0}).ignoresSafeArea()}
            VStack(spacing:18){
                HStack{Button{dismiss()}label:{Image(systemName:"xmark").padding(14).background(.ultraThinMaterial,in:Circle())}.accessibilityLabel("Stäng kameran");Spacer();Text(stop.name).font(.headline).padding(12).background(.ultraThinMaterial,in:Capsule())}
                Spacer()
                if success {Label("Insamlad!",systemImage:"checkmark.circle.fill").font(.largeTitle.bold()).foregroundStyle(.white)}
                else {Text(ready ? "Där är ditt fynd." : "Rikta kameran mot en öppen yta.").font(.title2.bold()).foregroundStyle(.white);Text(ready ? "Tryck för att lägga det till din samling." : "Rör telefonen långsamt så hittar vi marken.").foregroundStyle(.white)}
                if !error.isEmpty{Text(error).foregroundStyle(.white).padding().background(.red.opacity(0.8),in:RoundedRectangle(cornerRadius:12))}
                if !allowed && !error.isEmpty {Button("Öppna inställningar"){if let url=URL(string:UIApplication.openSettingsURLString){UIApplication.shared.open(url)}}.buttonStyle(.borderedProminent)}
                Button{Task{await capture()}}label:{HStack{Spacer();if busy{ProgressView().tint(.black)}else{Label(success ? "Fortsätt jakten" : "Samla föremålet",systemImage:success ? "arrow.right" : "hand.tap.fill")};Spacer()}.font(.headline).padding(18).foregroundStyle(.black).background(Color(red:0.85,green:0.95,blue:0.45),in:Capsule())}.disabled((!ready && !success)||busy)
            }.padding(24)
        }.task{
            guard ARWorldTrackingConfiguration.isSupported else {error="Den här enheten stöder inte AR. Öppna jakten på en kompatibel iPhone.";return}
            allowed=await AVCaptureDevice.requestAccess(for:.video)
            if !allowed{error="Kameraåtkomst behövs för att visa föremålet i din omgivning."}
            guard allowed else{return}
            guard let model else{error="Kampanjen saknar ett 3D-objekt. Försök igen senare.";return}
            do{modelURL=try await API.shared.modelFile(assetID:model.usdz_asset_id)}catch{self.error=error.localizedDescription}
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
    let fileURL:URL
    let onFailure:(String)->Void
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
    @MainActor final class Coordinator:NSObject,@preconcurrency ARSessionDelegate {
        let parent:PizzaARView
        weak var view:ARView?
        var placed=false
        init(_ parent:PizzaARView){self.parent=parent}
        func session(_ session:ARSession,didAdd anchors:[ARAnchor]){
            guard !placed,let plane=anchors.compactMap({$0 as? ARPlaneAnchor}).first,let view else{return}
            let anchor=AnchorEntity(world:plane.transform)
            do {
                let object=try Entity.load(contentsOf:parent.fileURL)
                let bounds=object.visualBounds(relativeTo:nil)
                let longest=max(bounds.extents.x,max(bounds.extents.y,bounds.extents.z))
                guard longest.isFinite,longest>0.001 else{parent.onFailure("3D-objektet saknar giltig geometri.");return}
                object.scale *= 1.5 / longest
                object.position=[0,0.7,0]
                anchor.addChild(object);view.scene.addAnchor(anchor)
            }catch{parent.onFailure("3D-objektet kunde inte visas. Försök igen senare.");return}
            placed=true;parent.ready=true
        }
        func session(_ session:ARSession,cameraDidChangeTrackingState camera:ARCamera){
            if case .normal=camera.trackingState{parent.ready=placed}else{parent.ready=false}
        }
        func sessionWasInterrupted(_ session:ARSession){parent.ready=false}
        func session(_ session:ARSession,didFailWithError error:Error){parent.ready=false}
    }
}
