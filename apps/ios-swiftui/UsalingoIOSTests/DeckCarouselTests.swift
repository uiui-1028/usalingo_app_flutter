import XCTest
@testable import UsalingoIOS

/// カルーセルの並び方と、デッキの並び順を覚えておく仕組みを確かめる。
final class DeckCarouselLayoutTests: XCTestCase {
    private let layout = DeckCarouselLayout(bandHeight: 64, expandedHeight: 240, spacing: 10)

    /// 中央の枠だけが広がり、画面の中央に来る。
    func testCenterSlotIsExpandedAndCentered() {
        XCTAssertEqual(layout.height(offset: 0), 240, accuracy: 0.001)
        XCTAssertEqual(layout.y(offset: 0), 0, accuracy: 0.001)
        XCTAssertEqual(layout.height(offset: 1), 64, accuracy: 0.001)
        XCTAssertEqual(layout.height(offset: -2), 64, accuracy: 0.001)
    }

    /// 動いている途中でも、隣どうしは重ならず、同じ間隔だけ離れる。
    func testSlotsNeverOverlapWhileMoving() {
        for step in -30...30 {
            let offset = CGFloat(step) / 10
            let upper = layout.y(offset: offset) + layout.height(offset: offset) / 2
            let lower = layout.y(offset: offset + 1) - layout.height(offset: offset + 1) / 2
            XCTAssertEqual(lower - upper, 10, accuracy: 0.001, "offset \(offset)")
        }
    }

    /// 中央とその隣は、指の移動にそのまま付いてくる。1枠ぶんで `stride` だけ動く。
    func testCenterMovesExactlyWithTheFinger() {
        for step in -10...10 {
            let offset = CGFloat(step) / 10
            XCTAssertEqual(layout.y(offset: offset), offset * layout.stride, accuracy: 0.001)
        }
        XCTAssertEqual(layout.stride, 162, accuracy: 0.001)
    }

    /// 両端に空き枠を1つずつ置く。デッキが無いときは空き枠1つだけ。
    func testEmptySlotsSitAtBothEnds() {
        let decks = [makeDeck(1), makeDeck(2)]

        XCTAssertEqual(DeckSlot.slots(for: decks), [.empty(.top), .deck(decks[0]), .deck(decks[1]), .empty(.bottom)])
        XCTAssertEqual(DeckSlot.slots(for: []), [.empty(.bottom)])
    }
}

final class DeckOrderStoreTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suiteName: String!

    override func setUp() {
        super.setUp()
        suiteName = "DeckOrderStoreTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil
        super.tearDown()
    }

    /// 覚えた順が無ければ、渡された順のまま。
    func testKeepsGivenOrderAtFirst() {
        let store = DeckOrderStore(accountId: "a", defaults: defaults)
        XCTAssertEqual(store.arranged([makeDeck(3), makeDeck(1)]).map(\.id), [3, 1])
    }

    /// 消えたデッキは詰め、覚えていないデッキは末尾へ足す。
    func testDeletedDecksCloseTheGapAndNewOnesGoLast() {
        let store = DeckOrderStore(accountId: "a", defaults: defaults)
        _ = store.arranged([makeDeck(1), makeDeck(2), makeDeck(3)])

        XCTAssertEqual(store.arranged([makeDeck(9), makeDeck(3), makeDeck(1)]).map(\.id), [1, 3, 9])
    }

    /// 利用者が違えば、並び順も最後に選んだデッキも混ざらない。
    func testEachAccountKeepsItsOwnOrder() {
        let first = DeckOrderStore(accountId: "a", defaults: defaults)
        let second = DeckOrderStore(accountId: "b", defaults: defaults)
        _ = first.arranged([makeDeck(2), makeDeck(1)])
        first.selectedDeckId = 2

        XCTAssertEqual(second.arranged([makeDeck(1), makeDeck(2), makeDeck(3)]).map(\.id), [1, 2, 3])
        XCTAssertNil(second.selectedDeckId)
        XCTAssertEqual(first.arranged([makeDeck(1), makeDeck(2)]).map(\.id), [2, 1])
        XCTAssertEqual(first.selectedDeckId, 2)
    }

    func testRemoveAllForgetsOnlyThatAccount() {
        let first = DeckOrderStore(accountId: "a", defaults: defaults)
        let second = DeckOrderStore(accountId: "b", defaults: defaults)
        first.selectedDeckId = 1
        second.selectedDeckId = 2

        first.removeAll()

        XCTAssertNil(first.selectedDeckId)
        XCTAssertEqual(second.selectedDeckId, 2)
    }

    func testRemembersSelectedDeck() {
        let store = DeckOrderStore(accountId: "a", defaults: defaults)
        XCTAssertNil(store.selectedDeckId)

        store.selectedDeckId = -5
        XCTAssertEqual(DeckOrderStore(accountId: "a", defaults: defaults).selectedDeckId, -5)
    }
}

