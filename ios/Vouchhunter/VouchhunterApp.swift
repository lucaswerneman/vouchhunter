import HuntCore
import MapKit
import SceneKit
import SwiftUI

@main struct VouchhunterApp: App {
  var body: some Scene {
    WindowGroup {
      #if DEBUG && targetEnvironment(simulator)
        if ProcessInfo.processInfo.arguments.contains("--preview-hunt") {
          NavigationStack { HuntView(campaign: SimulatorHunt.campaign) }.tint(Brand.accent)
        } else {
          RootView().tint(HuntStyle.green).fontDesign(.rounded)
        }
      #else
        RootView().tint(HuntStyle.green).fontDesign(.rounded)
      #endif
    }
  }
}
@MainActor final class Session: ObservableObject {
  @Published var loggedIn = Keychain.read() != nil
  func logout() async {
    struct Result: Decodable { let ok: Bool }
    let _: Result? = try? await API.shared.request("/logout", body: [:])
    Keychain.clear()
    loggedIn = false
  }
}
struct RootView: View {
  @StateObject private var session = Session()
  @State private var linkedCampaign: Campaign?
  @State private var linkError: String?
  var body: some View {
    Group {
      if session.loggedIn {
        TabView {
          ExploreView().tabItem { Label("Upptäck", systemImage: "map") }
          WalletView().tabItem { Label("Vouchers", systemImage: "ticket") }
          NavigationStack {
            List {
              Section("Ditt konto") {
                Button("Logga ut", role: .destructive) { Task { await session.logout() } }
              }
            }.navigationTitle("Profil")
          }.tabItem { Label("Profil", systemImage: "person.crop.circle") }
        }
      } else {
        LoginView(session: session)
      }
    }
    .sheet(item: $linkedCampaign) { c in NavigationStack { HuntView(campaign: c) } }
    .onOpenURL { url in
      guard let id = url.pathComponents.last,
        id.range(of: "^[a-f0-9]{24}$", options: .regularExpression) != nil
      else { return }
      Task {
        do { linkedCampaign = try await API.shared.request("/campaigns/" + id) } catch {
          linkError = error.localizedDescription
        }
      }
    }
    .alert(
      "Kampanjen kunde inte öppnas",
      isPresented: Binding(get: { linkError != nil }, set: { if !$0 { linkError = nil } })
    ) {
      Button("OK") { linkError = nil }
    } message: {
      Text(linkError ?? "")
    }
  }
}
enum Brand {
  static let accent = Color(
    uiColor: UIColor { traits in
      traits.userInterfaceStyle == .dark
        ? UIColor(red: 0.55, green: 0.85, blue: 0.67, alpha: 1)
        : UIColor(red: 0.13, green: 0.38, blue: 0.27, alpha: 1)
    })
}
enum HuntStyle {
  static let green = Color(
    uiColor: UIColor { traits in
      traits.userInterfaceStyle == .dark
        ? UIColor(red: 0.18, green: 0.95, blue: 0.42, alpha: 1)
        : UIColor(red: 0.0, green: 0.47, blue: 0.30, alpha: 1)
    })
  static let electric = Color(red: 0.18, green: 0.95, blue: 0.42)
  static let mint = green.opacity(0.10)
  static let surface = Color(uiColor: .secondarySystemGroupedBackground)
}
struct HuntPillButton: ButtonStyle {
  @Environment(\.isEnabled) private var enabled
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  func makeBody(configuration: Configuration) -> some View {
    configuration.label.font(.system(.subheadline, design: .monospaced, weight: .medium)).textCase(
      .uppercase
    )
    .padding(.horizontal, 20).frame(minHeight: 52).frame(maxWidth: .infinity)
    .foregroundStyle(enabled ? Color.black : Color.secondary)
    .background(
      enabled ? HuntStyle.electric : Color(.tertiarySystemFill), in: Capsule()
    )
    .scaleEffect(configuration.isPressed && !reduceMotion ? 0.97 : 1)
    .animation(
      reduceMotion ? nil : .spring(response: 0.25, dampingFraction: 0.75),
      value: configuration.isPressed)
  }
}
struct LoginView: View {
  @ObservedObject var session: Session
  @State private var register = false
  @State private var name = ""
  @State private var email = ""
  @State private var password = ""
  @State private var error = ""
  @State private var busy = false
  var body: some View {
    NavigationStack {
      Form {
        Section {
          VStack(alignment: .leading, spacing: 14) {
            Image(systemName: "location.circle.fill").font(.largeTitle).foregroundStyle(
              Brand.accent)
            Text("Nästa upptäckt väntar runt hörnet.").font(.title2.bold())
            Text("Hitta kampanjer, samla föremål och få din belöning.").foregroundStyle(.secondary)
          }.padding(.vertical, 12)
        }
        Section(register ? "Skapa konto" : "Logga in") {
          if register { TextField("Ditt namn", text: $name).textContentType(.name) }
          TextField("E-postadress", text: $email).keyboardType(.emailAddress)
            .textInputAutocapitalization(.never).autocorrectionDisabled().textContentType(.username)
          SecureField("Lösenord, minst 10 tecken", text: $password).textContentType(
            register ? .newPassword : .password)
        }
        if !error.isEmpty {
          Section { Label(error, systemImage: "exclamationmark.circle").foregroundStyle(.red) }
        }
        Section {
          Button {
            Task { await submit() }
          } label: {
            HStack {
              Spacer()
              if busy { ProgressView() } else { Text(register ? "Skapa konto" : "Logga in").bold() }
              Spacer()
            }
          }
          .buttonStyle(.borderedProminent).controlSize(.large)
          .disabled(busy || email.isEmpty || password.count < 10 || (register && name.isEmpty))
          Button(register ? "Har du ett konto? Logga in" : "Ny här? Skapa konto") {
            register.toggle()
            error = ""
          }.frame(maxWidth: .infinity)
        }.listRowBackground(Color.clear)
      }.navigationTitle("Vouchhunter")
    }
  }
  private func submit() async {
    busy = true
    defer { busy = false }
    do {
      let response: LoginResponse = try await API.shared.request(
        register ? "/register" : "/login",
        body: ["email": email, "password": password, "name": name, "native": true])
      try Keychain.save(response.token)
      session.loggedIn = true
    } catch { self.error = error.localizedDescription }
  }
}
struct ExploreView: View {
  @StateObject private var location = LocationService()
  @State private var campaigns: [Campaign] = []
  @State private var error: String?
  @State private var loading = true
  var body: some View {
    NavigationStack {
      List {
        Section {
          Map(
            initialPosition: .region(
              MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 59.3326, longitude: 18.0649),
                span: MKCoordinateSpan(latitudeDelta: 0.035, longitudeDelta: 0.035)))
          ) {
            UserAnnotation()
            ForEach(campaigns) { c in
              ForEach(c.stops) { s in
                Annotation(s.name, coordinate: .init(latitude: s.lat, longitude: s.lon)) {
                  NavigationLink {
                    HuntView(campaign: c)
                  } label: {
                    Image(systemName: "gift.fill").font(.title2).padding(12).background(
                      Brand.accent, in: Circle()
                    ).foregroundStyle(.white)
                  }
                }
              }
            }
          }.frame(height: 300).mapControls {
            MapUserLocationButton()
            MapCompass()
          }
        }.listRowInsets(EdgeInsets())
        Section("Kampanjer att upptäcka") {
          if loading { ProgressView("Hämtar kampanjer…") }
          if let error {
            ContentUnavailableView {
              Label("Kunde inte hämta kampanjer", systemImage: "wifi.exclamationmark")
            } description: {
              Text(error)
            } actions: {
              Button("Försök igen") { Task { await load() } }
            }
          }
          if !loading && error == nil && campaigns.isEmpty {
            ContentUnavailableView(
              "Nästa äventyr är på väg", systemImage: "map",
              description: Text("Öppna kampanjer visas här när de publiceras."))
          }
          ForEach(campaigns) { c in
            NavigationLink {
              HuntView(campaign: c)
            } label: {
              VStack(alignment: .leading, spacing: 8) {
                Text(c.brand).font(.subheadline).foregroundStyle(.secondary)
                Text(c.title).font(.headline)
                Label(c.reward, systemImage: "ticket").font(.subheadline)
                Text("\(c.target) objekt · \(c.stops.count) platser").font(.footnote)
                  .foregroundStyle(.secondary)
              }.padding(.vertical, 8)
            }
          }
        }
        if let message = location.message {
          Section { Text(message).font(.footnote).foregroundStyle(.secondary) }
        }
      }.listStyle(.insetGrouped).navigationTitle("Upptäck").refreshable { await load() }.task {
        location.start()
        await load()
      }.onDisappear { location.stop() }
    }
  }
  private func load() async {
    loading = true
    defer { loading = false }
    do {
      let r: CampaignList = try await API.shared.request("/campaigns")
      campaigns = r.campaigns
      error = nil
    } catch { self.error = error.localizedDescription }
  }
}
/// One static 3D scene on the map. The active campaign uses its uploaded USDZ.
struct CollectibleMapObject: UIViewRepresentable {
  let url: URL?
  let pizzaPreview: Bool
  func makeUIView(context: Context) -> SCNView {
    let view = SCNView()
    view.backgroundColor = .clear
    view.autoenablesDefaultLighting = true
    view.isUserInteractionEnabled = false
    view.antialiasingMode = .multisampling4X
    let scene = SCNScene()
    let object = SCNNode()
    if pizzaPreview {
      func disc(
        _ radius: CGFloat, _ height: CGFloat, _ color: UIColor, _ x: Float, _ y: Float, _ z: Float
      ) {
        let geometry = SCNCylinder(radius: radius, height: height)
        geometry.radialSegmentCount = 48
        geometry.firstMaterial?.diffuse.contents = color
        geometry.firstMaterial?.roughness.contents = 0.8
        let node = SCNNode(geometry: geometry)
        node.position = SCNVector3(x, y, z)
        object.addChildNode(node)
      }
      disc(0.68, 0.12, UIColor(red: 0.76, green: 0.39, blue: 0.12, alpha: 1), 0, 0, 0)
      disc(0.59, 0.04, UIColor(red: 1, green: 0.76, blue: 0.25, alpha: 1), 0, 0.08, 0)
      for i in 0..<6 {
        let angle = Float(i) * .pi / 3
        disc(
          0.09, 0.016, UIColor(red: 0.76, green: 0.14, blue: 0.08, alpha: 1), cos(angle) * 0.36,
          0.112, sin(angle) * 0.36)
      }
    } else if let url, let loaded = try? SCNScene(url: url) {
      for node in loaded.rootNode.childNodes { object.addChildNode(node) }
      let (minimum, maximum) = object.boundingBox
      let longest = max(maximum.x - minimum.x, max(maximum.y - minimum.y, maximum.z - minimum.z))
      if longest.isFinite && longest > 0 {
        let scale: Float = 1.4 / longest
        object.scale = SCNVector3(scale, scale, scale)
        object.position = SCNVector3(
          -(minimum.x + maximum.x) * scale / 2, -(minimum.y + maximum.y) * scale / 2,
          -(minimum.z + maximum.z) * scale / 2)
      }
    }
    scene.rootNode.addChildNode(object)
    let camera = SCNNode()
    camera.camera = SCNCamera()
    camera.position = SCNVector3(0, 2.3, 2.7)
    camera.look(at: SCNVector3Zero)
    camera.camera?.usesOrthographicProjection = true
    camera.camera?.orthographicScale = 0.95
    scene.rootNode.addChildNode(camera)
    view.scene = scene
    view.pointOfView = camera
    return view
  }
  func updateUIView(_ view: SCNView, context: Context) {}
}
struct HuntView: View {
  let campaign: Campaign
  private var isPreview: Bool {
    #if DEBUG && targetEnvironment(simulator)
      return ProcessInfo.processInfo.arguments.contains("--preview-hunt")
    #else
      return false
    #endif
  }
  @StateObject private var location = LocationService()
  @State private var hunt: Hunt?
  @State private var selected: Stop?
  @State private var error = ""
  @State private var busy = false
  @State private var captureCount = 0
  @State private var showWallet = false
  @State private var clock = Date()
  @State private var showDetails = false
  @State private var mapPosition: MapCameraPosition = .automatic
  @State private var thumbnailURL: URL?
  @State private var focusedStopID: String?
  private var nextStop: Stop? {
    let available = orderedStops.filter { hunt?.collected.contains($0.id) != true }
    return available.first { $0.id == focusedStopID } ?? available.first
  }
  private var objectName: String { isPreview ? "Pizza" : campaign.model?.name ?? "Föremål" }
  private func focusNext() {
    guard let next = nextStop else { return }
    mapPosition = .camera(
      MapCamera(
        centerCoordinate: .init(latitude: next.lat, longitude: next.lon), distance: 850,
        heading: 20, pitch: 48))
  }
  private var detailContent: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 20) {
        Text(campaign.brand).font(.subheadline).foregroundStyle(.secondary)
        Text(campaign.title).font(.largeTitle.bold())
        Text(campaign.description).foregroundStyle(.secondary)
        Label(
          "Till \(Date(timeIntervalSince1970: campaign.ends).formatted(date: .abbreviated, time: .shortened))",
          systemImage: "calendar"
        )
        .font(.subheadline).foregroundStyle(.secondary)
        VStack(alignment: .leading, spacing: 12) {
          Label(campaign.reward, systemImage: "ticket.fill").font(.title2.bold())
          Text("Samla \(campaign.target) objekt för att få din belöning.")
          if let hunt {
            ProgressView(value: Double(hunt.collected.count), total: Double(campaign.target))
            Text("\(hunt.collected.count) av \(campaign.target) insamlade").font(.subheadline)
          }
        }.padding(22).frame(maxWidth: .infinity, alignment: .leading).background(
          Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18))
        if let hunt, hunt.completed != nil {
          Label("Du är klar! Din voucher finns i plånboken.", systemImage: "checkmark.seal.fill")
            .foregroundStyle(HuntStyle.green)
          Button("Visa min voucher", systemImage: "qrcode") { showWallet = true }
            .buttonStyle(.borderedProminent)
        } else if hunt == nil || (hunt?.expires ?? 0) <= clock.timeIntervalSince1970 {
          Text(
            "En belöning reserveras i upp till 60 minuter, senast till kampanjens slut. Du behöver vara vid platserna för att samla."
          ).font(.footnote).foregroundStyle(.secondary)
          Button("Starta jakten") { Task { await start() } }.buttonStyle(.borderedProminent)
            .disabled(
              busy || campaign.ends <= clock.timeIntervalSince1970
                || campaign.starts > clock.timeIntervalSince1970)
        } else if let hunt {
          Text(
            "Reserverad till \(Date(timeIntervalSince1970:hunt.expires).formatted(date:.omitted,time:.shortened))"
          ).font(.footnote)
        }
        Map {
          UserAnnotation()
          ForEach(campaign.stops) { s in
            Marker(s.name, coordinate: .init(latitude: s.lat, longitude: s.lon)).tint(
              hunt?.collected.contains(s.id) == true ? .gray : .green)
          }
        }.frame(height: 240).clipShape(RoundedRectangle(cornerRadius: 16))
        Text("Platser att upptäcka").font(.title2.bold())
        ForEach(orderedStops) { s in
          HStack {
            VStack(alignment: .leading) {
              Text(s.name).font(.headline)
              if let loc = location.location {
                Text("\(Int(loc.distance(from:CLLocation(latitude:s.lat,longitude:s.lon)))) m bort")
                  .foregroundStyle(.secondary).font(.footnote)
              }
              Text(collectionHint(s)).font(.caption).foregroundStyle(.secondary)
              Button("Visa gångväg", systemImage: "figure.walk") { directions(s) }
                .font(.subheadline)
            }
            Spacer()
            if hunt?.collected.contains(s.id) == true {
              Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
            } else {
              Button("Öppna AR") {
                captureCount = hunt?.collected.count ?? 0
                selected = s
              }.buttonStyle(.bordered).disabled(!canCollect(s))
            }
          }.padding(.vertical, 10)
        }
        if !error.isEmpty { Text(error).foregroundStyle(.red) }
        if let message = location.message { Text(message).foregroundStyle(.secondary) }
        Text("Villkor").font(.headline)
        Text(campaign.terms).font(.subheadline)
        Text(
          "Lös in hos \(campaign.venue). Vouchern gäller i \(campaign.voucher_days) dagar efter slutförd jakt."
        ).font(.footnote).foregroundStyle(.secondary)
      }.padding(22)
    }
    .background(Color(.systemGroupedBackground))
  }
  var body: some View {
    ZStack(alignment: .top) {
      Map(position: $mapPosition) {
        UserAnnotation()
        ForEach(campaign.stops.filter { hunt?.collected.contains($0.id) != true }) { stop in
          Annotation(stop.name, coordinate: .init(latitude: stop.lat, longitude: stop.lon)) {
            if stop.id == nextStop?.id {
              Button {
                if canCollect(stop) {
                  captureCount = hunt?.collected.count ?? 0
                  selected = stop
                } else {
                  showDetails = true
                }
              } label: {
                VStack(spacing: 0) {
                  if isPreview || thumbnailURL != nil {
                    CollectibleMapObject(url: thumbnailURL, pizzaPreview: isPreview).frame(
                      width: 112, height: 108
                    ).allowsHitTesting(false)
                  } else {
                    Image(systemName: "cube.fill").font(.system(size: 42)).foregroundStyle(
                      HuntStyle.green
                    )
                    .padding(20).background(HuntStyle.surface, in: Circle())
                  }
                  Text(objectName).font(.system(.subheadline, design: .monospaced, weight: .bold))
                    .foregroundStyle(.primary).padding(.horizontal, 14).padding(.vertical, 7)
                    .background(HuntStyle.surface, in: Capsule())
                }
              }.accessibilityLabel("\(objectName), \(stop.name), \(collectionHint(stop))")
            } else {
              Button {
                focusedStopID = stop.id
                focusNext()
              } label: {
                Circle().fill(HuntStyle.green.opacity(0.5)).frame(width: 12, height: 12)
                  .overlay(Circle().stroke(.white, lineWidth: 2)).frame(width: 44, height: 44)
              }.accessibilityLabel("Visa fynd vid \(stop.name)")
            }
          }.annotationTitles(.hidden)
        }
      }.mapStyle(
        .standard(elevation: .realistic, emphasis: .muted, pointsOfInterest: .excludingAll)
      )
      .mapControls {}.ignoresSafeArea(edges: .bottom)
      HStack {
        Button {
          showDetails = true
        } label: {
          HStack(spacing: 10) {
            Text("\(hunt?.collected.count ?? 0) / \(campaign.target)").font(
              .system(.headline, design: .monospaced, weight: .bold))
            Text("FYND").font(.subheadline).foregroundStyle(.secondary)
          }.padding(.horizontal, 18).frame(height: 48)
            .background(HuntStyle.surface, in: Capsule())
        }.buttonStyle(.plain).accessibilityLabel(
          "Din samling, \(hunt?.collected.count ?? 0) av \(campaign.target). Visa kampanjdetaljer")
        Spacer()
        Button {
          focusNext()
        } label: {
          Image(systemName: "scope").font(.title3).frame(width: 48, height: 48)
            .background(HuntStyle.surface, in: Circle())
        }.accessibilityLabel("Centrera nästa fynd")
      }.foregroundStyle(.white).environment(\.colorScheme, .dark)
        .padding(.horizontal, 20).padding(.top, 8)
    }
    .safeAreaInset(edge: .bottom) {
      VStack(alignment: .leading, spacing: 12) {
        if hunt?.completed != nil {
          Label("Jakten är klar!", systemImage: "checkmark.seal.fill").font(.title2.bold())
          Text(campaign.reward).font(.headline)
          Button("Hämta din belöning", systemImage: "ticket.fill") { showWallet = true }
            .buttonStyle(HuntPillButton())
        } else if hunt == nil || (hunt?.expires ?? 0) <= clock.timeIntervalSince1970 {
          Text(hunt == nil ? "Ditt nästa äventyr" : "Redo för en ny runda?").font(.title2.bold())
          Text(
            "Hitta \(campaign.target) föremål ute i staden. Samla dem i AR och lås upp \(campaign.reward.lowercased())."
          )
          .font(.subheadline)
          Button {
            Task { await start() }
          } label: {
            HStack {
              if busy { ProgressView() }
              Text("Starta jakten")
              Image(systemName: "arrow.right")
            }
            .frame(maxWidth: .infinity)
          }.buttonStyle(HuntPillButton())
            .disabled(
              busy || campaign.ends <= clock.timeIntervalSince1970
                || campaign.starts > clock.timeIntervalSince1970)
          Text(
            "Belöningen reserveras i upp till 60 minuter. Håll koll på trafiken och din omgivning."
          )
          .font(.caption).foregroundStyle(.secondary)
        } else if let next = nextStop {
          HStack {
            Label("NÄSTA FYND", systemImage: "location").font(.subheadline.weight(.semibold))
              .foregroundStyle(HuntStyle.green)
            Spacer()
            Button("KARTA", systemImage: "list.bullet") { showDetails = true }
              .font(.caption.weight(.semibold)).foregroundStyle(.secondary)
          }
          HStack {
            Text(next.name.uppercased()).font(
              .system(.title2, design: .monospaced, weight: .medium)
            )
            .minimumScaleFactor(0.8)
            Spacer()
            if let loc = location.location {
              Text(
                "\(Int(loc.distance(from: CLLocation(latitude: next.lat, longitude: next.lon)))) m"
              )
              .font(.system(.title2, design: .monospaced, weight: .bold)).monospacedDigit()
            }
          }
          Text(isPreview ? "\(objectName) · exempel på nästa fynd" : collectionHint(next)).font(
            .subheadline
          ).foregroundStyle(.secondary)
          if canCollect(next) {
            Button("Samla i AR", systemImage: "viewfinder") {
              captureCount = hunt?.collected.count ?? 0
              selected = next
            }.buttonStyle(HuntPillButton())
          } else {
            Button(
              isPreview ? "Utforska jakten" : "Visa vägen",
              systemImage: isPreview ? "map.fill" : "figure.walk"
            ) {
              if isPreview { showDetails = true } else { directions(next) }
            }.buttonStyle(HuntPillButton())
          }
          Label(
            "\(max(0, campaign.target - (hunt?.collected.count ?? 0))) fynd kvar · \(campaign.reward)",
            systemImage: "ticket"
          )
          .font(.caption.weight(.medium)).foregroundStyle(.secondary)
        }
        if !error.isEmpty { Text(error).font(.footnote).foregroundStyle(.red) }
        if let message = location.message {
          Text(message).font(.caption).foregroundStyle(.secondary)
        }
      }.padding(24).frame(maxWidth: .infinity, alignment: .leading)
        .background(HuntStyle.surface, in: RoundedRectangle(cornerRadius: 32, style: .continuous))
        .overlay(
          RoundedRectangle(cornerRadius: 32).stroke(Color.primary.opacity(0.035), lineWidth: 1)
        )
        .foregroundStyle(.white).environment(\.colorScheme, .dark)
        .padding(.horizontal, 12).padding(.bottom, 8)
    }
    .fontDesign(.monospaced)
    .preferredColorScheme(.dark)
    .tint(HuntStyle.green)
    .navigationTitle(isPreview ? "Förhandsvisning" : "Jakten").navigationBarTitleDisplayMode(
      .inline
    )
    .sheet(isPresented: $showDetails) {
      NavigationStack {
        detailContent.navigationTitle("Om jakten").navigationBarTitleDisplayMode(.inline)
          .toolbar {
            ToolbarItem(placement: .confirmationAction) { Button("Klart") { showDetails = false } }
          }
      }.presentationDetents([.medium, .large]).presentationDragIndicator(.visible)
    }
    .task {
      if isPreview {
        #if DEBUG && targetEnvironment(simulator)
          hunt = SimulatorHunt.hunt
          focusNext()
        #endif
        return
      }
      location.start()
      do {
        let r: HuntEnvelope = try await API.shared.request("/hunts/" + campaign.id)
        hunt = r.hunt
        focusNext()
      } catch { self.error = error.localizedDescription }
    }
    .task {
      guard !isPreview, let model = campaign.model else { return }
      thumbnailURL = try? await API.shared.modelFile(assetID: model.usdz_asset_id)
    }
    .onChange(of: hunt?.collected.count) { _, _ in focusNext() }
    .task {
      while !Task.isCancelled {
        clock = Date()
        do { try await Task.sleep(for: .seconds(5)) } catch { return }
      }
    }
    .sheet(isPresented: $showWallet) {
      WalletView().overlay(alignment: .topTrailing) {
        Button("Stäng") { showWallet = false }.padding()
      }
    }
    .onDisappear { if selected == nil { location.stop() } }
    .fullScreenCover(
      item: $selected,
      onDismiss: {
        location.start()
        if hunt?.completed != nil { showWallet = true }
      }
    ) { s in
      CaptureView(
        stop: s, model: campaign.model, collectedCount: captureCount, target: campaign.target
      ) { try await collect(s) }
    }
  }
  private var orderedStops: [Stop] {
    campaign.stops.sorted { a, b in
      let aCollected = hunt?.collected.contains(a.id) == true
      let bCollected = hunt?.collected.contains(b.id) == true
      if aCollected != bCollected { return !aCollected }
      guard let loc = location.location else {
        return (campaign.stops.firstIndex(where: { $0.id == a.id }) ?? 0)
          < (campaign.stops.firstIndex(where: { $0.id == b.id }) ?? 0)
      }
      return loc.distance(from: CLLocation(latitude: a.lat, longitude: a.lon))
        < loc.distance(from: CLLocation(latitude: b.lat, longitude: b.lon))
    }
  }
  private func collectionHint(_ stop: Stop) -> String {
    if isPreview && hunt?.collected.contains(stop.id) != true {
      return "Förhandsvisning · kamera-AR provas på iPhone"
    }
    if hunt?.collected.contains(stop.id) == true { return "Redan i din samling" }
    if hunt?.completed != nil { return "Jakten är slutförd" }
    guard let hunt else { return "Starta jakten för att samla" }
    if hunt.expires <= clock.timeIntervalSince1970 { return "Reservationen har gått ut" }
    guard let loc = location.location, loc.horizontalAccuracy >= 0, loc.horizontalAccuracy <= 35,
      abs(loc.timestamp.timeIntervalSinceNow) < 45
    else { return "Väntar på en noggrann GPS-position" }
    return canCollect(stop)
      ? "Du är framme – öppna kameran" : "Gå inom \(stop.radius) meter för att samla"
  }
  private func directions(_ stop: Stop) {
    guard !isPreview else { return }
    let destination = MKMapItem(
      placemark: MKPlacemark(coordinate: .init(latitude: stop.lat, longitude: stop.lon)))
    destination.name = stop.name
    destination.openInMaps(launchOptions: [
      MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeWalking
    ])
  }
  private func canCollect(_ stop: Stop) -> Bool {
    guard !isPreview else { return false }
    guard let hunt, hunt.completed == nil, hunt.expires > Date().timeIntervalSince1970,
      let loc = location.location, loc.horizontalAccuracy >= 0, loc.horizontalAccuracy <= 35,
      abs(loc.timestamp.timeIntervalSinceNow) < 45
    else { return false }
    return loc.distance(from: CLLocation(latitude: stop.lat, longitude: stop.lon))
      <= Double(stop.radius)
  }
  private func start() async {
    if isPreview {
      #if DEBUG && targetEnvironment(simulator)
        hunt = SimulatorHunt.hunt
      #endif
      return
    }
    busy = true
    defer { busy = false }
    do {
      hunt = try await API.shared.request("/hunts/" + campaign.id + "/start", body: [:])
      error = ""
    } catch { self.error = error.localizedDescription }
  }
  private func collect(_ stop: Stop) async throws {
    guard !isPreview else { return }
    location.start()
    var payload = try location.payload()
    payload["stop_id"] = stop.id
    hunt = try await API.shared.request("/hunts/" + campaign.id + "/collect", body: payload)
  }
}

