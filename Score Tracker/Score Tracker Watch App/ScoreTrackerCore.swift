// Imports Foundation types used here, including Date, UUID, UserDefaults, and JSON encoders.
import Foundation

enum NumGames: Int, CaseIterable, Identifiable {
    case bo1 = 1
    case bo3 = 3
    case bo5 = 5
    
    var id: Int {self.rawValue}
    var gamesNeededToWin: Int {(rawValue / 2)}
}

enum Team: String, Codable, CaseIterable, Equatable {
    case teamA
    case teamB

    var displayName: String {
        switch self {
        case .teamA:
            return "Your Team"
        case .teamB:
            // Returns the display text for Team B.
            return "Opponent Team"
        }
    }
}

// Match Lifecycle
enum MatchPhase: Equatable { // ...exactly what you think it means
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

// Defines the interface that any match-history storage implementation must provide.
protocol MatchHistoryPersisting {
    // Requires conforming storage types to load and return all saved match records.
    func load() -> [MatchRecord]
    // Requires conforming storage types to save the supplied record array; `_` omits the external argument label.
    func save(_ records: [MatchRecord])
}

// Declares a non-subclassable reference type that stores match history in UserDefaults.
final class UserDefaultsMatchHistoryPersistence: MatchHistoryPersisting {
    // Stores the UserDefaults database used by this persistence object.
    private let defaults: UserDefaults
    // Stores the dictionary key under which encoded history data is saved.
    private let key: String

    init(
        // Declares an injectable UserDefaults parameter whose default is the app’s standard database.
        defaults: UserDefaults = .standard,
        // Declares an injectable storage-key parameter with the app’s normal key as its default.
        key: String = "scoreTracker.matchHistory"
    ) {
        // Assigns the initializer parameter to the instance property; `self` distinguishes the property from the parameter.
        self.defaults = defaults
        // Stores the supplied persistence key on this instance.
        self.key = key
    }

    // Requires conforming storage types to load and return all saved match records.
    func load() -> [MatchRecord] {
        // Begins a guard statement that requires all following optional operations to succeed.
        guard
            // Attempts to read previously encoded Data from UserDefaults using the storage key.
            let data = defaults.data(forKey: key),
            // Attempts JSON decoding and converts any thrown error into nil with `try?`.
            let records = try? JSONDecoder().decode(
                // Passes the MatchRecord-array type itself so JSONDecoder knows the desired output type.
                [MatchRecord].self,
                // Supplies the stored bytes that JSONDecoder should decode.
                from: data
            )
        else {
            // Returns an empty array when there is no data or decoding fails.
            return []
        }

        // Returns the successfully decoded match records.
        return records
    }

    // Requires conforming storage types to save the supplied record array; `_` omits the external argument label.
    func save(_ records: [MatchRecord]) {
        // Attempts to encode the records as JSON Data and enters the failure branch if encoding fails.
        guard let data = try? JSONEncoder().encode(records) else {
            // Exits the current function early without producing a value.
            return
        }

        // Writes the encoded bytes into UserDefaults under the configured key.
        defaults.set(data, forKey: key)
    }
}

// Declares a file-private value that captures all mutable match fields needed for Undo.
private struct GameSnapshot {
    // Stores Team A’s score as an immutable integer.
    let scoreA: Int
    // Stores Team B’s score as an immutable integer.
    let scoreB: Int
    // Stores the current game number for later restoration by Undo.
    let gameNum: Int
    // Stores all completed games as part of an Undo snapshot.
    let completedGames: [GameResult]
    // Stores Team A’s game-win count.
    let gamesWonA: Int
    // Stores Team B’s game-win count.
    let gamesWonB: Int
    // Stores the match lifecycle phase.
    let matchPhase: MatchPhase
}

// Declares the central value type that owns scoring rules, active-match state, Undo, and history.
struct GameState {
    // Stores Team A’s live score; outside code may read it but only GameState may change it directly.
    private(set) var scoreA = 0
    // Stores Team B’s live score with a private setter.
    private(set) var scoreB = 0
    private(set) var gameNum = 1
    private(set) var matchFormat: NumGames = .bo3
    // Stores completed game results while preventing outside code from mutating the array directly.
    private(set) var completedGames: [GameResult] = []
    private(set) var gamesWonA = 0
    private(set) var gamesWonB = 0
    // Stores the current lifecycle phase, initially allowing scoring.
    private(set) var matchPhase: MatchPhase = .playing
    // Stores saved match records with read-only access outside GameState.
    private(set) var matchHistory: [MatchRecord]

