import HuntCore
import MapKit
import SwiftUI

@main struct VouchhunterApp: App {
  var body: some Scene { WindowGroup { RootView().tint(Brand.accent) } }
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
struct HuntView: View {
  let campaign: Campaign
  @StateObject private var location = LocationService()
  @State private var hunt: Hunt?
  @State private var selected: Stop?
  @State private var error = ""
  @State private var busy = false
  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 20) {
        Text(campaign.brand).font(.subheadline).foregroundStyle(.secondary)
        Text(campaign.title).font(.largeTitle.bold())
        Text(campaign.description).foregroundStyle(.secondary)
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
            .foregroundStyle(.green)
        } else if hunt == nil || (hunt?.expires ?? 0) < Date().timeIntervalSince1970 {
          Text(
            "En belöning reserveras i upp till 60 minuter, senast till kampanjens slut. Du behöver vara vid platserna för att samla."
          ).font(.footnote).foregroundStyle(.secondary)
          Button("Starta jakten") { Task { await start() } }.buttonStyle(.borderedProminent)
            .disabled(busy)
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
        ForEach(campaign.stops) { s in
          HStack {
            VStack(alignment: .leading) {
              Text(s.name).font(.headline)
              if let loc = location.location {
                Text("\(Int(loc.distance(from:CLLocation(latitude:s.lat,longitude:s.lon)))) m bort")
                  .foregroundStyle(.secondary).font(.footnote)
              }
            }
            Spacer()
            if hunt?.collected.contains(s.id) == true {
              Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
            } else {
              Button("Samla") { selected = s }.buttonStyle(.bordered).disabled(!canCollect(s))
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
    }.background(Color(.systemGroupedBackground)).navigationTitle("Jakten")
      .navigationBarTitleDisplayMode(.inline)
      .task {
        location.start()
        do {
          let r: HuntEnvelope = try await API.shared.request("/hunts/" + campaign.id)
          hunt = r.hunt
        } catch { self.error = error.localizedDescription }
      }
      .onDisappear { if selected == nil { location.stop() } }
      .fullScreenCover(item: $selected, onDismiss: { location.start() }) { s in
        CaptureView(stop: s, model: campaign.model) { try await collect(s) }
      }
  }
  private func canCollect(_ stop: Stop) -> Bool {
    guard let hunt, hunt.completed == nil, hunt.expires > Date().timeIntervalSince1970,
      let loc = location.location, loc.horizontalAccuracy >= 0, loc.horizontalAccuracy <= 35,
      abs(loc.timestamp.timeIntervalSinceNow) < 45
    else { return false }
    return loc.distance(from: CLLocation(latitude: stop.lat, longitude: stop.lon))
      <= Double(stop.radius)
  }
  private func start() async {
    busy = true
    defer { busy = false }
    do {
      hunt = try await API.shared.request("/hunts/" + campaign.id + "/start", body: [:])
      error = ""
    } catch { self.error = error.localizedDescription }
  }
  private func collect(_ stop: Stop) async throws {
    location.start()
    var payload = try location.payload()
    payload["stop_id"] = stop.id
    hunt = try await API.shared.request("/hunts/" + campaign.id + "/collect", body: payload)
  }
}
