import Foundation

enum Team: String, Codable, CaseIterable, Equatable {
    case teamA
    case teamB

    var displayName: String {
        switch self {
        case .teamA:
            return "Team A"
        case .teamB:
            return "Team B"
        }
    }
}

enum MatchPhase: Equatable {
    case playing
    case awaitingConfirmation
    case completed
}

struct GameResult: Codable, Equatable {
    let scoreA: Int
    let scoreB: Int

    var winner: Team {
        scoreA > scoreB ? .teamA : .teamB
    }

    var displayScore: String {
        "\(scoreA)-\(scoreB)"
    }
}

struct MatchRecord: Identifiable, Codable, Equatable {
    let id: UUID
    let playedAt: Date
    let games: [GameResult]
    let winner: Team
}

protocol MatchHistoryPersisting {
    func load() -> [MatchRecord]
    func save(_ records: [MatchRecord])
}

final class UserDefaultsMatchHistoryPersistence: MatchHistoryPersisting {
    private let defaults: UserDefaults
    private let key: String

    init(
        defaults: UserDefaults = .standard,
        key: String = "scoreTracker.matchHistory"
    ) {
        self.defaults = defaults
        self.key = key
    }

    func load() -> [MatchRecord] {
        guard
            let data = defaults.data(forKey: key),
            let records = try? JSONDecoder().decode(
                [MatchRecord].self,
                from: data
            )
        else {
            return []
        }

        return records
    }

    func save(_ records: [MatchRecord]) {
        guard let data = try? JSONEncoder().encode(records) else {
            return
        }

        defaults.set(data, forKey: key)
    }
}

private struct GameSnapshot {
    let scoreA: Int
    let scoreB: Int
    let gameNum: Int
    let completedGames: [GameResult]
    let gamesWonA: Int
    let gamesWonB: Int
    let matchPhase: MatchPhase
}

struct GameState {
    private(set) var scoreA = 0
    private(set) var scoreB = 0
    private(set) var gameNum = 1
    private(set) var completedGames: [GameResult] = []
    private(set) var gamesWonA = 0
    private(set) var gamesWonB = 0
    private(set) var matchPhase: MatchPhase = .playing
    private(set) var matchHistory: [MatchRecord]

    private var undoHistory: [GameSnapshot] = []
    private let matchHistoryLimit: Int
    private let persistence: any MatchHistoryPersisting

    init(
        matchHistoryLimit: Int = 10,
        persistence: any MatchHistoryPersisting =
            UserDefaultsMatchHistoryPersistence()
    ) {
        self.matchHistoryLimit = max(1, matchHistoryLimit)
        self.persistence = persistence
        self.matchHistory = Array(
            persistence.load().suffix(max(1, matchHistoryLimit))
        )
    }

    var isGameOver: Bool {
        let leadingScore = max(scoreA, scoreB)
        return leadingScore == 30 ||
            (leadingScore >= 21 && abs(scoreA - scoreB) >= 2)
    }

    var isMatchOver: Bool {
        gamesWonA == 2 || gamesWonB == 2
    }

    var matchWinner: Team? {
        if gamesWonA == 2 {
            return .teamA
        }

        if gamesWonB == 2 {
            return .teamB
        }

        return nil
    }

    var canUndo: Bool {
        !undoHistory.isEmpty && matchPhase != .completed
    }

    var hasActiveMatchProgress: Bool {
        scoreA > 0 || scoreB > 0 || !completedGames.isEmpty
    }

    mutating func pointWon(by winningTeam: Team) {
        guard matchPhase == .playing else {
            return
        }

        saveSnapshot()
        incrementScore(for: winningTeam)

        if isGameOver {
            finishGame()
        }
    }

    mutating func undoLastPoint() {
        guard let previous = undoHistory.popLast() else {
            return
        }

        scoreA = previous.scoreA
        scoreB = previous.scoreB
        gameNum = previous.gameNum
        completedGames = previous.completedGames
        gamesWonA = previous.gamesWonA
        gamesWonB = previous.gamesWonB
        matchPhase = previous.matchPhase
    }

    @discardableResult
    mutating func confirmCompletedMatch(
        at date: Date = Date(),
        id: UUID = UUID()
    ) -> MatchRecord? {
        guard
            matchPhase == .awaitingConfirmation,
            let winner = matchWinner
        else {
            return nil
        }

        let record = MatchRecord(
            id: id,
            playedAt: date,
            games: completedGames,
            winner: winner
        )

        matchHistory.append(record)
        trimMatchHistory()
        persistence.save(matchHistory)

        undoHistory.removeAll()
        matchPhase = .completed
        return record
    }

    mutating func startNewMatch() {
        scoreA = 0
        scoreB = 0
        gameNum = 1
        completedGames = []
        gamesWonA = 0
        gamesWonB = 0
        undoHistory = []
        matchPhase = .playing
    }

    mutating func discardCurrentMatch() {
        startNewMatch()
    }

    mutating func deleteHistoryRecord(id: UUID) {
        matchHistory.removeAll { $0.id == id }
        persistence.save(matchHistory)
    }

    mutating func clearMatchHistory() {
        matchHistory.removeAll()
        persistence.save(matchHistory)
    }

    private mutating func saveSnapshot() {
        undoHistory.append(
            GameSnapshot(
                scoreA: scoreA,
                scoreB: scoreB,
                gameNum: gameNum,
                completedGames: completedGames,
                gamesWonA: gamesWonA,
                gamesWonB: gamesWonB,
                matchPhase: matchPhase
            )
        )
    }

    private mutating func incrementScore(for team: Team) {
        switch team {
        case .teamA:
            scoreA += 1
        case .teamB:
            scoreB += 1
        }
    }

    private mutating func finishGame() {
        let result = GameResult(scoreA: scoreA, scoreB: scoreB)
        completedGames.append(result)

        switch result.winner {
        case .teamA:
            gamesWonA += 1
        case .teamB:
            gamesWonB += 1
        }

        scoreA = 0
        scoreB = 0

        if isMatchOver {
            matchPhase = .awaitingConfirmation
        } else {
            gameNum += 1
        }
    }

    private mutating func trimMatchHistory() {
        let overflow = matchHistory.count - matchHistoryLimit
        if overflow > 0 {
            matchHistory.removeFirst(overflow)
        }
    }
}
