import SwiftUI

#if os(watchOS)
import WatchKit
#endif

@main
struct ScoreTrackerApp: App {
    var body: some Scene {
        WindowGroup {
            HomeView()
        }
    }
}

struct HomeView: View {
    @State private var game = GameState()

    var body: some View {
        NavigationStack {
            List {
                NavigationLink {
                    BadmintonView(game: $game)
                } label: {
                    Label("Score Match", systemImage: "plus.circle.fill")
                }

                NavigationLink {
                    MatchHistoryView(game: $game)
                } label: {
                    Label("Match History", systemImage: "clock.arrow.circlepath")
                }
            }
            .navigationTitle("Badminton")
        }
    }
}

struct BadmintonView: View {
    @Binding var game: GameState
    @Environment(\.dismiss) private var dismiss
    @State private var showDiscardConfirmation = false

    private var showMatchCompletion: Binding<Bool> {
        Binding(
            get: { game.matchPhase == .awaitingConfirmation },
            set: { _ in }
        )
    }

    var body: some View {
        ScoreView(game: $game)
            .navigationTitle("Score")
            .navigationBarBackButtonHidden(game.hasActiveMatchProgress)
            .toolbar {
                if game.hasActiveMatchProgress {
                    ToolbarItem(placement: .cancellationAction) {
                        Button {
                            showDiscardConfirmation = true
                        } label: {
                            Image(systemName: "xmark")
                        }
                        .accessibilityLabel("End current match")
                    }
                }
            }
            .confirmationDialog(
                "Discard the current match?",
                isPresented: $showDiscardConfirmation,
                titleVisibility: .visible
            ) {
                Button("Discard Match", role: .destructive) {
                    game.discardCurrentMatch()
                    dismiss()
                }

                Button("Keep Playing", role: .cancel) {}
            } message: {
                Text("The unfinished match and its Undo history will be lost.")
            }
            .sheet(isPresented: showMatchCompletion) {
                if let winner = game.matchWinner {
                    MatchCompletionView(
                        winner: winner,
                        games: game.completedGames,
                        canUndo: game.canUndo,
                        undo: {
                            game.undoLastPoint()
                            Haptics.undo()
                        },
                        saveAndStartNew: {
                            game.confirmCompletedMatch()
                            game.startNewMatch()
                        },
                        saveAndFinish: {
                            game.confirmCompletedMatch()
                            game.startNewMatch()
                            dismiss()
                        }
                    )
                    .interactiveDismissDisabled()
                }
            }
    }
}

struct ScoreView: View {
    @Binding var game: GameState

    private var completedScores: String {
        game.completedGames
            .map(\.displayScore)
            .joined(separator: "  ")
    }

    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 6) {
                Text("Game \(game.gameNum)")
                    .font(.caption2)
                    .fontWeight(.semibold)

                if !completedScores.isEmpty {
                    Spacer(minLength: 2)
                    Text(completedScores)
                        .font(.caption2)
                        .lineLimit(1)
                        .minimumScaleFactor(0.65)
                }
            }
            .foregroundStyle(.primary)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(.gray.opacity(0.3))
            .clipShape(Capsule())
            .accessibilityElement(children: .combine)

            VStack(spacing: 2) {
                scoreButton(
                    team: .teamA,
                    score: game.scoreA,
                    color: .red
                )

                scoreButton(
                    team: .teamB,
                    score: game.scoreB,
                    color: .blue
                )
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Button {
                game.undoLastPoint()
                Haptics.undo()
            } label: {
                Label("Undo", systemImage: "arrow.uturn.backward")
                    .font(.caption)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 36)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .background(.gray.opacity(game.canUndo ? 0.28 : 0.12))
            .clipShape(Capsule())
            .disabled(!game.canUndo)
            .accessibilityLabel("Undo last point")
            .accessibilityHint("Restores the score before the most recent point")
        }
        .padding(.horizontal, 4)
    }

    private func scoreButton(
        team: Team,
        score: Int,
        color: Color
    ) -> some View {
        Button {
            let completedGameCount = game.completedGames.count
            game.pointWon(by: team)

            if game.matchPhase == .awaitingConfirmation {
                Haptics.matchCompleted()
            } else if game.completedGames.count > completedGameCount {
                Haptics.gameCompleted()
            } else {
                Haptics.pointScored()
            }
        } label: {
            VStack(spacing: 2) {
                Text(team.displayName)
                    .font(.caption2)
                    .fontWeight(.semibold)

                Text("\(score)")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .monospacedDigit()
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .background(color)
        }
        .buttonStyle(ScorePanelButtonStyle())
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .disabled(game.matchPhase != .playing)
        .accessibilityLabel(team.displayName)
        .accessibilityValue("\(score) points")
        .accessibilityHint("Adds one point")
    }
}

