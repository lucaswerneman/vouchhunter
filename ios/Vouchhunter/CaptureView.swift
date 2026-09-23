import ARKit
import AVFoundation
import HuntCore
import RealityKit
import SwiftUI

struct CaptureView: View {
  let stop: Stop
  let model: CampaignModel?
  var localModelURL: URL? = nil
  let collectedCount: Int
  let target: Int
  let collect: () async throws -> Void
  @Environment(\.dismiss) private var dismiss
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var allowed = false
  @State private var ready = false
  @State private var busy = false
  @State private var success = false
  @State private var error = ""
  @State private var modelURL: URL?
  @State private var trackingHint = "Rör telefonen långsamt så hittar vi marken."
  @State private var sessionID = UUID()
  var body: some View {
    ZStack {
      Color.black.ignoresSafeArea()
      if allowed, let modelURL {
        CollectibleARView(
          ready: $ready, fileURL: modelURL, captured: success, reduceMotion: reduceMotion,
          onTap: { Task { await capture() } },
          onHint: { trackingHint = $0 }, onFailure: { error = $0 }
        )
        .id(sessionID).ignoresSafeArea()
      }
      VStack(spacing: 18) {
        HStack {
          Button {
            dismiss()
          } label: {
            Image(systemName: "xmark").padding(14).background(
              Color.black.opacity(0.65), in: Circle()
            )
            .overlay(Circle().stroke(HuntStyle.line, lineWidth: 0.5))
          }.accessibilityLabel("Stäng kameran")
          Spacer()
          Text(stop.name).font(.headline).padding(12).background(
            Color.black.opacity(0.65), in: RoundedRectangle(cornerRadius: 16)
          ).overlay(RoundedRectangle(cornerRadius: 8).stroke(HuntStyle.line, lineWidth: 0.5))
        }
        Text("\(min(target, collectedCount + (success ? 1 : 0))) av \(target) insamlade")
          .font(.subheadline.bold()).padding(12).background(
            Color.black.opacity(0.65), in: RoundedRectangle(cornerRadius: 16)
          ).overlay(RoundedRectangle(cornerRadius: 8).stroke(HuntStyle.line, lineWidth: 0.5))
        Spacer()
        if allowed && modelURL == nil && error.isEmpty {
          ProgressView("Laddar ditt 3D-objekt…").tint(.white).foregroundStyle(.white)
        }
        if success {
          Label(
            collectedCount + 1 >= target ? "Belöningen är din!" : "Insamlad!",
            systemImage: "checkmark.circle.fill"
          ).font(.system(.largeTitle, design: .default))
            .foregroundStyle(.white)
        } else {
          Text(ready ? "Där är ditt fynd." : "Rikta kameran mot en öppen yta.").font(
            .system(.title2, design: .default)
          )
          .foregroundStyle(.white)
          Text(
            ready
              ? "Tryck på 3D-objektet eller knappen för att samla."
              : trackingHint
          ).foregroundStyle(.white)
        }
        if !error.isEmpty {
          Text(error).foregroundStyle(.white).padding().background(
            .red.opacity(0.8), in: RoundedRectangle(cornerRadius: 12))
        }
        if allowed && !error.isEmpty && !success {
          Button("Försök igen") {
            error = ""
            ready = false
            if modelURL != nil { sessionID = UUID() } else { Task { await loadModel() } }
          }.buttonStyle(HuntSecondaryButton())
        }
        if !allowed && !error.isEmpty && ARWorldTrackingConfiguration.isSupported {
          Button("Öppna inställningar") {
            if let url = URL(string: UIApplication.openSettingsURLString) {
              UIApplication.shared.open(url)
            }
          }.buttonStyle(HuntSecondaryButton())
        }
        Button {
          Task { await capture() }
        } label: {
          HStack {
            Spacer()
            if busy {
              ProgressView().tint(.white)
            } else {
              Label(
                success
                  ? (collectedCount + 1 >= target ? "Visa belöningen" : "Fortsätt jakten")
                  : "Samla föremålet",
                systemImage: success ? "arrow.right" : "hand.tap.fill")
            }
            Spacer()
          }
        }.buttonStyle(HuntPillButton()).disabled((!ready && !success) || busy)
      }.padding(24).fontDesign(.default).foregroundStyle(.white)
    }.task {
      guard ARWorldTrackingConfiguration.isSupported else {
        error = "Den här enheten stöder inte AR. Öppna jakten på en kompatibel iPhone."
        return
      }
      allowed = await AVCaptureDevice.requestAccess(for: .video)
      if !allowed { error = "Kameraåtkomst behövs för att visa föremålet i din omgivning." }
      guard allowed else { return }
      await loadModel()
    }
  }
  private func loadModel() async {
    if let localModelURL {
      modelURL = localModelURL
      return
    }
    guard let model else {
      error = "Kampanjen saknar ett 3D-objekt. Försök igen senare."
      return
    }
    do { modelURL = try await API.shared.modelFile(assetID: model.usdz_asset_id) } catch {
      self.error = error.localizedDescription
    }
  }
  private func capture() async {
    if success {
      dismiss()
      return
    }
    guard ready, !busy else { return }
    busy = true
    defer { busy = false }
    do {
      try await collect()
      withAnimation(reduceMotion ? nil : .spring(response: 0.4)) { success = true }
      error = ""
      UINotificationFeedbackGenerator().notificationOccurred(.success)
    } catch { self.error = error.localizedDescription }
  }
}
struct CollectibleARView: UIViewRepresentable {
  @Binding var ready: Bool
  let fileURL: URL
  let captured: Bool
  let reduceMotion: Bool
  let onTap: () -> Void
  let onHint: (String) -> Void
  let onFailure: (String) -> Void
  func makeCoordinator() -> Coordinator { Coordinator(self) }
  func makeUIView(context: Context) -> ARView {
    let view = ARView(frame: .zero, cameraMode: .ar, automaticallyConfigureSession: false)
    let configuration = ARWorldTrackingConfiguration()
    configuration.planeDetection = [.horizontal]
    view.session.delegate = context.coordinator
    context.coordinator.view = view
    view.addGestureRecognizer(
      UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.tapped(_:)))
    )
    view.session.run(configuration)
    let coaching = ARCoachingOverlayView()
    coaching.session = view.session
    coaching.goal = .horizontalPlane
    coaching.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    coaching.frame = view.bounds
    view.addSubview(coaching)
    return view
  }
  func updateUIView(_ view: ARView, context: Context) {
    context.coordinator.parent = self
    if captured { context.coordinator.animateCollection() }
  }
  static func dismantleUIView(_ view: ARView, coordinator: Coordinator) {
    coordinator.displayLink?.invalidate()
    view.session.pause()
  }
  @MainActor final class Coordinator: NSObject, @preconcurrency ARSessionDelegate {
    var parent: CollectibleARView
    weak var view: ARView?
    var placed = false
    var object: Entity?
    var animated = false
    var halo: Entity?
    var displayLink: CADisplayLink?
    private var motionTime: Double = 0
    @objc func advance(_ link: CADisplayLink) {
      guard !animated, let object else { return }
      guard !parent.reduceMotion else {
        object.position.y = 0.7
        object.orientation = simd_quatf(angle: 0, axis: [0, 1, 0])
        halo?.scale = .one
        return
      }
      motionTime += min(link.targetTimestamp - link.timestamp, 0.05)
      let t = Float(motionTime)
      object.position.y = 0.7 + sin(t * 1.8) * 0.055
      object.orientation = simd_quatf(angle: t * 0.18, axis: [0, 1, 0])
      halo?.scale = SIMD3(repeating: 1 + 0.07 * sin(t * 2.5))
    }
    @objc func tapped(_ gesture: UITapGestureRecognizer) {
      guard parent.ready, !parent.captured, let view,
        var hit = view.entity(at: gesture.location(in: view)), let object
      else { return }
      while hit !== object {
        guard let ancestor = hit.parent else { return }
        hit = ancestor
      }
      parent.onTap()
    }
    func animateCollection() {
      guard !animated, let object else { return }
      animated = true
      displayLink?.invalidate()
      halo?.isEnabled = false
      if parent.reduceMotion {
        object.isEnabled = false
        return
      }
      var destination = object.transform
      destination.scale *= 0.01
      destination.translation.y += 0.5
      object.move(
        to: destination, relativeTo: object.parent, duration: 0.45, timingFunction: .easeInOut)
    }
    init(_ parent: CollectibleARView) { self.parent = parent }
    func session(_ session: ARSession, didAdd anchors: [ARAnchor]) { placeInView() }
    func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) { placeInView() }
    private func placeInView() {
      guard !placed, let view,
        let hit = view.raycast(
          from: CGPoint(x: view.bounds.midX, y: view.bounds.midY),
          allowing: .existingPlaneGeometry, alignment: .horizontal
        ).first
      else { return }
      let anchor = AnchorEntity(world: hit.worldTransform)
      do {
        let model = try Entity.load(contentsOf: parent.fileURL)
        let object = Entity()
        object.addChild(model)
        let bounds = model.visualBounds(relativeTo: object)
        let longest = max(bounds.extents.x, max(bounds.extents.y, bounds.extents.z))
        guard longest.isFinite, longest > 0.001 else {
          parent.onFailure("3D-objektet saknar giltig geometri.")
          return
        }
        let scale = 1.5 / longest
        model.scale *= scale
        model.position -= bounds.center * scale
        object.position = [0, 0.7, 0]
        object.generateCollisionShapes(recursive: true)
        self.object = object
        anchor.addChild(object)
        // A quiet dotted halo marks the collectible without obscuring the real ground.
        let halo = Entity()
        let material = UnlitMaterial(color: UIColor.white.withAlphaComponent(0.85))
        for index in 0..<48 {
          let angle = Float(index) * 2 * .pi / 48
          let dot = ModelEntity(mesh: .generateSphere(radius: 0.012), materials: [material])
          dot.position = [cos(angle) * 0.88, 0.035, sin(angle) * 0.88]
          halo.addChild(dot)
        }
        self.halo = halo
        anchor.addChild(halo)
        view.scene.addAnchor(anchor)
        let link = CADisplayLink(target: self, selector: #selector(advance(_:)))
        link.add(to: .main, forMode: .common)
        displayLink = link
      } catch {
        parent.onFailure("3D-objektet kunde inte visas. Försök igen senare.")
        return
      }
      placed = true
      parent.ready = true
    }
    func session(_ session: ARSession, cameraDidChangeTrackingState camera: ARCamera) {
      if case .normal = camera.trackingState { parent.ready = placed } else { parent.ready = false }
    }
    func sessionWasInterrupted(_ session: ARSession) {
      parent.ready = false
      parent.onHint("Kameran pausades. Rikta den mot samma yta igen.")
    }
    func sessionInterruptionEnded(_ session: ARSession) {
      parent.onHint("Hitta samma yta igen genom att röra telefonen långsamt.")
    }
    func session(_ session: ARSession, didFailWithError error: Error) {
      parent.ready = false
      parent.onFailure("AR-spårningen avbröts. Tryck på Försök igen.")
    }
  }
}