    // Stores snapshots in stack order so the most recent point can be undone first.
    private var undoHistory: [GameSnapshot] = []
    // Stores the validated maximum number of history records.
    private let matchHistoryLimit: Int
    // Stores an object conforming to the persistence protocol; `any` denotes an existential value.
    private let persistence: any MatchHistoryPersisting

    // Begins an initializer that constructs a new instance.
    init(
        // Declares the maximum number of history records to retain, defaulting to ten.
        matchHistoryLimit: Int = 10,
        // Declares injectable storage through the protocol type, allowing tests or alternatives.
        persistence: any MatchHistoryPersisting =
            // Creates the default UserDefaults-backed persistence implementation.
            UserDefaultsMatchHistoryPersistence()
    // Begins the scope introduced by this declaration or control-flow statement.
    ) {
        // Clamps the history limit to at least one before storing it.
        self.matchHistoryLimit = max(1, matchHistoryLimit)
        // Stores the injected persistence implementation.
        self.persistence = persistence
        // Creates the initial in-memory history array from persisted records.
        self.matchHistory = Array(
            // Loads history and keeps only the newest records up to the configured limit.
            persistence.load().suffix(max(1, matchHistoryLimit))
        )
    }

    // Declares a computed Boolean that applies badminton’s game-winning rules.
    var isGameOver: Bool {
        // Finds the greater of the two current scores.
        let leadingScore = max(scoreA, scoreB)
        // Ends a game at the 30-point cap or when a team has at least 21 points and leads by two.
        return leadingScore == 30 ||
            // Implements the normal win-by-two condition after reaching 21 points.
            (leadingScore >= 21 && abs(scoreA - scoreB) >= 2)
    }

    // Declares a computed Boolean for a best-of-three match.
    var isMatchOver: Bool {
        // Returns true as soon as either team has won two games.
        gamesWonA == matchFormat.gamesNeededToWin || gamesWonB == matchFormat.gamesNeededToWin
    }

    // Declares an optional computed winner because an unfinished match has no winner.
    var matchWinner: Team? {
        // Checks whether Team A has reached the two-game winning threshold.
        if gamesWonA == matchFormat.gamesNeededToWin {
            // Returns Team A as the match winner.
            return .teamA
        }

        // Checks whether Team B has reached the two-game winning threshold.
        if gamesWonB == matchFormat.gamesNeededToWin {
            // Returns Team B as the match winner.
            return .teamB
        }

        // Returns no value because the match has not produced a winner.
        return nil
    }

    // Declares whether there is a saved snapshot and the match has not been finalized.
    var canUndo: Bool {
        // Requires at least one snapshot and disallows Undo after completion.
        !undoHistory.isEmpty && matchPhase != .completed
    }

    // Declares whether the current match contains any points or completed games.
    var hasActiveMatchProgress: Bool {
        // Returns true when either live score is nonzero or a game has already finished.
        scoreA > 0 || scoreB > 0 || !completedGames.isEmpty
    }

    // Declares a method that may change this value-type instance when a team scores.
    mutating func pointWon(by winningTeam: Team) {
        // Rejects scoring unless the match is actively in the playing phase.
        guard matchPhase == .playing else {
            // Exits the current function early without producing a value.
            return
        }

        // Captures the current state before changing it, enabling Undo.
        saveSnapshot()
        // Adds one point to the team supplied by the caller.
        incrementScore(for: winningTeam)

        // Checks the scoring rules after the point to see whether the current game ended.
        if isGameOver {
            // Records the completed game and advances or completes the match.
            finishGame()
        }
    }