private struct ScorePanelButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.78 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.08), value: configuration.isPressed)
    }
}

private struct MatchCompletionView: View {
    let winner: Team
    let games: [GameResult]
    let canUndo: Bool
    let undo: () -> Void
    let saveAndStartNew: () -> Void
    let saveAndFinish: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                Image(systemName: "trophy.fill")
                    .font(.title2)
                    .foregroundStyle(.yellow)

                Text("\(winner.displayName) Wins")
                    .font(.headline)
                    .multilineTextAlignment(.center)

                Text(games.map(\.displayScore).joined(separator: "  "))
                    .font(.subheadline)
                    .monospacedDigit()
                    .accessibilityLabel(
                        games
                            .enumerated()
                            .map { "Game \($0.offset + 1), \($0.element.scoreA) to \($0.element.scoreB)" }
                            .joined(separator: ", ")
                    )

                Button("Undo Last Point", action: undo)
                    .disabled(!canUndo)

                Button("Save & Start New Match", action: saveAndStartNew)
                    .buttonStyle(.borderedProminent)

                Button("Save & Finish", action: saveAndFinish)
            }
            .padding()
        }
    }
}

struct MatchHistoryView: View {
    @Binding var game: GameState
    @State private var showClearConfirmation = false

    var body: some View {
        Group {
            if game.matchHistory.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.title2)
                    Text("No Saved Matches")
                        .font(.headline)
                    Text("Confirmed matches will appear here.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
            } else {
                List {
                    ForEach(game.matchHistory.reversed()) { record in
                        MatchHistoryRow(record: record) {
                            game.deleteHistoryRecord(id: record.id)
                        }
                    }
                }
            }
        }
        .navigationTitle("History")
        .toolbar {
            if !game.matchHistory.isEmpty {
                ToolbarItem(placement: .destructiveAction) {
                    Button {
                        showClearConfirmation = true
                    } label: {
                        Image(systemName: "trash")
                    }
                    .accessibilityLabel("Clear match history")
                }
            }
        }
        .confirmationDialog(
            "Clear all match history?",
            isPresented: $showClearConfirmation,
            titleVisibility: .visible
        ) {
            Button("Clear History", role: .destructive) {
                game.clearMatchHistory()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This cannot be undone.")
        }
    }
}

private struct MatchHistoryRow: View {
    let record: MatchRecord
    let delete: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 3) {
                Text("\(record.winner.displayName) won")
                    .font(.headline)

                Text(record.games.map(\.displayScore).joined(separator: "  "))
                    .font(.caption)
                    .monospacedDigit()

                Text(record.playedAt, style: .date)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button(role: .destructive, action: delete) {
                Image(systemName: "trash")
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Delete match")
        }
        .accessibilityElement(children: .contain)
    }
}

private enum Haptics {
    static func pointScored() {
        #if os(watchOS)
        WKInterfaceDevice.current().play(.click)
        #endif
    }

    static func gameCompleted() {
        #if os(watchOS)
        WKInterfaceDevice.current().play(.directionUp)
        #endif
    }

    static func matchCompleted() {
        #if os(watchOS)
        WKInterfaceDevice.current().play(.success)
        #endif
    }

    static func undo() {
        #if os(watchOS)
        WKInterfaceDevice.current().play(.directionDown)
        #endif
    }
}
