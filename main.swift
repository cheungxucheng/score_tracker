import SwiftUI

struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: CGPoint(x: rect.midX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.midX, y: rect.minY))
        }
    }
}

@main // the defined place where execution begins (every app needs)
// App : tells swiftui this describes an app
// body : declares the scenes
// WindowGroup : creates the app's main window
struct ScoreTrackerApp: App {
    var body: some Scene {
        WindowGroup {
            HomeView()
        }
    }
}

struct HomeView: View {
    var body: some View {
        NavigationStack {
            NavigationLink("Badminton") {
                BadmintonView()
            }
        }
    }
}
/*
ScoreView should be the only one able to modify scores
ServeView has only read access to scores
*/
struct BadmintonView: View {
    @State private var game = GameState()

    var body: some View {
        TabView {
            ServeView(
                isDoubles: true,
                game: game
            )

            ScoreView(
                game: $game
            )
        }
    }
}

// team A is considered to be the user's team
enum Team {
    case teamA
    case teamB
}

enum Parity {
    case left
    case right
}

struct Player {
    // distinguish what team a player is on
    let team: Team
    // distinguish what side the player is on
    var side: Parity
}

// changed to store methods within gamestate
// why? 
// well, even when we're just changing the score
// there are lots of variables that depend on the score
// we encapsulate it all in game state so that when score is updated, everything else updates
// that way the logic for buttons is much simpler
// also mutating is needed because struct functions are read only by default in swift
struct GameState {
    private(set) var scoreA = 0
    private(set) var scoreB = 0
    private(set) var servingTeam: Team = .teamA
    private(set) var gameNum = 1
    // a collection(arr?) of completed game score strings
    private(set) var completedGames: [String] = []
    private(set) var serverNum = 0
    private(set) var gamesWonA = 0;
    private(set) var gamesWonB = 0;
    /*
    0 : A1 <- user (hopefully)
    1 : A2
    2 : B1
    3 : B2
    */
    private(set) var players = [
        Player(team: .teamA, side: .right),
        Player(team: .teamA, side: .left),
        Player(team: .teamB, side: .right),
        Player(team: .teamB, side: .left)
    ]

    var isGameOver: Bool {
        let leadingScore = max(scoreA, scoreB)

        return leadingScore == 30 ||
            (leadingScore >= 21 &&
             abs(scoreA - scoreB) >= 2)
    }

    var isMatchOver: Bool {
        return gamesWonA == 2 || gamesWonB == 2
    }

    mutating func pointWon(by winningTeam: Team) {
        incrementScore(for: winningTeam)
        updateService(afterPointWonBy: winningTeam)

        if isGameOver {
            finishGame()
        }
    }

    private mutating func incrementScore(for team: Team) {
        switch team {
        case .teamA:
            scoreA += 1

        case .teamB:
            scoreB += 1
        }
    }

    private mutating func updateService(
        afterPointWonBy winningTeam: Team
    ) {
        if winningTeam != servingTeam {
            servingTeam = winningTeam
            selectServerUsingScoreParity(for: winningTeam)
        } else {
            switchPlayerSides(for: winningTeam)
        }
    }

    private mutating func selectServerUsingScoreParity(
        for team: Team
    ) {
        // the idea is is that we select the current server from the winning team
        // based on the score parity. we can have an index into the player arr 
        // represent who is currently serving.

        // issue being, how do we tell what the score is based on the team?
        // score is currently being tracked as two ints, scoreA and scoreB
        // but just because its named score

        // could do: if team = .teamA, check scoreA, vice versa

        // if serving team is teamA then if the score is even then if 
        let score = team == .teamA ? scoreA : scoreB
        let player1 = team == .teamA ? 0 : 2
        let player2 = player1 + 1

        let desiredSide: Parity =
            score % 2 == 0 ? .right : .left 
        
        serverNum = players[player1].side == desiredSide ? player1 : player2
    }

    private mutating func switchPlayerSides(
        for team: Team
    ) {
        // Add doubles position-switching logic here.
        if (team == .teamA) {
            let temp: Parity = players[0].side
            players[0].side = players[1].side
            players[1].side = temp
        }
        else {
            let temp: Parity = players[2].side
            players[2].side = players[3].side
            players[3].side = temp
        }
    }

    private mutating func finishGame() {
        completedGames.append("\(scoreA)-\(scoreB)")

        if (scoreA - scoreB >= 2 || scoreA == 30) {
            gamesWonA += 1
        }
        else if (scoreB - scoreA >= 2 || scoreB == 30) {
            gamesWonB += 1
        }

        scoreA = 0
        scoreB = 0
        if (!isMatchOver) 
            gameNum += 1
        }
    }

    mutating func resetMatch() { 
        completedGames = []
        gameNum = 1;
        gamesWonA = 0
        gamesWonB = 0
    }

    mutating func removePoint(from team: Team) {
    switch team {
    case .teamA:
        scoreA = max(0, scoreA - 1)

    case .teamB:
        scoreB = max(0, scoreB - 1)
    }
}
}

