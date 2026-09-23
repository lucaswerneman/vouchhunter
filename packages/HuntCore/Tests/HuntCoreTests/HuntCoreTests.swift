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
  }
  func testHuntContractSupportsNoVoucher() throws {
    let data = Data(
      #"{"id":"h","expires":1900000000,"completed":null,"collected":["s"],"voucher":null}"#.utf8)
    XCTAssertEqual(try JSONDecoder().decode(Hunt.self, from: data).collected, ["s"])
  }
}
