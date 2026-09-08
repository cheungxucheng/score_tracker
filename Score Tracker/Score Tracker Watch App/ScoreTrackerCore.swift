// Imports Foundation types used here, including Date, UUID, UserDefaults, and JSON encoders.
import Foundation

// Match Length Selection
enum NumGames: Int, CaseIterable, Identifiable {
    case bo1 = 1
    case bo3 = 3
    case bo5 = 5
    
    var id: Int {self.rawValue}
    var gamesNeededToWin: Int {(rawValue / 2)}
}
// Declares the two possible teams and adopts protocols for raw strings, persistence, iteration, and equality.
enum Team: String, Codable, CaseIterable, Equatable {
    // Defines the first valid Team value.
    case teamA
    // Defines the second valid Team value.
    case teamB

    // Declares a computed property that produces a user-facing name for this team.
    var displayName: String {
        // Selects behavior based on which Team value this instance contains.
        switch self {
        // Handles the Team A branch of the switch.
        case .teamA:
            // Returns the display text for Team A.
            return "Your Team"
        // Handles the Team B branch of the switch.
        case .teamB:
            // Returns the display text for Team B.
            return "Opponent Team"
        // Closes the current Swift declaration, function, conditional, switch, or type scope.
        }
    // Closes the current Swift declaration, function, conditional, switch, or type scope.
    }
// Closes the current Swift declaration, function, conditional, switch, or type scope.
}

// Declares the finite states that describe where a match is in its lifecycle.
enum MatchPhase: Equatable {
    // Represents a match that currently accepts scoring input.
    case playing
    // Represents a finished match waiting for the user to save or undo it.
    case awaitingConfirmation
    // Represents a match that has been confirmed and saved.
    case completed
// Closes the current Swift declaration, function, conditional, switch, or type scope.
}

// Declares a value type representing the final score of one completed game.
struct GameResult: Codable, Equatable {
    // Stores Team A’s score as an immutable integer.
    let scoreA: Int
    // Stores Team B’s score as an immutable integer.
    let scoreB: Int

    // Declares a computed property that determines the winning team from the two scores.
    var winner: Team {
        // Uses the ternary operator: choose Team A when its score is greater; otherwise choose Team B.
        scoreA > scoreB ? .teamA : .teamB
    // Closes the current Swift declaration, function, conditional, switch, or type scope.
    }

    // Declares a computed string formatted for compact score display.
    var displayScore: String {
        // Uses string interpolation to combine both integer scores with a hyphen.
        "\(scoreA)-\(scoreB)"
    // Closes the current Swift declaration, function, conditional, switch, or type scope.
    }
// Closes the current Swift declaration, function, conditional, switch, or type scope.
}

// Declares an identifiable, persistable value representing one completed match.
struct MatchRecord: Identifiable, Codable, Equatable {
    // Stores the record’s stable unique identifier.
    let id: UUID
    // Stores the date and time when the match was saved.
    let playedAt: Date
    // Stores the ordered results of every game in the match.
    let games: [GameResult]
    // Stores the team that won the match.
    let winner: Team
// Closes the current Swift declaration, function, conditional, switch, or type scope.
}

// Defines the interface that any match-history storage implementation must provide.
protocol MatchHistoryPersisting {
    // Requires conforming storage types to load and return all saved match records.
    func load() -> [MatchRecord]
    // Requires conforming storage types to save the supplied record array; `_` omits the external argument label.
    func save(_ records: [MatchRecord])
// Closes the current Swift declaration, function, conditional, switch, or type scope.
}

// Declares a non-subclassable reference type that stores match history in UserDefaults.
final class UserDefaultsMatchHistoryPersistence: MatchHistoryPersisting {
    // Stores the UserDefaults database used by this persistence object.
    private let defaults: UserDefaults
    // Stores the dictionary key under which encoded history data is saved.
    private let key: String

