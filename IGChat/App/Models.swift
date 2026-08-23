import Foundation

struct ChatElement: Identifiable, Equatable {
    enum Style: Equatable {
        case date
        case sent
        case received
    }

    var id: UUID = UUID()
    var style: Style
    var text: String
    var heartHint: Bool = false
}

struct IGProfile {
    var username: String = "gentlewomanstore"
    var isVerified: Bool = false
    var followers: String = "482K"
    var posts: String = "11K"
    var statusLine: String = "You don't follow each other on Instagram"

    var initials: String {
        let trimmed = username.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "?" }
        return String(trimmed.prefix(2)).uppercased()
    }
}

enum IGSeed {
    static func defaultElements() -> [ChatElement] {
        [
            ChatElement(style: .date, text: "JUL 16 AT 1:11 PM"),
            ChatElement(style: .sent, text: "Tiktokshop link"),
            ChatElement(
                style: .received,
                text: "สินค้า GENTLEWOMAN มีช่องทางการจัดจำหน่ายดังนี้\n\n1. ทางร้าน GENTLEWOMAN\n2. เว็บไซต์ www.gentlewomanonline.com เท่านั้นค่ะ\n3. TIK TOK shop\nhttps://vt.tiktok.com/ZMBLwP2Q6/?page=TikTokShop\n4. GENTLEWOMANSTORE บนลาซาด้า\nhttps://s.lazada.co.th/s.ZWa2tb\n\nทางแบรนด์ไม่มีร้านค้าใน Shopee นะค้า",
                heartHint: true
            )
        ]
    }
}
