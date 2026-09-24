import XCTest

@testable import HuntCore

final class HuntCoreTests: XCTestCase {
  func testDistanceDoesNotTreatDifferentLongitudesAsSameLocation() {
    XCTAssertEqual(
      Geo.distance(lat1: 59.3326, lon1: 18.0649, lat2: 59.3326, lon2: 18.0649), 0, accuracy: 0.001)
    XCTAssertGreaterThan(
      Geo.distance(lat1: 59.3326, lon1: 18.0649, lat2: 59.3326, lon2: 18.0749), 500)
  }
  func testDecodeIssuedVoucherWithNullableRedeemed() throws {
    let data = Data(#"{"id":"abc","code":"secret","expires":1900000000,"redeemed":null}"#.utf8)
    let v = try JSONDecoder().decode(Voucher.self, from: data)
    XCTAssertNil(v.redeemed)
    XCTAssertNil(v.title)
    XCTAssertNil(v.brand)
    XCTAssertNil(v.branding)
  }
  func testDecodeBrandedVoucherInCompletedHunt() throws {
    let data = Data(#"{"id":"h","expires":1900000000,"completed":1800000000,"collected":["s"],"voucher":{"id":"v","code":"test-code","expires":1900000000,"campaign_id":"c","brand":"Pizzeria Ett","title":"Ny pizza","terms":"En per person","branding":{"accent_color":"#FF113A","logo_url":"https://example.com/logo.png"}}}"#.utf8)
    let hunt = try JSONDecoder().decode(Hunt.self, from: data)
    XCTAssertEqual(hunt.voucher?.campaign_id, "c")
    XCTAssertEqual(hunt.voucher?.brand, "Pizzeria Ett")
    XCTAssertEqual(hunt.voucher?.terms, "En per person")
    XCTAssertEqual(hunt.voucher?.branding?.accent_color, "#FF113A")
    let restored = try JSONDecoder().decode(Hunt.self, from: JSONEncoder().encode(hunt))
    XCTAssertEqual(restored.voucher?.branding?.logo_url, "https://example.com/logo.png")
  }
  func testHuntContractSupportsNoVoucher() throws {
    let data = Data(
      #"{"id":"h","expires":1900000000,"completed":null,"collected":["s"],"voucher":null}"#.utf8)
    XCTAssertEqual(try JSONDecoder().decode(Hunt.self, from: data).collected, ["s"])
  }
}