    // Begins an initializer that constructs a new instance.
    init(
        // Declares an injectable UserDefaults parameter whose default is the app’s standard database.
        defaults: UserDefaults = .standard,
        // Declares an injectable storage-key parameter with the app’s normal key as its default.
        key: String = "scoreTracker.matchHistory"
    // Begins the scope introduced by this declaration or control-flow statement.
    ) {
        // Assigns the initializer parameter to the instance property; `self` distinguishes the property from the parameter.
        self.defaults = defaults
        // Stores the supplied persistence key on this instance.
        self.key = key
    // Closes the current Swift declaration, function, conditional, switch, or type scope.
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
            // Closes the surrounding initializer call or multiline argument list.
            )
        // Begins the guard’s failure branch, which must exit the current scope.
        else {
            // Returns an empty array when there is no data or decoding fails.
            return []
        // Closes the current Swift declaration, function, conditional, switch, or type scope.
        }

        // Returns the successfully decoded match records.
        return records
    // Closes the current Swift declaration, function, conditional, switch, or type scope.
    }

    // Requires conforming storage types to save the supplied record array; `_` omits the external argument label.
    func save(_ records: [MatchRecord]) {
        // Attempts to encode the records as JSON Data and enters the failure branch if encoding fails.
        guard let data = try? JSONEncoder().encode(records) else {
            // Exits the current function early without producing a value.
            return
        // Closes the current Swift declaration, function, conditional, switch, or type scope.
        }

        // Writes the encoded bytes into UserDefaults under the configured key.
        defaults.set(data, forKey: key)
    // Closes the current Swift declaration, function, conditional, switch, or type scope.
    }
// Closes the current Swift declaration, function, conditional, switch, or type scope.
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
// Closes the current Swift declaration, function, conditional, switch, or type scope.
}

