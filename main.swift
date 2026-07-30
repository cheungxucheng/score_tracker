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
    var scoreA = 0
    var scoreB = 0
    var servingTeam: Team = .teamA
    var gameNum = 1
    var firstGame = ""
    var secondGame = ""

    var isGameOver: Bool {
        let leadingScore = max(scoreA, scoreB)

        return leadingScore == 30 ||
            (leadingScore >= 21 &&
             abs(scoreA - scoreB) >= 2)
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
        // Add server selection logic here.
    }

    private mutating func switchPlayerSides(
        for team: Team
    ) {
        // Add doubles position-switching logic here.
    }

    private mutating func finishGame() {
        let result = "\(scoreA)-\(scoreB)"

        if gameNum == 1 {
            firstGame = result
        } else if gameNum == 2 {
            secondGame = result
        }

        scoreA = 0
        scoreB = 0
        gameNum += 1
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
}

@ViewBuilder
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
    private var gameHeader: String {
        "Game \(game.gameNum) \(game.firstGame) \(game.secondGame)"
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
