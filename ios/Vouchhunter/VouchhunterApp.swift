import HuntCore
import MapKit
import SceneKit
import SwiftUI

@main struct VouchhunterApp: App {
  @AppStorage("vouchhunter.didSeeIntroduction.v1") private var didSeeIntroduction = false
  var body: some Scene {
    WindowGroup {
      Group {
        #if DEBUG || FIELD_TESTING
          if LocalExperience.active {
            SimulatorExperience().vouchhunterTheme()
          } else {
            RootView().vouchhunterTheme()
          }
        #else
          RootView().vouchhunterTheme()
        #endif
      }
      .fullScreenCover(
        isPresented: Binding(
          get: { !didSeeIntroduction }, set: { if !$0 { didSeeIntroduction = true } })
      ) {
        IntroductionView { didSeeIntroduction = true }.vouchhunterTheme()
          .interactiveDismissDisabled()
      }
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
    TabView {
      ExploreView().tabItem { Label("Upptäck", systemImage: "map") }
      Group {
        if session.loggedIn { WalletView() } else { LoginView(session: session) }
      }.tabItem { Label("Kuponger", systemImage: "ticket") }
      AccountView(session: session).tabItem { Label("Konto", systemImage: "person.crop.circle") }
    }
    .environmentObject(session)
    .sheet(item: $linkedCampaign) { c in
      NavigationStack { CampaignOverviewView(campaign: c) }.environmentObject(session)
        .vouchhunterTheme()
    }
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
// WhatsApp iOS reference: neutral system type, grouped surfaces, inset separators.
enum Brand { static let accent = HuntStyle.accent }
enum HuntStyle {
  static let accent = Color(white: 0.16)
  static let electric = accent
  static let green = accent
  static let canvas = Color(white: 0.96)
  static let surface = Color.white
  static let line = Color(white: 0.86)
  static let mint = Color(white: 0.92)
}
extension View {
  func vouchhunterTheme() -> some View {
    self.preferredColorScheme(.light).tint(HuntStyle.accent)
      .font(.body).fontDesign(.default).background(HuntStyle.canvas)
  }
  func huntPanel() -> some View {
    self.padding(16).frame(maxWidth: .infinity, alignment: .leading)
      .background(HuntStyle.surface, in: RoundedRectangle(cornerRadius: 24))
  }
}
struct HuntRule: View {
  var body: some View { Divider().accessibilityHidden(true) }
}
struct HuntSecondaryButton: ButtonStyle {
  @Environment(\.isEnabled) private var enabled
  func makeBody(configuration: Configuration) -> some View {
    configuration.label.font(.body.weight(.medium)).padding(.horizontal, 16).frame(minHeight: 44)
      .foregroundStyle(enabled ? HuntStyle.accent : Color.secondary)
      .background(configuration.isPressed ? HuntStyle.mint : HuntStyle.surface, in: Capsule())
  }
}
struct HuntPillButton: ButtonStyle {
  var fill = HuntStyle.accent
  var ink = Color.white
  @Environment(\.isEnabled) private var enabled
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  func makeBody(configuration: Configuration) -> some View {
    configuration.label.font(.body.weight(.semibold))
      .padding(.horizontal, 20).frame(minHeight: 50).frame(maxWidth: .infinity)
      .foregroundStyle(enabled ? ink : Color.secondary)
      .background(enabled ? fill : HuntStyle.mint, in: Capsule())
      .opacity(configuration.isPressed ? 0.8 : 1)
      .animation(reduceMotion ? nil : .easeOut(duration: 0.15), value: configuration.isPressed)
  }
}
extension Color {
  init(brandHex: String?, fallback: UInt32 = 0x242424) {
    let cleaned = brandHex?.replacingOccurrences(of: "#", with: "") ?? ""
    let value = cleaned.count == 6 ? UInt32(cleaned, radix: 16) ?? fallback : fallback
    self.init(
      red: Double((value >> 16) & 255) / 255, green: Double((value >> 8) & 255) / 255,
      blue: Double(value & 255) / 255)
  }
  static func brandText(on hex: String?) -> Color {
    let value =
      UInt32((hex ?? "#242424").replacingOccurrences(of: "#", with: ""), radix: 16) ?? 0x242424
    let channels = [16, 8, 0].map { shift -> Double in
      let c = Double((value >> shift) & 255) / 255
      return c <= 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
    }
    let luminance = channels[0] * 0.2126 + channels[1] * 0.7152 + channels[2] * 0.0722
    return (luminance + 0.05) / 0.05 >= 1.05 / (luminance + 0.05) ? .black : .white
  }
}
extension Campaign {
  var accent: Color { Color(brandHex: branding?.accent_color) }
  var accentText: Color { .white }
  var buttonAccent: Color {
    // Keep the campaign hue while ensuring white button labels have 4.5:1 contrast.
    let value =
      UInt32(
        (branding?.accent_color ?? "242424").replacingOccurrences(of: "#", with: ""), radix: 16)
      ?? 0x242424
    var channels = [16, 8, 0].map { Double((value >> $0) & 255) / 255 }
    func luminance(_ values: [Double]) -> Double {
      let linear = values.map { $0 <= 0.04045 ? $0 / 12.92 : pow(($0 + 0.055) / 1.055, 2.4) }
      return linear[0] * 0.2126 + linear[1] * 0.7152 + linear[2] * 0.0722
    }
    while luminance(channels) > 0.1833 { channels = channels.map { $0 * 0.97 } }
    return Color(red: channels[0], green: channels[1], blue: channels[2])
  }
  var collectionPitch: String {
    if LocalExperience.active {
      return target == 1
        ? "Hitta pizzan på Odenplan och samla den i AR för att få en testkupong på den nya pizzan."
        : "Samla \(target) pizzor på stan – så bjuder vi på din första pizza."
    }
    return "Samla \(target) föremål och lås upp din kupong: \(reward)."
  }
  var brandSurface: Color { Color(brandHex: branding?.background_color, fallback: 0xF2F2F2) }
}
struct CampaignAvatar: View {
  let campaign: Campaign
  var size: CGFloat = 60
  var body: some View {
    ZStack {
      Circle().fill(campaign.brandSurface)
      if LocalExperience.active {
        Image("BrilloLogo").resizable().scaledToFit().padding(size * 0.16)
      } else if let source = campaign.branding?.logo_url, let url = URL(string: source),
        url.scheme == "https"
      {
        AsyncImage(url: url) { image in
          image.resizable().scaledToFit()
        } placeholder: {
          Text(String(campaign.brand.prefix(1))).font(.system(size: size * 0.4, weight: .semibold))
        }.padding(size * 0.12)
      } else {
        Text(String(campaign.brand.prefix(1))).font(.system(size: size * 0.4, weight: .semibold))
      }
    }.frame(width: size, height: size).clipShape(Circle()).accessibilityHidden(true)
  }
}
struct CampaignHero: View {
  let campaign: Campaign
  var body: some View {
    Group {
      if LocalExperience.active {
        Image("BrilloHero").resizable().scaledToFill()
      } else if let source = campaign.branding?.hero_url, let url = URL(string: source),
        url.scheme == "https"
      {
        AsyncImage(url: url) { image in
          image.resizable().scaledToFill()
        } placeholder: {
          campaign.brandSurface.overlay(Image(systemName: "shippingbox").font(.largeTitle))
        }
      } else {
        campaign.brandSurface.overlay(CampaignAvatar(campaign: campaign, size: 100))
      }
    }.frame(height: 190).frame(maxWidth: .infinity).clipped().clipShape(
      RoundedRectangle(cornerRadius: 24)
    )
    .accessibilityLabel("Kampanjbild för \(campaign.brand)")
  }
}
struct AccountView: View {
  @ObservedObject var session: Session
  @State private var user: User?
  @State private var showGuide = false
  @State private var showLogin = false
  @State private var confirmReset = false
  @State private var error: String?
  #if DEBUG || FIELD_TESTING
    @ObservedObject private var test = SimulatorStore.shared
  #endif
  var body: some View {
    NavigationStack {
      List {
        Section {
          VStack(spacing: 12) {
            Image(systemName: "person.crop.circle.fill").font(.system(size: 88)).foregroundStyle(
              Color(white: 0.72))
            Text(LocalExperience.active ? "Ditt testkonto" : user?.name ?? "Ditt konto").font(
              .title.bold())
            Text(
              LocalExperience.active
                ? "Brillo Pizza · Odenplan" : user?.email ?? "Spara dina fynd och kuponger"
            ).foregroundStyle(.secondary)
          }.frame(maxWidth: .infinity).padding(.vertical, 20)
        }.listRowBackground(Color.clear)
        if !LocalExperience.active && !session.loggedIn {
          Section { Button("Logga in eller skapa konto") { showLogin = true } }
        }
        Section {
          Button {
            showGuide = true
          } label: {
            Label("Så fungerar VoucherHunt", systemImage: "questionmark.circle")
          }
          Button {
            if let url = URL(string: UIApplication.openSettingsURLString) {
              UIApplication.shared.open(url)
            }
          } label: {
            Label("Plats och kamera", systemImage: "location")
          }
        }
        #if DEBUG || FIELD_TESTING
          if LocalExperience.active {
            Section("Testa resan") {
              Label(
                LocalExperience.fieldTest ? "Riktig GPS och kamera" : "Simulerad insamling",
                systemImage: "viewfinder")
              Button("Börja om jakten") { confirmReset = true }
              Button("Testa utgången reservation") { test.expire() }
              if test.voucher != nil && !test.redeemed {
                Button("Testa inlöst kupong") { test.redeem() }
              }
            }
            Section {
              Text(
                LocalExperience.fieldTest
                  ? "Fälttestet sparar dina fynd på den här telefonen. Gå till Odenplan för att hitta pizzan. Testkupongen är inte ett riktigt erbjudande från Brillo Pizza."
                  : "Öppna Brillo Pizza under Upptäck och prova resan till kupongen. Kamera och GPS simuleras här."
              ).font(.footnote).foregroundStyle(.secondary)
            }
          }
        #endif
        if !LocalExperience.active && session.loggedIn {
          Section {
            Button("Logga ut", role: .destructive) {
              Task {
                await session.logout()
                user = nil
              }
            }
          }
        }
        if let error { Section { Text(error).font(.footnote).foregroundStyle(.secondary) } }
      }.navigationTitle("Konto").navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showGuide) { JourneyGuide().vouchhunterTheme() }
        .sheet(isPresented: $showLogin) { LoginView(session: session).vouchhunterTheme() }
        .onChange(of: session.loggedIn) { _, value in
          if value {
            showLogin = false
            Task { await load() }
          }
        }
        .confirmationDialog(
          "Börja om testjakten?", isPresented: $confirmReset, titleVisibility: .visible
        ) {
          #if DEBUG || FIELD_TESTING
            Button("Börja om", role: .destructive) { test.reset() }
          #endif
          Button("Avbryt", role: .cancel) {}
        } message: {
          Text("Dina lokala testfynd och testkupongen återställs. Riktiga kampanjer påverkas inte.")
        }
        .task { await load() }
    }
  }
  private func load() async {
    guard session.loggedIn && !LocalExperience.active else { return }
    do {
      user = try await API.shared.request("/me")
      error = nil
    } catch { self.error = error.localizedDescription }
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
            Text("Ditt nästa fynd väntar.").font(.system(.title, design: .default))
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
              if busy { ProgressView() } else { Text(register ? "Skapa konto" : "Logga in") }
              Spacer()
            }
          }
          .buttonStyle(HuntPillButton())
          .disabled(busy || email.isEmpty || password.count < 10 || (register && name.isEmpty))
          Button(register ? "Har du ett konto? Logga in" : "Ny här? Skapa konto") {
            register.toggle()
            error = ""
          }.frame(maxWidth: .infinity)
        }.listRowBackground(Color.clear)
      }.scrollContentBackground(.hidden).background(HuntStyle.canvas)
        .navigationTitle("VoucherHunt").navigationBarTitleDisplayMode(.inline)
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
  @State private var campaigns: [Campaign] = []
  @State private var error: String?
  @State private var loading = true
  @State private var query = ""
  @State private var showGuide = false
  private var filtered: [Campaign] {
    campaigns.filter {
      query.isEmpty
        || ($0.brand + " " + $0.title + " " + $0.reward).localizedCaseInsensitiveContains(query)
    }
  }
  var body: some View {
    NavigationStack {
      List {
        if LocalExperience.active {
          Section {
            Label("Exempelkampanj · Odenplan", systemImage: "testtube.2")
              .font(.footnote).foregroundStyle(.secondary)
          }.listRowSeparator(.hidden)
        }
        if loading {
          ProgressView("Hämtar kampanjer…").frame(maxWidth: .infinity).listRowSeparator(.hidden)
        }
        if let error {
          ContentUnavailableView {
            Label("Kunde inte hämta kampanjer", systemImage: "wifi.exclamationmark")
          } description: {
            Text(error)
          } actions: {
            Button("Försök igen") { Task { await load() } }.buttonStyle(HuntSecondaryButton())
          }.listRowSeparator(.hidden)
        } else if !loading && filtered.isEmpty {
          ContentUnavailableView(
            query.isEmpty ? "Inga jakter just nu" : "Ingen träff", systemImage: "map",
            description: Text(
              query.isEmpty
                ? "Nya kampanjer visas här när de öppnar. Dra nedåt för att uppdatera."
                : "Prova ett annat namn eller erbjudande.")
          )
          .listRowSeparator(.hidden)
        }
        ForEach(filtered) { campaign in
          NavigationLink {
            CampaignOverviewView(campaign: campaign)
          } label: {
            HStack(alignment: .top, spacing: 14) {
              CampaignAvatar(campaign: campaign)
              VStack(alignment: .leading, spacing: 5) {
                HStack(alignment: .firstTextBaseline) {
                  Text(campaign.brand).font(.headline)
                  Spacer(minLength: 8)
                  Text("\(campaign.target) fynd").font(.caption).foregroundStyle(.secondary)
                }
                Text(campaign.title).font(.subheadline).foregroundStyle(.secondary)
                Text(campaign.collectionPitch).font(.subheadline).fixedSize(
                  horizontal: false, vertical: true
                )
                .padding(.top, 3)
                if LocalExperience.active {
                  Text("Exempel · testkupong utan värde").font(.caption).foregroundStyle(.secondary)
                    .padding(.top, 3)
                }
              }
            }.padding(.vertical, 8)
          }.listRowSeparatorTint(HuntStyle.line)
        }
      }.listStyle(.plain).background(HuntStyle.surface)
        .navigationTitle("Upptäck").navigationBarTitleDisplayMode(.large)
        .searchable(text: $query, prompt: "Sök kampanj eller företag")
        .toolbar {
          ToolbarItem(placement: .topBarTrailing) {
            Button {
              showGuide = true
            } label: {
              Image(systemName: "questionmark")
            }
            .accessibilityLabel("Så fungerar VoucherHunt")
          }
        }
        .refreshable { await load() }.task { await load() }
        .sheet(isPresented: $showGuide) { JourneyGuide().vouchhunterTheme() }
    }
  }
  private func load() async {
    #if DEBUG || FIELD_TESTING
      if LocalExperience.active {
        campaigns = [SimulatorHunt.campaign]
        loading = false
        return
      }
    #endif
    loading = true
    defer { loading = false }
    do {
      let r: CampaignList = try await API.shared.request("/campaigns")
      campaigns = r.campaigns
      error = nil
    } catch { self.error = error.localizedDescription }
  }
}
struct IntroductionView: View {
  var onContinue: () -> Void
  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 20) {
        VStack(alignment: .leading, spacing: 18) {
          Image(systemName: "map.fill").font(.system(size: 34, weight: .medium))
            .foregroundStyle(HuntStyle.accent).padding(16).background(
              .white, in: RoundedRectangle(cornerRadius: 28)
            )
            .accessibilityHidden(true)
          Text("Välkommen till\nVoucherHunt").font(.largeTitle.bold()).fixedSize(
            horizontal: false, vertical: true)
          Text("Gör stan till en skattjakt.").font(.title3.weight(.semibold))
          Text(
            "Hitta företagens gömda föremål på stan. Samla dem med kameran och lås upp kuponger."
          )
          .foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }
        VStack(spacing: 0) {
          step(
            "Hitta något du vill ha",
            detail: "Välj en kampanj och se vad du kan få.",
            icon: "ticket")
          Divider().padding(.leading, 46)
          step(
            "Gå ut och samla",
            detail:
              "Följ kartan. När du är nära ser du föremålet i din omgivning genom kameran.",
            icon: "viewfinder")
          Divider().padding(.leading, 46)
          step(
            "Hämta din belöning",
            detail:
              "Nå målet och få din kupong. Visa den hos företaget enligt kampanjens villkor.",
            icon: "gift")
        }.padding(.horizontal, 16).background(.white, in: RoundedRectangle(cornerRadius: 24))
        Text(
          "Du kan börja med att titta runt. Vi frågar om plats och kamera först när de behövs i jakten."
        )
        .font(.footnote).foregroundStyle(.secondary)
      }.padding(24)
    }.background(HuntStyle.canvas)
      .safeAreaInset(edge: .bottom) {
        Button("Upptäck kampanjer", action: onContinue).buttonStyle(HuntPillButton())
          .padding(20).background(HuntStyle.canvas)
      }
  }
  private func step(_ title: String, detail: String, icon: String) -> some View {
    HStack(alignment: .top, spacing: 16) {
      Image(systemName: icon).font(.title3).frame(width: 30).accessibilityHidden(true)
      VStack(alignment: .leading, spacing: 5) {
        Text(title).font(.headline)
        Text(detail).font(.subheadline).foregroundStyle(.secondary).fixedSize(
          horizontal: false, vertical: true)
      }
    }.frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 18)
  }
}
struct JourneyGuide: View {
  @Environment(\.dismiss) private var dismiss
  var body: some View { IntroductionView { dismiss() } }
}
struct CampaignOverviewView: View {
  let campaign: Campaign
  @EnvironmentObject private var session: Session
  @State private var showLogin = false
  @State private var openHunt = false
  var body: some View {
    ScrollView {
      VStack(spacing: 24) {
        VStack(spacing: 12) {
          CampaignAvatar(campaign: campaign, size: 112)
          Text(campaign.brand).font(.largeTitle.bold())
          Text(campaign.title).font(.body).foregroundStyle(.secondary)
          if LocalExperience.active {
            Text("Exempelkampanj").font(.caption).padding(.horizontal, 12).padding(.vertical, 5)
              .background(HuntStyle.mint, in: Capsule())
          }
        }.padding(.top, 20)
        CampaignHero(campaign: campaign)
        VStack(alignment: .leading, spacing: 12) {
          Label(campaign.reward, systemImage: "ticket").font(.title3.weight(.semibold))
          Text(LocalExperience.active ? campaign.collectionPitch : campaign.description)
            .foregroundStyle(.secondary)
        }.huntPanel()
        VStack(spacing: 0) {
          overviewRow("Samla", value: "\(campaign.target) föremål", icon: "shippingbox")
          Divider().padding(.leading, 40)
          overviewRow(
            "Område",
            value: SimulatorMode.active ? "Odenplan" : (campaign.stops.first?.name ?? "Se kartan"),
            icon: "mappin.and.ellipse")
          Divider().padding(.leading, 40)
          overviewRow("Tid när du startar", value: "Upp till 60 min", icon: "clock")
        }.huntPanel()
        VStack(alignment: .leading, spacing: 10) {
          Text("Bra att veta").font(.headline)
          Text(campaign.terms).foregroundStyle(.secondary)
          Text(
            LocalExperience.active
              ? "Testkupongen sparas på den här enheten och kan inte lösas in hos Brillo Pizza."
              : "Lös in hos \(campaign.venue). Gäller i \(campaign.voucher_days) dagar efter slutförd jakt."
          ).font(.footnote).foregroundStyle(.secondary)
        }.huntPanel()
      }.padding(16)
    }.background(HuntStyle.canvas)
      .navigationTitle("Om kampanjen").navigationBarTitleDisplayMode(.inline)
      .safeAreaInset(edge: .bottom) {
        Button {
          if LocalExperience.active || session.loggedIn {
            openHunt = true
          } else {
            showLogin = true
          }
        } label: {
          Text("Öppna jakten")
        }
        .buttonStyle(HuntPillButton(fill: campaign.buttonAccent, ink: campaign.accentText))
        .padding(16).background(HuntStyle.canvas)
      }
      .navigationDestination(isPresented: $openHunt) { HuntView(campaign: campaign) }
      .sheet(isPresented: $showLogin) {
        LoginView(session: session).vouchhunterTheme().overlay(alignment: .topTrailing) {
          Button("Stäng") { showLogin = false }.padding()
        }
      }
      .onChange(of: session.loggedIn) { _, loggedIn in
        if loggedIn && showLogin {
          showLogin = false
          openHunt = true
        }
      }
  }
  private func overviewRow(_ title: String, value: String, icon: String) -> some View {
    HStack(spacing: 14) {
      Image(systemName: icon).frame(width: 24)
      Text(title)
      Spacer(minLength: 10)
      Text(value).foregroundStyle(.secondary).multilineTextAlignment(.trailing)
    }.padding(.vertical, 13)
  }
}
/// A collectible scene on the map. The active campaign uses its uploaded USDZ.
struct CollectibleMapObject: UIViewRepresentable {
  let url: URL?
  let pizzaPreview: Bool
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
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
    object.name = "collectible"
    scene.rootNode.addChildNode(object)
    let ring = SCNNode(geometry: SCNTorus(ringRadius: 0.78, pipeRadius: 0.012))
    ring.name = "halo"
    ring.geometry?.firstMaterial?.diffuse.contents = UIColor.white
    ring.geometry?.firstMaterial?.emission.contents = UIColor(white: 0.85, alpha: 1)
    ring.position.y = -0.18
    scene.rootNode.addChildNode(ring)
    if !reduceMotion { animate(object, ring) }
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
  private func animate(_ object: SCNNode, _ ring: SCNNode) {
    object.runAction(
      .repeatForever(
        .sequence([
          .moveBy(x: 0, y: 0.07, z: 0, duration: 1.4), .moveBy(x: 0, y: -0.07, z: 0, duration: 1.4),
        ])), forKey: "float")
    ring.runAction(
      .repeatForever(
        .sequence([
          .group([.scale(to: 1.1, duration: 1), .fadeOpacity(to: 0.35, duration: 1)]),
          .group([.scale(to: 1, duration: 1), .fadeOpacity(to: 1, duration: 1)]),
        ])), forKey: "pulse")
  }
  func updateUIView(_ view: SCNView, context: Context) {
    guard let object = view.scene?.rootNode.childNode(withName: "collectible", recursively: false),
      let ring = view.scene?.rootNode.childNode(withName: "halo", recursively: false)
    else { return }
    if reduceMotion {
      object.removeAllActions()
      ring.removeAllActions()
      ring.scale = SCNVector3(1, 1, 1)
      ring.opacity = 1
    } else if object.action(forKey: "float") == nil {
      animate(object, ring)
    }
  }
}
struct HuntView: View {
  let campaign: Campaign
  private var isPreview: Bool { SimulatorMode.active }
  #if DEBUG || FIELD_TESTING
    @ObservedObject private var simulator = SimulatorStore.shared
  #endif
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
  private var objectName: String {
    LocalExperience.active ? "Pizza" : campaign.model?.name ?? "Föremål"
  }
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
        Text(campaign.title).font(.system(.title, design: .default))
        HuntRule()
        Text(campaign.description).foregroundStyle(.secondary)
        Label(
          "Till \(Date(timeIntervalSince1970: campaign.ends).formatted(date: .abbreviated, time: .shortened))",
          systemImage: "calendar"
        )
        .font(.subheadline).foregroundStyle(.secondary)
        VStack(alignment: .leading, spacing: 12) {
          Text("Belöning").font(.caption).foregroundStyle(.secondary)
          Text(campaign.reward).font(.system(.title2, design: .default))
          Text("Samla \(campaign.target) objekt för att få din belöning.")
          if let hunt {
            ProgressView(value: Double(hunt.collected.count), total: Double(campaign.target))
            Text("\(hunt.collected.count) av \(campaign.target) insamlade").font(.subheadline)
          }
        }.huntPanel()
        if let hunt, hunt.completed != nil {
          Label("Du är klar! Din voucher finns i plånboken.", systemImage: "checkmark.seal.fill")
            .foregroundStyle(HuntStyle.green)
          Button("Visa min voucher", systemImage: "qrcode") { showWallet = true }
            .buttonStyle(HuntPillButton(fill: campaign.buttonAccent, ink: campaign.accentText))
        } else if hunt == nil || (hunt?.expires ?? 0) <= clock.timeIntervalSince1970 {
          Text(
            "En belöning reserveras i upp till 60 minuter, senast till kampanjens slut. Du behöver vara vid platserna för att samla."
          ).font(.footnote).foregroundStyle(.secondary)
          Button("Starta jakten") { Task { await start() } }.buttonStyle(
            HuntPillButton(fill: campaign.buttonAccent, ink: campaign.accentText)
          )
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
        }.mapStyle(
          .standard(elevation: .realistic, emphasis: .muted, pointsOfInterest: .excludingAll)
        ).frame(height: 240).clipShape(RoundedRectangle(cornerRadius: 16))
        HuntRule()
        Text("Platser i jakten").font(.system(.title3, design: .default))
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
              }.buttonStyle(HuntSecondaryButton()).disabled(!canCollect(s) && !isPreview)
            }
          }.padding(.vertical, 10)
          HuntRule()
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
    .background(HuntStyle.canvas)
  }
  var body: some View {
    ZStack(alignment: .top) {
      Map(position: $mapPosition) {
        UserAnnotation()
        ForEach(campaign.stops.filter { hunt?.collected.contains($0.id) != true }) { stop in
          Annotation(stop.name, coordinate: .init(latitude: stop.lat, longitude: stop.lon)) {
            if stop.id == nextStop?.id {
              Button {
                if canCollect(stop) || isPreview {
                  captureCount = hunt?.collected.count ?? 0
                  selected = stop
                } else {
                  showDetails = true
                }
              } label: {
                VStack(spacing: 0) {
                  if isPreview || thumbnailURL != nil {
                    CollectibleMapObject(
                      url: thumbnailURL, pizzaPreview: isPreview && thumbnailURL == nil
                    ).id(thumbnailURL).frame(
                      width: 112, height: 108
                    ).allowsHitTesting(false)
                  } else {
                    Image(systemName: "cube.fill").font(.system(size: 42)).foregroundStyle(
                      HuntStyle.green
                    )
                    .padding(20).background(HuntStyle.surface, in: Circle())
                  }
                  Text(objectName).font(.system(.subheadline, design: .default, weight: .bold))
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
      .mapControls {}
      HStack {
        Button {
          showDetails = true
        } label: {
          HStack(spacing: 10) {
            Text("\(hunt?.collected.count ?? 0) / \(campaign.target)").font(
              .system(.headline, design: .default, weight: .bold))
            Text("fynd").font(.subheadline).foregroundStyle(.secondary)
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
      }.foregroundStyle(HuntStyle.accent)
        .padding(.horizontal, 20).padding(.top, 8)
    }
    .safeAreaInset(edge: .bottom, spacing: 0) {
      VStack(alignment: .leading, spacing: 16) {
        Capsule().fill(Color.secondary.opacity(0.3)).frame(width: 36, height: 5)
          .frame(maxWidth: .infinity).accessibilityHidden(true)
        if hunt?.completed != nil {
          Label("Alla fynd är samlade", systemImage: "checkmark.circle.fill").font(
            .title3.weight(.semibold))
          Text(campaign.reward).foregroundStyle(.secondary)
          Button("Visa min kupong") { showWallet = true }.buttonStyle(
            HuntPillButton(fill: campaign.buttonAccent, ink: campaign.accentText))
        } else if hunt == nil || (hunt?.expires ?? 0) <= clock.timeIntervalSince1970 {
          Text(hunt == nil ? "Redo att börja?" : "Reservationen har gått ut").font(
            .title3.weight(.semibold))
          Text("Samla \(campaign.target) föremål och lås upp \(campaign.reward.lowercased()).")
            .foregroundStyle(.secondary)
          Button {
            Task { await start() }
          } label: {
            HStack {
              if busy { ProgressView().tint(.white) }
              Text("Starta jakten")
            }
          }.buttonStyle(HuntPillButton(fill: campaign.buttonAccent, ink: campaign.accentText))
            .disabled(
              busy || campaign.ends <= clock.timeIntervalSince1970
                || campaign.starts > clock.timeIntervalSince1970)
          Text("Din belöning reserveras i upp till 60 minuter.").font(.footnote).foregroundStyle(
            .secondary)
        } else if let next = nextStop {
          Button {
            showDetails = true
          } label: {
            HStack(spacing: 12) {
              CampaignAvatar(campaign: campaign, size: 48)
              VStack(alignment: .leading, spacing: 4) {
                Text(next.name).font(.headline)
                Text(isPreview ? "Simulerad närhet · Odenplan" : collectionHint(next)).font(
                  .subheadline
                ).foregroundStyle(.secondary)
              }
              Spacer(minLength: 4)
              Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(
                .secondary)
            }.padding(14).background(HuntStyle.surface, in: RoundedRectangle(cornerRadius: 22))
          }.buttonStyle(.plain)
          HStack {
            Text("\(hunt?.collected.count ?? 0) av \(campaign.target) insamlade").font(.subheadline)
            Spacer()
            Text(campaign.reward).font(.subheadline).foregroundStyle(.secondary)
              .multilineTextAlignment(.trailing)
          }
          ProgressView(value: Double(hunt?.collected.count ?? 0), total: Double(campaign.target))
            .tint(campaign.accent)
          if canCollect(next) || isPreview {
            Button(isPreview ? "Prova att samla" : "Öppna kameran") {
              captureCount = hunt?.collected.count ?? 0
              selected = next
            }.buttonStyle(HuntPillButton(fill: campaign.buttonAccent, ink: campaign.accentText))
          } else if location.permissionDenied {
            Button("Tillåt platsåtkomst") {
              if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
            }.buttonStyle(HuntPillButton(fill: campaign.buttonAccent, ink: campaign.accentText))
          } else if location.location == nil {
            Button("Hämta min position") { location.start() }
              .buttonStyle(HuntPillButton(fill: campaign.buttonAccent, ink: campaign.accentText))
          } else {
            Button("Visa gångväg") { directions(next) }.buttonStyle(
              HuntPillButton(fill: campaign.buttonAccent, ink: campaign.accentText))
          }
        }
        if !error.isEmpty {
          Label(error, systemImage: "exclamationmark.circle").font(.footnote).foregroundStyle(.red)
        }
        if let message = location.message {
          Text(message).font(.footnote).foregroundStyle(.secondary)
        }
      }.padding(.horizontal, 16).padding(.top, 8).padding(.bottom, 16)
        .background(HuntStyle.canvas.ignoresSafeArea(edges: .bottom))
    }
    .fontDesign(.default).preferredColorScheme(.light).tint(campaign.accent)
    .navigationTitle(isPreview ? "Brillo Pizza · Test" : campaign.brand)
    .navigationBarTitleDisplayMode(
      .inline
    )
    .sheet(isPresented: $showDetails) {
      NavigationStack {
        detailContent.navigationTitle("Om jakten").navigationBarTitleDisplayMode(.inline)
          .toolbar {
            ToolbarItem(placement: .confirmationAction) { Button("Klart") { showDetails = false } }
          }
      }.vouchhunterTheme().presentationDetents([.medium, .large]).presentationDragIndicator(
        .visible)
    }
    .task {
      if LocalExperience.active {
        #if DEBUG || FIELD_TESTING
          if LocalExperience.fieldTest { location.start() }
          hunt = simulator.hunt
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
      if LocalExperience.active {
        thumbnailURL = LocalExperience.modelURL
        return
      }
      guard let model = campaign.model else { return }
      thumbnailURL = try? await API.shared.modelFile(assetID: model.usdz_asset_id)
    }
    #if DEBUG || FIELD_TESTING
      .onReceive(simulator.$hunt) { value in
        if LocalExperience.active {
          hunt = value
          focusNext()
        }
      }
    #endif
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
        if !isPreview { location.start() }
        if hunt?.completed != nil { showWallet = true }
      }
    ) { s in
      #if DEBUG || FIELD_TESTING
        if isPreview {
          SimulatorCapture(stop: s).vouchhunterTheme()
        } else {
          captureView(s)
        }
      #else
        captureView(s)
      #endif
    }
  }
  private func captureView(_ s: Stop) -> some View {
    CaptureView(
      stop: s, model: campaign.model,
      localModelURL: LocalExperience.fieldTest ? LocalExperience.modelURL : nil,
      collectedCount: captureCount, target: campaign.target
    ) { try await collect(s) }.vouchhunterTheme()
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
    guard let hunt, hunt.completed == nil, !hunt.collected.contains(stop.id),
      hunt.expires > Date().timeIntervalSince1970,
      let loc = location.location, loc.horizontalAccuracy >= 0, loc.horizontalAccuracy <= 35,
      abs(loc.timestamp.timeIntervalSinceNow) < 45
    else { return false }
    return loc.distance(from: CLLocation(latitude: stop.lat, longitude: stop.lon))
      <= Double(stop.radius)
  }
  private func start() async {
    if LocalExperience.active {
      #if DEBUG || FIELD_TESTING
        simulator.start()
        hunt = simulator.hunt
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
    #if DEBUG || FIELD_TESTING
      if LocalExperience.fieldTest {
        guard canCollect(stop) else {
          throw APIError.message("Gå närmare föremålet och vänta på en noggrann position.")
        }
        simulator.collect(stop.id)
        hunt = simulator.hunt
        return
      }
    #endif
    location.start()
    var payload = try location.payload()
    payload["stop_id"] = stop.id
    hunt = try await API.shared.request("/hunts/" + campaign.id + "/collect", body: payload)
  }
}

#if DEBUG || FIELD_TESTING
  /// Offline visual fixture. Never published, paid, or granted backend privileges.
  enum SimulatorHunt {
    static let campaign: Campaign = {
      let coordinates: [(String, Double, Double)] = [
        ("Odenplan", 59.3428, 18.0497), ("Odenplan · fynd 2", 59.3429, 18.0498),
        ("Odenplan · fynd 3", 59.3430, 18.0499), ("Odenplan · fynd 4", 59.3427, 18.0498),
        ("Odenplan · fynd 5", 59.3428, 18.0500), ("Odenplan · fynd 6", 59.3429, 18.0501),
        ("Odenplan · fynd 7", 59.3427, 18.0500), ("Odenplan · fynd 8", 59.3426, 18.0500),
        ("Odenplan · fynd 9", 59.3428, 18.0502), ("Odenplan · fynd 10", 59.3429, 18.0503),
      ]
      let payload: [String: Any] = [
        "id": "simulator-preview", "title": "Upptäck vår nya pizza",
        "brand": "Brillo Pizza",
        "branding": ["accent_color": "#FF113A", "background_color": "#FFF5EB"],
        "description":
          (LocalExperience.fieldTest
          ? "Brillo Pizza lanserar en ny pizza i den här exempelkampanjen. Hitta pizzan vid Odenplan, samla den i AR och lås upp en testkupong."
          : "Brillo Pizza lanserar en ny pizza i den här exempelkampanjen. Hitta tio pizzor vid Odenplan och samla dem för att låsa upp en testkupong."),
        "reward": "En nybakad pizza",
        "terms": "Lokal testjakt. Ingen riktig kampanj eller giltig voucher.",
        "venue": "Brillo Pizza · Exempel", "target": LocalExperience.fieldTest ? 1 : 10,
        "capacity": 100, "voucher_days": 1,
        "starts": Date().timeIntervalSince1970 - 60, "ends": Date().timeIntervalSince1970 + 86400,
        "stops": (LocalExperience.fieldTest ? Array(coordinates.prefix(1)) : coordinates)
          .enumerated().map { i, item in
            [
              "id": "preview-\(i)", "campaign_id": "simulator-preview", "name": item.0,
              "lat": item.1,
              "lon": item.2, "radius": 50,
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

enum SimulatorMode {
  static var active: Bool {
    #if DEBUG && targetEnvironment(simulator)
      ProcessInfo.processInfo.arguments.contains("--preview-hunt")
    #else
      false
    #endif
  }
}
enum LocalExperience {
  static var fieldTest: Bool {
    #if FIELD_TESTING
      true
    #elseif DEBUG
      ProcessInfo.processInfo.arguments.contains("--field-test")
    #else
      false
    #endif
  }
  static var active: Bool { SimulatorMode.active || fieldTest }
  static var modelURL: URL? { Bundle.main.url(forResource: "brillo-pizza", withExtension: "usdz") }
}

#if DEBUG || FIELD_TESTING
  @MainActor final class SimulatorStore: ObservableObject {
    static let shared = SimulatorStore()
    @Published private(set) var hunt: Hunt?
    init() {
      if LocalExperience.fieldTest,
        let data = UserDefaults.standard.data(forKey: "vouchhunter.field-hunt.v1")
      {
        hunt = try? JSONDecoder().decode(Hunt.self, from: data)
        redeemed = hunt?.voucher?.redeemed != nil
      }
    }
    private func persist() {
      guard LocalExperience.fieldTest else { return }
      UserDefaults.standard.set(
        try? JSONEncoder().encode(hunt), forKey: "vouchhunter.field-hunt.v1")
    }
    @Published private(set) var redeemed = false
    var voucher: Voucher? { hunt?.voucher }
    func start() {
      redeemed = false
      hunt = nil
      update(ids: [])
    }
    func reset() {
      redeemed = false
      hunt = nil
      persist()
    }
    func expire() { update(ids: hunt?.collected ?? [], expired: true) }
    func redeem() {
      redeemed = true
      update(ids: hunt?.collected ?? [])
    }
    func collect(_ id: String) {
      guard let hunt, hunt.completed == nil, hunt.expires > Date().timeIntervalSince1970,
        !hunt.collected.contains(id), SimulatorHunt.campaign.stops.contains(where: { $0.id == id })
      else { return }
      update(ids: hunt.collected + [id])
    }
    private func update(ids: [String], expired: Bool = false) {
      let complete = ids.count >= SimulatorHunt.campaign.target
      var payload: [String: Any] = [
        "id": "preview-hunt",
        "expires": expired
          ? Date().timeIntervalSince1970 - 1
          : (hunt?.expires ?? Date().timeIntervalSince1970 + 3600),
        "collected": ids,
      ]
      if complete {
        payload["completed"] = hunt?.completed ?? Date().timeIntervalSince1970
        var voucher: [String: Any] = [
          "id": "local-test-voucher", "code": "SIMULATOR-NOT-REDEEMABLE",
          "expires": hunt?.voucher?.expires ?? Date().timeIntervalSince1970 + 86400,
          "title": "Upptäck vår nya pizza",
          "reward": "En nybakad pizza", "venue": "Brillo Pizza · Exempel",
          "terms": "TESTKUPONG. Kan inte lösas in hos ett företag.",
        ]
        if redeemed { voucher["redeemed"] = Date().timeIntervalSince1970 }
        payload["voucher"] = voucher
      }
      hunt = try! JSONDecoder().decode(
        Hunt.self, from: JSONSerialization.data(withJSONObject: payload))
      persist()
    }
  }
  struct SimulatorExperience: View {
    @StateObject private var session = Session()
    var body: some View {
      TabView {
        ExploreView().tabItem { Label("Upptäck", systemImage: "map") }
        WalletView().tabItem { Label("Kuponger", systemImage: "ticket") }
        AccountView(session: session).tabItem { Label("Konto", systemImage: "person.crop.circle") }
      }.environmentObject(session)
    }
  }
  struct SimulatorCapture: View {
    let stop: Stop
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var store = SimulatorStore.shared
    @State private var collected = false
    var body: some View {
      VStack(spacing: 24) {
        HStack {
          Text("Simulerat möte").font(.subheadline)
          Spacer()
          Button {
            dismiss()
          } label: {
            Image(systemName: "xmark").frame(width: 44, height: 44)
          }
          .buttonStyle(HuntSecondaryButton()).accessibilityLabel("Stäng mötet")
        }
        HuntRule()
        Text(stop.name).font(.system(.title2, design: .default))
        Spacer()
        Button {
          collect()
        } label: {
          CollectibleMapObject(url: LocalExperience.modelURL, pizzaPreview: false).frame(
            height: 250
          )
          .opacity(collected ? 0.25 : 1)
        }.buttonStyle(.plain).disabled(collected).accessibilityLabel("Samla pizzan")
        Text(collected ? "Fynd insamlat" : "Där är ditt fynd").font(
          .system(.title2, design: .default))
        Text("\(store.hunt?.collected.count ?? 0) / 10").foregroundStyle(HuntStyle.electric)
        Spacer()
        Text("Lokal simulering utan kamera eller GPS.").font(.footnote).foregroundStyle(.secondary)
        Button(
          collected
            ? (store.voucher != nil ? "Visa testkupongen" : "Fortsätt jakten")
            : "Samla föremålet"
        ) {
          if collected { dismiss() } else { collect() }
        }.buttonStyle(HuntPillButton())
      }.padding(24).background(HuntStyle.canvas)
    }
    private func collect() {
      guard !collected else { return }
      store.collect(stop.id)
      collected = store.hunt?.collected.contains(stop.id) == true
    }
  }
#endif
