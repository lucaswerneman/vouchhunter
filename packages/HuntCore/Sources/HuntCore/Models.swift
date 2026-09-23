import Foundation

public struct Stop: Codable, Identifiable, Sendable {
    public let id: String
    public let campaign_id: String
    public let name: String
    public let lat: Double
    public let lon: Double
    public let radius: Int
}
public struct Campaign: Codable, Identifiable, Sendable {
    public let id: String
    public let title: String
    public let description: String
    public let reward: String
    public let terms: String
    public let venue: String
    public let brand: String
    public let target: Int
    public let capacity: Int
    public let starts: TimeInterval
    public let ends: TimeInterval
    public let voucher_days: Int
    public let stops: [Stop]
}
public struct Voucher: Codable, Identifiable, Sendable {
    public let id: String
    public let code: String
    public let expires: TimeInterval
    public let redeemed: TimeInterval?
    public let title: String?
    public let reward: String?
    public let venue: String?
    public let terms: String?
    public var isValid: Bool { redeemed == nil && expires > Date().timeIntervalSince1970 }
}
public struct Hunt: Codable, Sendable {
    public let id: String
    public let expires: TimeInterval
    public let completed: TimeInterval?
    public let collected: [String]
    public let voucher: Voucher?
}
public struct CampaignList: Codable, Sendable { public let campaigns: [Campaign] }
public struct VoucherList: Codable, Sendable { public let vouchers: [Voucher] }
public struct HuntEnvelope: Codable, Sendable { public let hunt: Hunt? }
public struct LoginResponse: Codable, Sendable { public let token: String }
public struct User: Codable, Sendable { public let id: String; public let name: String; public let email: String }
public enum Geo {
    public static func distance(lat1: Double, lon1: Double, lat2: Double, lon2: Double) -> Double {
        let p1 = lat1 * .pi / 180, p2 = lat2 * .pi / 180
        let a = pow(sin((p2-p1)/2),2) + cos(p1)*cos(p2)*pow(sin((lon2-lon1)*Double.pi/360),2)
        return 6_371_000 * 2 * asin(sqrt(min(1,max(0,a))))
    }
}