private func makeDeck(_ id: Int) -> Deck {
    Deck(id: id, deckName: "deck\(id)", description: nil)
}

final class DeckCoverStoreTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suiteName: String!

    override func setUp() {
        super.setUp()
        suiteName = "DeckCoverStoreTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil
        super.tearDown()
    }

    /// 一度選んだ表紙は、読み直しても同じ1枚のままにする。
    func testSelectedCoverStaysTheSameOnLaterLoads() {
        let cards = (1...20).map { makeCard(id: $0, imagePath: "images/\($0).png") }
        let first = DeckCoverStore(defaults: defaults)
            .coverURL(deckId: 3, cards: cards)
        XCTAssertNotNil(first)

        // アプリを開き直した想定で、別のインスタンスから同じ保存先を読む。
        for _ in 0..<10 {
            let again = DeckCoverStore(defaults: defaults)
                .coverURL(deckId: 3, cards: cards)
            XCTAssertEqual(again, first)
        }
    }

    /// 覚えていたカードがデッキから消えたら、残っているカードから選び直す。
    func testCoverIsPickedAgainWhenTheSavedCardIsGone() {
        let cards = [makeCard(id: 1, imagePath: "images/1.png")]
        let store = DeckCoverStore(defaults: defaults)
        XCTAssertEqual(store.coverURL(deckId: 3, cards: cards)?.lastPathComponent, "1.png")

        let replaced = [makeCard(id: 2, imagePath: "images/2.png")]
        XCTAssertEqual(store.coverURL(deckId: 3, cards: replaced)?.lastPathComponent, "2.png")
    }

    /// 絵の無いカードは表紙に選ばない。1枚も無ければ仮表紙にまかせる。
    func testDeckWithoutImagesHasNoCover() {
        let cards = [makeCard(id: 1, imagePath: nil), makeCard(id: 2, imagePath: nil)]
        let store = DeckCoverStore(defaults: defaults)

        XCTAssertNil(store.coverURL(deckId: 3, cards: cards))
    }

    func testOnlyCardsWithImagesArePicked() {
        let cards = [
            makeCard(id: 1, imagePath: nil),
            makeCard(id: 2, imagePath: "images/2.png"),
            makeCard(id: 3, imagePath: nil)
        ]
        let store = DeckCoverStore(defaults: defaults)

        XCTAssertEqual(store.coverURL(deckId: 3, cards: cards)?.lastPathComponent, "2.png")
    }

    /// 利用者が変わって同じデッキ番号が別のデッキを指しても、無い画像は出さない。
    func testCoverIsPickedAgainWhenTheDeckNumberPointsAtAnotherDeck() {
        let cards = [makeCard(id: 1, imagePath: "images/1.png")]
        _ = DeckCoverStore(defaults: defaults).coverURL(deckId: 3, cards: cards)

        let otherCards = [makeCard(id: 9, imagePath: "images/9.png")]
        let other = DeckCoverStore(defaults: defaults)
            .coverURL(deckId: 3, cards: otherCards)

        XCTAssertEqual(other?.lastPathComponent, "9.png")
    }

    private func makeCard(id: Int, imagePath: String?) -> WordCard {
        WordCard(
            id: id,
            text: "word\(id)",
            meaning: "いみ\(id)",
            partOfSpeech: nil,
            sentenceEnglish: nil,
            sentenceJapanese: nil,
            imageAssetPath: imagePath,
            audioAssetPath: nil,
            tags: [],
            learningStatus: nil,
            learning: nil
        )
    }
}

final class DeckTreeTests: XCTestCase {
    private let decks = (1...4).map { Deck(id: $0, deckName: "D\($0)", description: nil) }

    func testKeepsSavedOrderAndPutsFolderChildrenInsideTheFolder() {
        let folder = LocalDeckFolder(id: 7, name: "F", deckIds: [3, 1])
        let tree = DeckTree.build(decks: decks, layout: [.deck(2), .folder(7), .deck(4)], folders: [folder])
        XCTAssertEqual(tree, [.deck(decks[1]), .folder(folder, decks: [decks[2], decks[0]]), .deck(decks[3])])
    }

