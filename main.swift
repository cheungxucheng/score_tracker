struct HomeView: View {
    var body: some View {
        NavigationStack {
            NavigationLink("Badminton") {
                badmintonView()
            }
        }
    }
}

struct Badmintonview: View {
    var body: some View {
        TabView {
            serveView()
            scoreView()
        }
    }
}

struct ServeView: View {
    var body: some View {
        GeometryReader { geo in 
            let w = geo.size.width
            let h = geo.size.height
            ZStack {
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
                .stroke(.white, lineWidth: 2)

                Circle()

                Circle()

                Circle()

                Circle()
            }
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