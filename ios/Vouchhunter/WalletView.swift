import CoreImage.CIFilterBuiltins
import HuntCore
import SwiftUI

struct WalletView: View {
  #if DEBUG && targetEnvironment(simulator)
    @ObservedObject private var simulator = SimulatorStore.shared
  #endif
  @State private var vouchers: [Voucher] = []
  @State private var error: String?
  @State private var loading = true
  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(spacing: 20) {
          if loading { ProgressView("Hämtar dina vouchers…") }
          if let error {
            ContentUnavailableView(
              "Kunde inte hämta vouchers", systemImage: "wifi.exclamationmark",
              description: Text(error))
            Button("Försök igen") { Task { await load() } }.buttonStyle(HuntPillButton())
          }
          if !loading && error == nil && vouchers.isEmpty {
            ContentUnavailableView(
              "Något gott att se fram emot", systemImage: "ticket",
              description: Text("Slutför en jakt så sparas din belöning här."))
          }
          ForEach(vouchers) { v in
            VStack(alignment: .leading, spacing: 16) {
              Text((v.title ?? "Din belöning").uppercased()).font(.subheadline).foregroundStyle(
                .secondary)
              HuntRule()
              Text((v.reward ?? "Kupong").uppercased()).font(.system(.title2, design: .monospaced))
              if SimulatorMode.active {
                Label("TESTKUPONG · EJ GILTIG FÖR INLÖSEN", systemImage: "testtube.2").font(
                  .footnote
                ).foregroundStyle(HuntStyle.electric)
              }
              if v.isValid && !SimulatorMode.active, let image = qr(v.code) {
                Image(uiImage: image).interpolation(.none).resizable().scaledToFit().frame(
                  width: 210, height: 210
                ).frame(maxWidth: .infinity).accessibilityLabel("QR-kod för inlösen")
              }
              Text(
                v.redeemed != nil
                  ? "Inlöst"
                  : v.isValid ? "Visa för personalen vid inlösen" : "Giltighetstiden har gått ut"
              ).font(.headline)
              Text(v.venue ?? "")
              Text(
                "Gäller till \(Date(timeIntervalSince1970:v.expires).formatted(date:.abbreviated,time:.shortened))"
              ).font(.footnote)
              if v.isValid { Text(v.code).font(.caption.monospaced()).textSelection(.enabled) }
              if let terms = v.terms { Text(terms).font(.footnote).foregroundStyle(.secondary) }
            }.huntPanel()
          }
        }.padding(20)
      }.background(HuntStyle.canvas).navigationTitle("DINA KUPONGER").navigationBarTitleDisplayMode(
        .inline
      ).task { await load() }.refreshable { await load() }
        #if DEBUG && targetEnvironment(simulator)
          .onReceive(simulator.$hunt) { hunt in
            if SimulatorMode.active {
              vouchers = hunt?.voucher.map { [$0] } ?? []
              loading = false
            }
          }
        #endif
    }
  }
  private func load() async {
    #if DEBUG && targetEnvironment(simulator)
      if SimulatorMode.active {
        vouchers = simulator.voucher.map { [$0] } ?? []
        loading = false
        return
      }
    #endif
    loading = true
    defer { loading = false }
    do {
      let r: VoucherList = try await API.shared.request("/vouchers")
      vouchers = r.vouchers
      error = nil
    } catch { self.error = error.localizedDescription }
  }
  private func qr(_ value: String) -> UIImage? {
    let filter = CIFilter.qrCodeGenerator()
    filter.message = Data(value.utf8)
    guard let output = filter.outputImage,
      let image = CIContext().createCGImage(
        output.transformed(by: CGAffineTransform(scaleX: 9, y: 9)),
        from: output.extent.applying(CGAffineTransform(scaleX: 9, y: 9)))
    else { return nil }
    return UIImage(cgImage: image)
  }
}