    func testDeckListedTwiceStaysInTheFolderAndNewDecksGoLast() {
        let folder = LocalDeckFolder(id: 7, name: "F", deckIds: [1])
        let tree = DeckTree.build(decks: decks, layout: [.deck(1), .folder(7)], folders: [folder])
        XCTAssertEqual(tree.map(\.layoutEntry), [.folder(7), .deck(2), .deck(3), .deck(4)])
    }

    func testRemovedDecksDropOutOfFoldersButEmptyFoldersStay() {
        let folders = [LocalDeckFolder(id: 7, name: "F", deckIds: [9, 2]), LocalDeckFolder(id: 8, name: "G", deckIds: [])]
        let tree = DeckTree.build(decks: decks, layout: [.folder(7)], folders: folders)
        XCTAssertEqual(DeckTree.folders(in: tree, keepingEmptyFrom: folders).map(\.deckIds), [[2], []])
        XCTAssertEqual(tree.map(\.layoutEntry), [.folder(7), .folder(8), .deck(1), .deck(3), .deck(4)])
    }
}

final class DeckDropTests: XCTestCase {
    /// 並び: デッキ1、フォルダ7（開いていて中にデッキ2・3）、デッキ4。
    private let rows: [DeckRow] = [
        .deck(1, folder: nil),
        .folder(7),
        .deck(2, folder: 7),
        .deck(3, folder: 7),
        .deck(4, folder: nil)
    ]

    func testDroppingADeckOntoAnotherDeckMakesAFolder() {
        XCTAssertEqual(DeckDrop.action(rows: rows, dragged: 0, target: .row(4, .onto)), .makeFolder(deckId: 1, withDeckId: 4))
    }

    func testDroppingADeckOntoAFolderOrItsDeckPutsItInside() {
        XCTAssertEqual(DeckDrop.action(rows: rows, dragged: 4, target: .row(1, .onto)),
                       .moveIntoFolder(deckId: 4, folderId: 7, index: nil))
        XCTAssertEqual(DeckDrop.action(rows: rows, dragged: 4, target: .row(2, .onto)),
                       .moveIntoFolder(deckId: 4, folderId: 7, index: 1))
    }

    func testDroppingBetweenTopLevelCardsReorders() {
        XCTAssertEqual(DeckDrop.action(rows: rows, dragged: 4, target: .row(0, .before)), .moveToTop(.deck(4), index: 0))
        XCTAssertEqual(DeckDrop.action(rows: rows, dragged: 0, target: .row(4, .after)), .moveToTop(.deck(1), index: 2))
        XCTAssertEqual(DeckDrop.action(rows: rows, dragged: 0, target: .end), .moveToTop(.deck(1), index: 2))
        XCTAssertEqual(DeckDrop.action(rows: rows, dragged: 4, target: .start), .moveToTop(.deck(4), index: 0))
    }

    func testReorderingInsideAnOpenFolder() {
        XCTAssertEqual(DeckDrop.action(rows: rows, dragged: 3, target: .row(2, .before)),
                       .moveIntoFolder(deckId: 3, folderId: 7, index: 0))
        XCTAssertEqual(DeckDrop.action(rows: rows, dragged: 0, target: .row(1, .after)),
                       .moveIntoFolder(deckId: 1, folderId: 7, index: 0))
    }

    func testDraggingADeckOutOfItsFolder() {
        XCTAssertEqual(DeckDrop.action(rows: rows, dragged: 2, target: .row(0, .before)), .moveToTop(.deck(2), index: 0))
        XCTAssertEqual(DeckDrop.action(rows: rows, dragged: 2, target: .row(4, .after)), .moveToTop(.deck(2), index: 3))
    }

    func testFoldersCannotGoInsideAnything() {
        XCTAssertEqual(DeckDrop.action(rows: rows, dragged: 1, target: .row(0, .onto)), .moveToTop(.folder(7), index: 1))
        XCTAssertEqual(DeckDrop.action(rows: rows, dragged: 1, target: .row(4, .after)), .moveToTop(.folder(7), index: 2))
    }