#if DEBUG && targetEnvironment(simulator)
  /// Offline visual fixture. Never published, paid, or granted backend privileges.
  private enum SimulatorHunt {
    static let campaign: Campaign = {
      let coordinates: [(String, Double, Double)] = [
        ("Sergels torg", 59.3326, 18.0649), ("Kulturhuset", 59.3321, 18.0645),
        ("Brunkebergstorg", 59.3309, 18.0663), ("Kungsträdgården", 59.3312, 18.0717),
        ("Hötorget", 59.3354, 18.0631), ("Berzelii park", 59.3326, 18.0740),
        ("Norrmalmstorg", 59.3330, 18.0730), ("Gustav Adolfs torg", 59.3294, 18.0700),
        ("Norra Bantorget", 59.3350, 18.0570), ("Strömparterren", 59.3280, 18.0707),
      ]
      let payload: [String: Any] = [
        "id": "simulator-preview", "title": "Den stora pizzajakten",
        "brand": "Vouchhunter · Exempelkampanj",
        "description":
          "Tio pizzor har dykt upp i city. Upptäck platserna, samla dina fynd och nå hela vägen till belöningen.",
        "reward": "En nybakad pizza",
        "terms": "Lokal designförhandsvisning. Ingen riktig kampanj eller giltig voucher.",
        "venue": "Exempelpizzerian", "target": 10, "capacity": 100, "voucher_days": 14,
        "starts": Date().timeIntervalSince1970 - 60, "ends": Date().timeIntervalSince1970 + 86400,
        "stops": coordinates.enumerated().map { i, item in
          [
            "id": "preview-\(i)", "campaign_id": "simulator-preview", "name": item.0, "lat": item.1,
            "lon": item.2, "radius": 40,
          ] as [String: Any]
        },
      ]
      return try! JSONDecoder().decode(
        Campaign.self, from: JSONSerialization.data(withJSONObject: payload))
    }()
    static var hunt: Hunt {
      let payload: [String: Any] = [
        "id": "preview-hunt", "expires": Date().timeIntervalSince1970 + 3000,
        "collected": ["preview-1", "preview-2", "preview-4"],
      ]
      return try! JSONDecoder().decode(
        Hunt.self, from: JSONSerialization.data(withJSONObject: payload))
    }
  }
#endif