    // Declares the operation that restores the most recently saved snapshot.
    mutating func undoLastPoint() {
        // Removes and unwraps the newest snapshot; exits if the history stack is empty.
        guard let previous = undoHistory.popLast() else {
            // Exits the current function early without producing a value.
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

    // Allows callers to ignore this method’s returned record without receiving a compiler warning.
    @discardableResult
    // Declares the operation that validates, saves, and finalizes a completed match.
    mutating func confirmCompletedMatch(
        // Accepts a save date, defaulting to the current time while remaining injectable for tests.
        at date: Date = Date(),
        // Accepts a record identifier, defaulting to a new UUID while remaining injectable for tests.
        id: UUID = UUID()
    // Declares an optional return because confirmation can fail when the match is not ready.
    ) -> MatchRecord? {
        // Begins a guard statement that requires all following optional operations to succeed.
        guard
            // Requires the match to be waiting for confirmation.
            matchPhase == .awaitingConfirmation,
            // Safely unwraps the computed winner as another confirmation requirement.
            let winner = matchWinner
        // Begins the guard’s failure branch, which must exit the current scope.
        else {
            // Returns no value because the match has not produced a winner.
            return nil
        }

        // Constructs the persistable record for this completed match.
        let record = MatchRecord(
            id: id,
            playedAt: date,
            games: completedGames,
            winner: winner
        )

        // Adds the new record to the end of in-memory history.
        matchHistory.append(record)
        // Removes oldest records if history now exceeds its configured limit.
        trimMatchHistory()
        // Writes the updated complete history through the persistence abstraction.
        persistence.save(matchHistory)

        // Clears obsolete Undo snapshots after finalizing the match.
        undoHistory.removeAll()
        // Marks the active match as finalized so it no longer accepts Undo or scoring.
        matchPhase = .completed
        // Returns the record that was successfully created and saved.
        return record
    }

    // Declares the reset operation used to begin a completely fresh match.
    mutating func startNewMatch(format: NumGames) {
        scoreA = 0
        scoreB = 0
        gameNum = 1
        completedGames = []
        gamesWonA = 0
        gamesWonB = 0
        undoHistory = []
        matchPhase = .playing
        
        matchFormat = format
    }

    // Declares a convenience operation for abandoning active progress.
    mutating func discardCurrentMatch() {
        // Reuses the full reset logic rather than duplicating it.
        startNewMatch(format: matchFormat)
    }

    // Declares an operation that deletes one saved match by identifier.
    mutating func deleteHistoryRecord(id: UUID) {
        // Removes every record whose identifier matches the requested identifier.
        matchHistory.removeAll { $0.id == id }
        // Writes the updated complete history through the persistence abstraction.
        persistence.save(matchHistory)
    }

    // Declares an operation that deletes the entire saved history.
    mutating func clearMatchHistory() {
        // Empties the in-memory match-history array.
        matchHistory.removeAll()
        // Writes the updated complete history through the persistence abstraction.
        persistence.save(matchHistory)
    }

    // Declares a helper that captures the complete reversible match state.
    private mutating func saveSnapshot() {
        // Pushes a new snapshot onto the Undo stack.
        undoHistory.append(
            // Constructs a snapshot using the match’s current values.
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

    // Declares the helper that increments the selected team’s score.
    private mutating func incrementScore(for team: Team) {
        // Chooses which stored score to modify based on the supplied Team value.
        switch team {
        case .teamA:
            // Uses compound assignment to add one to Team A’s score.
            scoreA += 1
        case .teamB:
            // Uses compound assignment to add one to Team B’s score.
            scoreB += 1
        }
    }

    // Declares the helper that records a game and advances match state.
    private mutating func finishGame() {
        // Creates an immutable completed-game result from the current scores.
        let result = GameResult(scoreA: scoreA, scoreB: scoreB)
        // Adds the result to the ordered list of completed games.
        completedGames.append(result)

        // Branches on the computed winner of the completed game.
        switch result.winner {
        case .teamA:
            gamesWonA += 1
        case .teamB:
            gamesWonB += 1
        }

        scoreA = 0
        scoreB = 0

        // Checks whether either team has now won the best-of-three match.
        if isMatchOver {
            // Stops scoring and asks the UI to present match confirmation.
            matchPhase = .awaitingConfirmation
        // Begins the scope introduced by this declaration or control-flow statement.
        } else {
            // Advances the displayed game number when the match continues.
            gameNum += 1
        }
    }

    // Declares the helper that enforces the maximum saved-history length.
    private mutating func trimMatchHistory() {
        // Calculates how many records exceed the configured limit.
        let overflow = matchHistory.count - matchHistoryLimit
        // Performs trimming only when history is actually over the limit.
        if overflow > 0 {
            // Removes the calculated number of oldest records from the front of the array.
            matchHistory.removeFirst(overflow)
        }
    }
}
