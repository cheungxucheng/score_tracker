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
    @State private var scoreA: Int = 0
    @State private var scoreB: Int = 0

    var body: some View {
        NavigationStack {
            NavigationLink("Singles") {
                TabView {
                    ServeView(
                        isDoubles: false,
                        scoreA: scoreA,
                        scoreB: scoreB
                    )
                    ScoreView(
                        scoreA: $scoreA,
                        scoreB: $scoreB
                    )
                }
            }
            NavigationLink("Doubles") {
                TabView {
                    ServeView(
                        isDoubles: false,
                        scoreA: scoreA,
                        scoreB: scoreB
                    )
                    ScoreView(
                        scoreA: $scoreA,
                        scoreB: $scoreB
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

// struct GameState {
//     var scoreA = 0
//     var scoreB = 0
//     var servingTeam: Team = teamA
// }

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
    let scoreA: Int 
    let scoreB: Int

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
    @Binding var scoreA: Int
    @Binding var scoreB: Int

    var body: some View {
        VStack {
            Button("\(scoreA)")
            Button("\(scoreB)")
        }
    }
}