    /// 開いたフォルダの中から運んだデッキは、閉じた並びの最後に足して同じ決まりで扱う。
    func testDeckDraggedOutOfAFolderTileUsesTheSameRules() {
        let closed: [DeckRow] = [.deck(1, folder: nil), .folder(7), .deck(4, folder: nil), .deck(2, folder: 7)]
        XCTAssertEqual(DeckDrop.action(rows: closed, dragged: 3, target: .row(0, .before)), .moveToTop(.deck(2), index: 0))
        XCTAssertEqual(DeckDrop.action(rows: closed, dragged: 3, target: .end), .moveToTop(.deck(2), index: 3))
        XCTAssertEqual(DeckDrop.action(rows: closed, dragged: 3, target: .row(2, .onto)), .makeFolder(deckId: 2, withDeckId: 4))
        XCTAssertEqual(DeckDrop.action(rows: closed, dragged: 3, target: .row(1, .onto)),
                       .moveIntoFolder(deckId: 2, folderId: 7, index: nil))
    }

    func testDroppingOnItselfDoesNothing() {
        XCTAssertNil(DeckDrop.action(rows: rows, dragged: 0, target: .row(0, .onto)))
    }
}


/// 長押しメニューのボタンの並びと、指で選ぶ判定を確かめる。
final class DeckRadialMenuLayoutTests: XCTestCase {
    private let card = CGRect(x: 0, y: 200, width: 400, height: 400)

    /// 画面の下の方で左寄りを押すと、上へ開き、カードの中央の側（右）へ傾く。
    func testOpensUpAndTowardCardCenter() {
        let layout = DeckRadialMenuLayout(anchor: CGPoint(x: 60, y: 500), cardFrame: card, count: 2)
        for center in layout.centers {
            XCTAssertLessThan(center.y, 500)
            XCTAssertGreaterThan(center.x, 60)
        }
        XCTAssertLessThan(layout.centers[0].x, layout.centers[1].x)
    }

    /// 画面の上の方を押すと、下へ開く。
    func testOpensDownNearTheTop() {
        let layout = DeckRadialMenuLayout(anchor: CGPoint(x: 340, y: 120), cardFrame: card, count: 2)
        for center in layout.centers {
            XCTAssertGreaterThan(center.y, 120)
            XCTAssertLessThan(center.x, 340)
        }
    }

    /// ボタンの上へ指を動かすとそのボタンを選ぶ。動かし始めや遠すぎる場所では選ばない。
    func testSelectsTheButtonUnderTheFinger() {
        let anchor = CGPoint(x: 200, y: 500)
        let layout = DeckRadialMenuLayout(anchor: anchor, cardFrame: card, count: 2)
        for (index, center) in layout.centers.enumerated() {
            XCTAssertEqual(layout.item(at: center), index)
            XCTAssertTrue(layout.keepsMenu(center))
        }
        XCTAssertNil(layout.item(at: CGPoint(x: anchor.x, y: anchor.y - 10)))
        XCTAssertNil(layout.item(at: CGPoint(x: anchor.x, y: anchor.y - 400)))
    }

    /// ボタンと反対の向きへはっきり動かした指は、メニューではなくデッキを運ぶ操作に譲る。
    func testMovingAwayFromTheButtonsGivesWayToReordering() {
        let anchor = CGPoint(x: 200, y: 500)
        let layout = DeckRadialMenuLayout(anchor: anchor, cardFrame: card, count: 2)
        let below = CGPoint(x: anchor.x, y: anchor.y + 30)
        XCTAssertFalse(layout.keepsMenu(below))
        XCTAssertNil(layout.item(at: below))
    }

    /// 動かし始めの小さな揺れや、ボタンからずれた向きでも、ボタンの側なら運ぶ操作に切り替えない。
    func testWobblingOnTheWayToAButtonKeepsTheMenu() {
        let anchor = CGPoint(x: 200, y: 500)
        let layout = DeckRadialMenuLayout(anchor: anchor, cardFrame: card, count: 2)
        XCTAssertTrue(layout.keepsMenu(CGPoint(x: anchor.x, y: anchor.y + 12)))
        // 2つのボタンの外側へ 30 度ずれた向き。どのボタンも選ばないが、メニューは続ける。
        let outer = (layout.angles.last! + 30) * .pi / 180
        let wobble = CGPoint(x: anchor.x + 60 * cos(outer), y: anchor.y + 60 * sin(outer))
        XCTAssertNil(layout.item(at: wobble))
        XCTAssertTrue(layout.keepsMenu(wobble))
    }
}