// Declares the central value type that owns scoring rules, active-match state, Undo, and history.
struct GameState {
    // Stores Team A’s live score; outside code may read it but only GameState may change it directly.
    private(set) var scoreA = 0
    // Stores Team B’s live score with a private setter.
    private(set) var scoreB = 0
    // Stores the one-based current game number with a private setter.
    private(set) var gameNum = 1
    // Stores completed game results while preventing outside code from mutating the array directly.
    private(set) var completedGames: [GameResult] = []
    // Stores how many games Team A has won.
    private(set) var gamesWonA = 0
    // Stores how many games Team B has won.
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
        // Closes the surrounding initializer call or multiline argument list.
        )
    // Closes the current Swift declaration, function, conditional, switch, or type scope.
    }

    // Declares a computed Boolean that applies badminton’s game-winning rules.
    var isGameOver: Bool {
        // Finds the greater of the two current scores.
        let leadingScore = max(scoreA, scoreB)
        // Ends a game at the 30-point cap or when a team has at least 21 points and leads by two.
        return leadingScore == 30 ||
            // Implements the normal win-by-two condition after reaching 21 points.
            (leadingScore >= 21 && abs(scoreA - scoreB) >= 2)
    // Closes the current Swift declaration, function, conditional, switch, or type scope.
    }

    // Declares a computed Boolean for a best-of-three match.
    var isMatchOver: Bool {
        // Returns true as soon as either team has won two games.
        gamesWonA == 2 || gamesWonB == 2
    // Closes the current Swift declaration, function, conditional, switch, or type scope.
    }

    // Declares an optional computed winner because an unfinished match has no winner.
    var matchWinner: Team? {
        // Checks whether Team A has reached the two-game winning threshold.
        if gamesWonA == 2 {
            // Returns Team A as the match winner.
            return .teamA
        // Closes the current Swift declaration, function, conditional, switch, or type scope.
        }

        // Checks whether Team B has reached the two-game winning threshold.
        if gamesWonB == 2 {
            // Returns Team B as the match winner.
            return .teamB
        // Closes the current Swift declaration, function, conditional, switch, or type scope.
        }

        // Returns no value because the match has not produced a winner.
        return nil
    // Closes the current Swift declaration, function, conditional, switch, or type scope.
    }

    // Declares whether there is a saved snapshot and the match has not been finalized.
    var canUndo: Bool {
        // Requires at least one snapshot and disallows Undo after completion.
        !undoHistory.isEmpty && matchPhase != .completed
    // Closes the current Swift declaration, function, conditional, switch, or type scope.
    }

    // Declares whether the current match contains any points or completed games.
    var hasActiveMatchProgress: Bool {
        // Returns true when either live score is nonzero or a game has already finished.
        scoreA > 0 || scoreB > 0 || !completedGames.isEmpty
    // Closes the current Swift declaration, function, conditional, switch, or type scope.
    }

    // Declares a method that may change this value-type instance when a team scores.
    mutating func pointWon(by winningTeam: Team) {
        // Rejects scoring unless the match is actively in the playing phase.
        guard matchPhase == .playing else {
            // Exits the current function early without producing a value.
            return
        // Closes the current Swift declaration, function, conditional, switch, or type scope.
        }

        // Captures the current state before changing it, enabling Undo.
        saveSnapshot()
        // Adds one point to the team supplied by the caller.
        incrementScore(for: winningTeam)

        // Checks the scoring rules after the point to see whether the current game ended.
        if isGameOver {
            // Records the completed game and advances or completes the match.
            finishGame()
        // Closes the current Swift declaration, function, conditional, switch, or type scope.
        }
    // Closes the current Swift declaration, function, conditional, switch, or type scope.
    }

    // Declares the operation that restores the most recently saved snapshot.
    mutating func undoLastPoint() {
        // Removes and unwraps the newest snapshot; exits if the history stack is empty.
        guard let previous = undoHistory.popLast() else {
            // Exits the current function early without producing a value.
            return
        // Closes the current Swift declaration, function, conditional, switch, or type scope.
        }

        // Restores this field from the snapshot captured before the last point.
        scoreA = previous.scoreA
        // Restores this field from the snapshot captured before the last point.
        scoreB = previous.scoreB
        // Restores this field from the snapshot captured before the last point.
        gameNum = previous.gameNum
        // Restores this field from the snapshot captured before the last point.
        completedGames = previous.completedGames
        // Restores this field from the snapshot captured before the last point.
        gamesWonA = previous.gamesWonA
        // Restores this field from the snapshot captured before the last point.
        gamesWonB = previous.gamesWonB
        // Restores this field from the snapshot captured before the last point.
        matchPhase = previous.matchPhase
    // Closes the current Swift declaration, function, conditional, switch, or type scope.
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
        // Closes the current Swift declaration, function, conditional, switch, or type scope.
        }

        // Constructs the persistable record for this completed match.
        let record = MatchRecord(
            // Copies the supplied unique identifier into the new record.
            id: id,
            // Copies the supplied completion date into the record.
            playedAt: date,
            // Copies every completed game result into the record.
            games: completedGames,
            // Copies the safely unwrapped winning team into the record.
            winner: winner
        // Closes the surrounding initializer call or multiline argument list.
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
    // Closes the current Swift declaration, function, conditional, switch, or type scope.
    }

    // Declares the reset operation used to begin a completely fresh match.
    mutating func startNewMatch() {
        // Resets this numeric match field to zero.
        scoreA = 0
        // Resets this numeric match field to zero.
        scoreB = 0
        // Resets the displayed game number to the first game.
        gameNum = 1
        // Replaces completed games with an empty array.
        completedGames = []
        // Resets this numeric match field to zero.
        gamesWonA = 0
        // Resets this numeric match field to zero.
        gamesWonB = 0
        // Removes every stored Undo snapshot.
        undoHistory = []
        // Returns the lifecycle to the state that accepts scoring.
        matchPhase = .playing
    // Closes the current Swift declaration, function, conditional, switch, or type scope.
    }

    // Declares a convenience operation for abandoning active progress.
    mutating func discardCurrentMatch() {
        // Reuses the full reset logic rather than duplicating it.
        startNewMatch()
    // Closes the current Swift declaration, function, conditional, switch, or type scope.
    }

    // Declares an operation that deletes one saved match by identifier.
    mutating func deleteHistoryRecord(id: UUID) {
        // Removes every record whose identifier matches the requested identifier.
        matchHistory.removeAll { $0.id == id }
        // Writes the updated complete history through the persistence abstraction.
        persistence.save(matchHistory)
    // Closes the current Swift declaration, function, conditional, switch, or type scope.
    }

    // Declares an operation that deletes the entire saved history.
    mutating func clearMatchHistory() {
        // Empties the in-memory match-history array.
        matchHistory.removeAll()
        // Writes the updated complete history through the persistence abstraction.
        persistence.save(matchHistory)
    // Closes the current Swift declaration, function, conditional, switch, or type scope.
    }

    // Declares a helper that captures the complete reversible match state.
    private mutating func saveSnapshot() {
        // Pushes a new snapshot onto the Undo stack.
        undoHistory.append(
            // Constructs a snapshot using the match’s current values.
            GameSnapshot(
                // Copies this current GameState field into the corresponding snapshot field.
                scoreA: scoreA,
                // Copies this current GameState field into the corresponding snapshot field.
                scoreB: scoreB,
                // Copies this current GameState field into the corresponding snapshot field.
                gameNum: gameNum,
                // Copies this current GameState field into the corresponding snapshot field.
                completedGames: completedGames,
                // Copies this current GameState field into the corresponding snapshot field.
                gamesWonA: gamesWonA,
                // Copies this current GameState field into the corresponding snapshot field.
                gamesWonB: gamesWonB,
                // Copies this current GameState field into the corresponding snapshot field.
                matchPhase: matchPhase
            // Closes the surrounding initializer call or multiline argument list.
            )
        // Closes the surrounding initializer call or multiline argument list.
        )
    // Closes the current Swift declaration, function, conditional, switch, or type scope.
    }

    // Declares the helper that increments the selected team’s score.
    private mutating func incrementScore(for team: Team) {
        // Chooses which stored score to modify based on the supplied Team value.
        switch team {
        // Handles the Team A branch of the switch.
        case .teamA:
            // Uses compound assignment to add one to Team A’s score.
            scoreA += 1
        // Handles the Team B branch of the switch.
        case .teamB:
            // Uses compound assignment to add one to Team B’s score.
            scoreB += 1
        // Closes the current Swift declaration, function, conditional, switch, or type scope.
        }
    // Closes the current Swift declaration, function, conditional, switch, or type scope.
    }

    // Declares the helper that records a game and advances match state.
    private mutating func finishGame() {
        // Creates an immutable completed-game result from the current scores.
        let result = GameResult(scoreA: scoreA, scoreB: scoreB)
        // Adds the result to the ordered list of completed games.
        completedGames.append(result)

        // Branches on the computed winner of the completed game.
        switch result.winner {
        // Handles the Team A branch of the switch.
        case .teamA:
            // Adds this game win to Team A’s match total.
            gamesWonA += 1
        // Handles the Team B branch of the switch.
        case .teamB:
            // Adds this game win to Team B’s match total.
            gamesWonB += 1
        // Closes the current Swift declaration, function, conditional, switch, or type scope.
        }

        // Resets this numeric match field to zero.
        scoreA = 0
        // Resets this numeric match field to zero.
        scoreB = 0

        // Checks whether either team has now won the best-of-three match.
        if isMatchOver {
            // Stops scoring and asks the UI to present match confirmation.
            matchPhase = .awaitingConfirmation
        // Begins the scope introduced by this declaration or control-flow statement.
        } else {
            // Advances the displayed game number when the match continues.
            gameNum += 1
        // Closes the current Swift declaration, function, conditional, switch, or type scope.
        }
    // Closes the current Swift declaration, function, conditional, switch, or type scope.
    }

    // Declares the helper that enforces the maximum saved-history length.
    private mutating func trimMatchHistory() {
        // Calculates how many records exceed the configured limit.
        let overflow = matchHistory.count - matchHistoryLimit
        // Performs trimming only when history is actually over the limit.
        if overflow > 0 {
            // Removes the calculated number of oldest records from the front of the array.
            matchHistory.removeFirst(overflow)
        // Closes the current Swift declaration, function, conditional, switch, or type scope.
        }
    // Closes the current Swift declaration, function, conditional, switch, or type scope.
    }
// Closes the current Swift declaration, function, conditional, switch, or type scope.
}
