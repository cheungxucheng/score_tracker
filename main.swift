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
    @State private var game: GameState

    var body: some View {
        NavigationStack {
            NavigationLink("Singles") {
                TabView {
                    ServeView(
                        isDoubles: false,
                        game: game
                    )
                    ScoreView(
                        game: $game
                    )
                }
            }
            NavigationLink("Doubles") {
                TabView {
                    ServeView(
                        isDoubles: false,
                        game: game
                    )
                    ScoreView(
                        game: $game
                    )
                }
            }
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

struct GameState {
    var scoreA = 0
    var scoreB = 0
    var servingTeam: Team = teamA
    var gameNum = 1
    var firstGame: String
    var secondGame: String
}

func pointWon(by winningTeam: Team) {
    let previousServingTeam = servingTeam

    // 1. Update score
    if winningTeam == .a {
        scoreA += 1
    } else {
        scoreB += 1
    }

    // 2. Update server logic
    if winningTeam != previousServingTeam {
        servingTeam = winningTeam

        // New serving team chooses server based on score parity
        updateServerByScoreParity()
    } else {
        // Same team scored while serving
        switchServerSide()
    }

    // 3. Check game over
    if isGameOver {
        resetGame()
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
                // logic should be:
                // score starts at 0 - 0
                // indicate which team/player serves first
                // then mark the player somehow to indicate they're serving
                // what are the criteria for winning a game?
                // score >= 21 and difference = 2 or score = 30
                // scoreA is >= 21 and scoreA - scoreB = 2 or scoreB is >= 21 and scoreB - scoreA = 2 or (scoreA or scoreB = 30)
                // while !(max(scoreA, scoreB) >= 21 && abs(scoreA - scoreB) >= 2) && !(max(scoreA, scoreB) == 30)
                    // we then await a score change
                    // if the team that wasn't serving scores a point
                    //      the server becomes the one on that team that matches the parity of the score
                    // else 
                    //      server and partner switch sides of the court
                // reset score to 0 - 0
                var p1: Player(team: teamA, side: right)
                var p2: Player(team: teamA, side: left)
                var p3: Player(team: teamB, side: left)
                var p4: Player(team: teamB, side: right)
                var scoreA = 0
                var scoreB = 0

                Path { path in
                    // Draws the opponent service lines
                    path.move(to: CGPoint(x: 0, y: 0.3 * h))
                    path.addLine(to: CGPoint(x: w, y: 0.3 * h))

                    path.move(to: CGPoint(x: 0.5 * w, y: 0))
                    path.addLine(to: CGPoint(x: 0.5 * w, y: 0.3 * h))

                    // Draws the user's service lines
                    path.move(to: CGPoint(x: 0, y: 0.7 * h))
                    path.addLine(to: CGPoint(x: w, y: 0.7 * h))

                    path.move(to: CGPoint(x: 0.5 * w, y: h))
                    path.addLine(to: CGPoint(x: 0.5 * w, y: 0.7 * h))
                }
                .stroke(.white, lineWidth: 7)

                // Player representations

                // Opponent team
                RoundedRectangle()
                    .fill(.red)
                    .frame(width: 0.2 * h, height: 0.2 * h)
                    .position(x: 0.25 * w, y: 0.15 * h)

                if (isDoubles) {
                    RoundedRectangle()
                        .fill(.clear)
                        .stroke(.red, lineWidth: 7)
                        .frame(width: 0.2 * h, height: 0.2 * h)
                        .position(x: 0.75 * w, y: 0.15 * h)
                }
                
                // User team
                Circle()
                    .fill(.blue)
                    .frame(width: 0.2 * h, height: 0.2 * h)
                    .position(x: 0.25 * w, y: 0.85 * h)

                if (isDoubles) {
                    Circle()
                        .fill(.clear)
                        .stroke(.blue, lineWidth: 7)
                        .frame(width: 0.2 * h, height: 0.2 * h)
                        .position(x: 0.75 * w, y: 0.85 * h)
                }
            }
            .background(.green)
        }
    }
}

struct ScoreView: View {
    @Binding var game: GameState

    var body: some View {
        GeometryReader { geo in
            VStack(spacing: 4) {
                Text("Game \(game.gameNum) \(game.firstGame) \(game.secondGame)")
                .font(.caption2)
                // text color
                .foregroundStyle(.black)
                // width of text fills display
                .frame(maxWidth: .infinity)
                .padding(.vertical, 3)
                .background(.gray)
                .clipShape(Capsule())

                // think about what it would mean to implement an undo and redo button.
                // how would i track the previous increments?
                // how would i track the undid increments?
                // why use this versus a decrement feature?
                // decrement vs undo/redo action
                // // decrement makes it so that score is adjustable
                // // effectively the same action, but its more that undoing and redoing 
                // // requires a history of score changes
                // // the end result is the same though. in what scenario would i want to keep a history?
                // // KISS
                // ok, so we just do a decrement feature instead
                ZStack {
                    // Apple has a symbol/emoji thing that i can use for the undo and redo buttons
                    // undo button should lie on the edge between two sides and on the left
                    Button {

                    }
                    // redo button should lie on the edge between two sides and on the right
                    Button {

                    }
                    VStack(spacing: 0) {
                        Button {
                            game.scoreA += 1
                        } label: {
                            Text("\(game.scoreA)")
                                .font(.largeTitle)
                                .frame(maxWidth: .infinity,
                                    maxHeight: .infinity)
                        }
                        .background(.red)
                        Button {
                            game.scoreB += 1
                        } label: {
                            Text("\(game.scoreB)")
                                .font(.largeTitle)
                                .frame(maxWidth: .infinity,
                                    maxHeight: .infinity)
                        }
                        .background(.blue)
                    }
                    .frame(maxWidth: .infinity,
                        maxHeight: .infinity)
                }
            }
        }
    }
}