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

struct BadmintonView: View {
    var body: some View {
        NavigationStack {
            NavigationLink("Singles") {
                ServeView(isDoubles: false)
            }
            NavigationLink("Doubles") {
                ServeView(isDoubles: true)
            }
        }
    }
}

struct ServeView: View {
    let isDoubles: Bool

    var body: some View {
        GeometryReader { geo in 
            let w = geo.size.width
            let h = geo.size.height
            ZStack {
                var 
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
    var body: some View {
        ZStack {
            Rectangle()
            Rectangle()
            Rectangle()
            Rectangle()
        }
    }
}