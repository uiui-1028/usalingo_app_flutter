import Foundation

/// 正式公開済みの法務文書の台帳。表示内容をテストから確かめられるよう internal にしている。
struct LegalDocument: Identifiable {
    enum Kind: CaseIterable {
        case terms
        case privacy
        case licenses
        case credits

        var title: String {
            switch self {
            case .terms: "利用規約"
            case .privacy: "プライバシー"
            case .licenses: "ライセンス"
            case .credits: "クレジット"
            }
        }
    }

    let id = UUID()
    let kind: Kind
    let title: String
    let version: String
    let effectiveDate: String
    let url: URL

    // Add only legal-approved documents here. Drafts and unverified asset records stay hidden.
    // 正本は docs/legal/published/ にある。版と施行日を上げたら、ここも合わせる。
    // ライセンスは外部URLではなくアプリ内画面なので、ここには入れない。
    //
    // 版と施行日は文書ごとに持つ。3つまとめて1つの定数にすると、1文書だけ改訂したときに
    // 残りの2つまで新しい版として表示してしまう。実際、クレジットを第1.1版へ上げた際に
    // これが起きた。
    static let publishedDocuments: [LegalDocument] = [
        published(.terms, path: "terms", version: "第1.0版", effectiveDate: "2026年9月1日"),
        published(.privacy, path: "privacy", version: "第1.1版", effectiveDate: "2026年9月17日"),
        published(.credits, path: "credits", version: "第1.1版", effectiveDate: "2026年9月4日")
    ].compactMap { $0 }

    private static let publishedBaseURL = "https://usalingo-app.vercel.app"

    /// URLを組み立てられなかった行は一覧から落とす。落ちた行は「公開準備中」に戻るだけで、
    /// 壊れたリンクをタップさせるより安全。
    private static func published(
        _ kind: Kind,
        path: String,
        version: String,
        effectiveDate: String
    ) -> LegalDocument? {
        guard let url = URL(string: "\(publishedBaseURL)/\(path)") else { return nil }
        return LegalDocument(
            kind: kind,
            title: kind.title,
            version: version,
            effectiveDate: effectiveDate,
            url: url
        )
    }
}

/// バンドルへ同梱したライセンス一覧を読む。
///
/// 一覧は `scripts/generate-licenses.sh` の生成物であり、依存がゼロのあいだは存在しない。
/// それが正しい状態なので、見つからないことを異常として扱わない。
enum OpenSourceLicenseCatalog {
    static func load(bundle: Bundle = .main) -> String? {
        guard let url = bundle.url(
            forResource: "Acknowledgements",
            withExtension: "md",
            subdirectory: "Licenses"
        ) else {
            return nil
        }
        return try? String(contentsOf: url, encoding: .utf8)
    }
}