struct ServeView: View {
    let isDoubles: Bool
    let game: GameState

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height

            ZStack {
                courtLines(width: w, height: h)

                opponentPlayers(width: w, height: h)

                userPlayers(width: w, height: h)

                servingIndicator(width: w, height: h)
            }
            .background(.green)
        }
    }
    @ViewBuilder
    private func userPlayers(width: CGFloat, height: CGFloat) -> some View {
        Circle()
            .fill(.blue)
            .frame(width: 0.2 * height, height: 0.2 * height)
            .position(x: 0.25 * width, y: 0.85 * height)

        if isDoubles {
            Circle()
                .stroke(.blue, lineWidth: 7)
                .frame(width: 0.2 * height, height: 0.2 * height)
                .position(x: 0.75 * width, y: 0.85 * height)
        }
    }

    @ViewBuilder
    private func opponentPlayers(width: CGFloat, height: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(.red)
            .frame(width: 0.2 * height, height: 0.2 * height)
            .position(x: 0.25 * width, y: 0.15 * height)

        if isDoubles {
            RoundedRectangle(cornerRadius: 4)
                .stroke(.red, lineWidth: 7)
                .frame(width: 0.2 * height, height: 0.2 * height)
                .position(x: 0.75 * width, y: 0.15 * height)
        }
    }

    @ViewBuilder
    private func servingIndicator(
        width: CGFloat,
        height: CGFloat
    ) -> some View {
        if game.servingTeam == .teamA {
            Circle()
                .stroke(.yellow, lineWidth: 3)
                .frame(width: 40, height: 40)
                .position(
                    x: width * 0.25,
                    y: height * 0.85
                )
        } else {
            RoundedRectangle(cornerRadius: 4)
                .stroke(.yellow, lineWidth: 3)
                .frame(width: 40, height: 40)
                .position(
                    x: width * 0.25,
                    y: height * 0.15
                )
        }
    }
}

// Viewbuilder technically not needed for court lines, since it only returns one path?
@ViewBuilder
private func courtLines(
    width: CGFloat,
    height: CGFloat
) -> some View {
    Path { path in
        // Opponent short service line
        path.move(to: CGPoint(x: 0, y: 0.3 * height))
        path.addLine(to: CGPoint(x: width, y: 0.3 * height))

        // Opponent center line
        path.move(to: CGPoint(x: 0.5 * width, y: 0))
        path.addLine(to: CGPoint(x: 0.5 * width, y: 0.3 * height))

        // User short service line
        path.move(to: CGPoint(x: 0, y: 0.7 * height))
        path.addLine(to: CGPoint(x: width, y: 0.7 * height))

        // User center line
        path.move(to: CGPoint(x: 0.5 * width, y: height))
        path.addLine(to: CGPoint(x: 0.5 * width, y: 0.7 * height))
    }
    .stroke(.white, lineWidth: 7)
    
}


struct ScoreView: View {
    // a binding is essentially a pointer to an outside value
    @Binding var game: GameState

    var body: some View {
        VStack(spacing: 4) {
            Text(gameHeader)
                .font(.caption2)
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 3)
                .background(.gray)
                .clipShape(Capsule())

            VStack(spacing: 0) {
                scoreRow(
                    score: game.scoreA,
                    color: .red,
                    onDecrement: {
                        game.removePoint(from: .teamA)
                    },
                    onIncrement: {
                        game.pointWon(by: .teamA)
                    }
                )

                scoreRow(
                    score: game.scoreB,
                    color: .blue,
                    onDecrement: {
                        game.removePoint(from: .teamB)
                    },
                    onIncrement: {
                        game.pointWon(by: .teamB)
                    }
                )
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
    // completedGames would crash if trying to access indices 0 and 1 at the start of the game
    // since it is an empty array
    private var gameHeader: String {
        let results = game.completedGames.joined(separator: "  ")
        return "Game \(game.gameNum) \(results)"
    }

    private func scoreRow(
        score: Int,
        color: Color,
        onDecrement: @escaping () -> Void,
        onIncrement: @escaping () -> Void
    ) -> some View {
        HStack {
            Button(action: onDecrement) {
                Image(systemName: "minus")
            }

            Text("\(score)")
                .font(.largeTitle)
                .frame(maxWidth: .infinity)

            Button(action: onIncrement) {
                Image(systemName: "plus")
            }
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal)
        .background(color)
    }
}
