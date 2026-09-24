import SwiftUI

#if os(watchOS)
// Imports WatchKit so the app can use Apple Watch-specific APIs such as haptic feedback.
import WatchKit
#endif

@main
struct ScoreTrackerApp: App {
    var body: some Scene {
        WindowGroup {
            // WindowGroup is a type of scene that manages 1 <= app windows
            // Think of it as a container for the ui
            // Creates and displays the app’s home screen.
            HomeView()
        }
    }
}

#Preview() {
    HomeView()
}
struct HomeView: View {
    @State private var game = GameState()
    @State private var numsGames: NumGames = .bo3
    @State private var showingMatch = false

    var body: some View {
        NavigationView {
            List {
                HStack() {
                    Text("Best Of : ")
                        .font(.body)
                    Spacer()
                    
                    Picker("Best of :", selection: $numsGames) {
                        ForEach(NumGames.allCases) { num in
                            Text("\(num.rawValue)").tag(num)
                        }
                    }
                    .pickerStyle(.wheel)
                    .labelsHidden()
                    .frame(width: 50, height: 50)
                    .clipped()
                }
                
                Button {
                    game.startNewMatch(format: numsGames)
                    showingMatch = true
                } label: {
                    // Creates a label that combines readable text with the named SF Symbol.
                    Label("Start Match", systemImage: "plus.circle.fill")
                }
                .background {
                    NavigationLink(
                        destination: BadmintonView(game: $game),
                        isActive: $showingMatch
                    ) {
                        EmptyView()
                    }
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
            // The binding reads its Boolean value by evaluating this getter closure.
            get: { game.matchPhase == .awaitingConfirmation },
            // The binding requires a setter, but this closure intentionally ignores attempted changes.
            set: { _ in }
        )
    }

    var body: some View {
        ScoreView(game: $game)
            // Hides the standard Back button while a match has progress, preventing accidental abandonment.
            .navigationBarBackButtonHidden(game.hasActiveMatchProgress)
            // Adds controls to the system-managed navigation toolbar.
            .toolbar {
                if game.hasActiveMatchProgress {
                    ToolbarItem(placement: .cancellationAction) {
                        Button {
                            showDiscardConfirmation = true
                        } label: {
                            Image(systemName: "xmark")
                        }
                    }
                }
            }
            // Attaches a confirmation dialog to the view.
            .confirmationDialog(
                "Discard the current match?",
                isPresented: $showDiscardConfirmation,
                titleVisibility: .visible
            ) {
                Button("Discard Match", role: .destructive) {
                    game.discardCurrentMatch()
                    // Asks SwiftUI to close the currently presented or pushed screen.
                    dismiss()
                }

                // Creates a cancel button with an intentionally empty action because dismissal is automatic.
                Button("Keep Playing", role: .cancel) {}
            } message: {
                Text("The unfinished match and its Undo history will be lost.")
            }
            .sheet(isPresented: showMatchCompletion) {
                if let winner = game.matchWinner {
                    // Creates the modal screen used to confirm and save a completed match.
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
                            game.startNewMatch(format: game.matchFormat)
                        },
                        saveAndFinish: {
                            game.confirmCompletedMatch()
                            game.startNewMatch(format: game.matchFormat)
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
            // Transforms every collection element into the displayed value described by the key path or closure.
            .map(\.displayScore)
            // Combines the transformed strings using the supplied separator.
            .joined(separator: "  ")
    }

    var body: some View {
        // Layers the screen-level Undo wedge above the normal score interface.
        ZStack(alignment: .bottomTrailing) {
            VStack(spacing: 4) {
                HStack(spacing: 6) {
                    Text("Game \(game.gameNum)")
                        .font(.caption2)
                        .fontWeight(.semibold)
                    
                    if !completedScores.isEmpty {
                        // Adds flexible empty space that pushes neighboring content apart.
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
                    .clipShape(
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                    )
                    
                    scoreButton(
                        team: .teamB,
                        score: game.scoreB,
                        color: .blue
                    )
                    .clipShape(
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                    )
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .padding(.horizontal, 4)

            Button {
                game.undoLastPoint()
                // Plays tactile confirmation that Undo succeeded.
                Haptics.undo()
            } label: {
                ZStack {
                    // Reads the fixed square used to reveal one quarter of the larger circle.
                    GeometryReader { geometry in
                        // Draws a circle whose center sits at the square's bottom-right corner.
                        Circle()
                            // Makes the active wedge prominent and the unavailable wedge subdued.
                            .fill(.gray.opacity(game.canUndo ? 0.9 : 0.9))
                            // Makes the circle twice the width and height of the visible square.
                            .frame(
                                width: geometry.size.width * 1,
                                height: geometry.size.height * 1
                            )
                            // Places the circle's center on the screen's lower-right corner.
                            .position(
                                x: geometry.size.width,
                                y: geometry.size.height
                            )

                        // Draws the same quarter-circle geometry as a subtle dividing line.
                        Circle()
                            .stroke(.white.opacity(0.25), lineWidth: 1)
                            .frame(
                                width: geometry.size.width * 1,
                                height: geometry.size.height * 1
                            )
                            .position(
                                x: geometry.size.width,
                                y: geometry.size.height
                            )
                    }

                    // Displays the Undo symbol near the visual center of the wedge.
                    Image(systemName: "arrow.uturn.backward")
                        .font(.title2)
                        .offset(x: 25, y: 25)
                }
                .frame(width: 60, height: 60)
            }
            .buttonStyle(.plain)
            // Lowers the complete circular control so the physical Watch edge clips its bottom.
            .offset(x: -20, y: 10)
            .disabled(!game.canUndo)
            .accessibilityLabel("Undo last point")
            .accessibilityHint("Restores the score before the most recent point")
        }
    }

    private func scoreButton(
        team: Team,
        score: Int,
        color: Color
    ) -> some View {
        Button {
            let completedGameCount = game.completedGames.count
            game.pointWon(by: team)

            // Checks whether scoring this point completed the entire match.
            if game.matchPhase == .awaitingConfirmation {
                Haptics.matchCompleted()
            // Else if completed a game
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
                    .font(.title)
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

#Preview {
    @Previewable @State var game = GameState()
    ScoreView(game: $game)
}
// Declares a file-private ScorePanelButtonStyle value type that can only be used in this file.
private struct ScorePanelButtonStyle: ButtonStyle {
    // Implements ButtonStyle’s requirement and receives the button’s current interaction configuration.
    func makeBody(configuration: Configuration) -> some View {
        // Starts with the label supplied by the button using this style.
        configuration.label
            // Adjusts visibility by choosing an opacity from the current state.
            .opacity(configuration.isPressed ? 0.78 : 1)
            // Slightly scales the button while pressed to provide visual feedback.
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            // Animates changes to the pressed state with a short easing curve.
            .animation(.easeOut(duration: 0.08), value: configuration.isPressed)
    }
}

// Declares a file-private MatchCompletionView value type that can only be used in this file.
private struct MatchCompletionView: View {
    // Stores the winning team supplied when this view is created.
    let winner: Team
    // Stores the completed game results supplied to this view.
    let games: [GameResult]
    // Stores whether the completion view should enable its Undo button.
    let canUndo: Bool
    // Stores a no-argument callback that performs Undo.
    let undo: () -> Void
    // Stores the callback for saving and immediately starting another match.
    let saveAndStartNew: () -> Void
    // Stores the callback for saving and leaving the scoring screen.
    let saveAndFinish: () -> Void

    // Defines the visual content for this SwiftUI view; `some View` hides the exact composed view type.
    var body: some View {
        // Creates vertically scrollable content for small Watch displays.
        ScrollView {
            // Arranges the enclosed child views vertically.
            VStack(spacing: 12) {
                // Displays the specified SF Symbol as an image.
                Image(systemName: "trophy.fill")
                    // Applies the specified semantic system font style.
                    .font(.title2)
                    // Sets the foreground color or material for this view and its descendants.
                    .foregroundStyle(.yellow)

                // Creates a SwiftUI text view from the supplied string or value.
                Text("\(winner.displayName) Wins")
                    // Applies the specified semantic system font style.
                    .font(.headline)
                    // Centers text when it wraps across multiple lines.
                    .multilineTextAlignment(.center)

                // Creates a SwiftUI text view from the supplied string or value.
                Text(games.map(\.displayScore).joined(separator: "  "))
                    // Applies the specified semantic system font style.
                    .font(.subheadline)
                    // Uses equal-width digits so changing scores do not make the layout jump.
                    .monospacedDigit()
                    // Provides a concise spoken name for VoiceOver.
                    .accessibilityLabel(
                        // Executes this statement as part of the surrounding view or action.
                        games
                            // Pairs each game with its zero-based position so the accessibility text can number it.
                            .enumerated()
                            // Applies another SwiftUI modifier or collection operation to the value created above.
                            .map { "Game \($0.offset + 1), \($0.element.scoreA) to \($0.element.scoreB)" }
                            // Combines the transformed strings using the supplied separator.
                            .joined(separator: ", ")
                    )

                // Creates a button wired directly to the supplied Undo callback.
                Button("Undo Last Point", action: undo)
                    // Disables interaction when this Boolean condition evaluates to true.
                    .disabled(!canUndo)

                // Creates a button wired to the save-and-start-new callback.
                Button("Save & Start New Match", action: saveAndStartNew)
                    // Applies the specified visual and interaction style to the button.
                    .buttonStyle(.borderedProminent)

                // Creates a button wired to the save-and-finish callback.
                Button("Save & Finish", action: saveAndFinish)
            }
            // Adds empty space around the view using the specified edges and amount.
            .padding()
        }
    }
}

// Declares the MatchHistoryView value type; conforming to View makes it a SwiftUI screen or component.
struct MatchHistoryView: View {
    // Receives a two-way reference to state owned by another view, so changes flow back to the owner.
    @Binding var game: GameState
    // Stores view-owned mutable state and tells SwiftUI to refresh the view when the value changes.
    @State private var showClearConfirmation = false

    // Defines the visual content for this SwiftUI view; `some View` hides the exact composed view type.
    var body: some View {
        // Groups conditional content without adding its own visible layout container.
        Group {
            // Chooses the empty-state interface when no matches have been saved.
            if game.matchHistory.isEmpty {
                // Arranges the enclosed child views vertically.
                VStack(spacing: 8) {
                    // Displays the specified SF Symbol as an image.
                    Image(systemName: "clock.arrow.circlepath")
                        // Applies the specified semantic system font style.
                        .font(.title2)
                    // Creates a SwiftUI text view from the supplied string or value.
                    Text("No Saved Matches")
                        // Applies the specified semantic system font style.
                        .font(.headline)
                    // Creates a SwiftUI text view from the supplied string or value.
                    Text("Confirmed matches will appear here.")
                        // Applies the specified semantic system font style.
                        .font(.caption)
                        // Sets the foreground color or material for this view and its descendants.
                        .foregroundStyle(.secondary)
                        // Centers text when it wraps across multiple lines.
                        .multilineTextAlignment(.center)
                }
                // Adds empty space around the view using the specified edges and amount.
                .padding()
            // Begins the fallback branch when the preceding conditions are false.
            } else {
                // Creates a vertically scrolling, watchOS-styled list.
                List {
                    // Creates one child row for every saved match, iterating newest records first.
                    ForEach(game.matchHistory.reversed()) { record in
                        // Creates the visual row for this saved match record.
                        MatchHistoryRow(record: record) {
                            // Deletes the selected record from memory and persistent storage.
                            game.deleteHistoryRecord(id: record.id)
                        }
                    }
                }
            }
        }
        // Sets the title that watchOS displays in this screen’s navigation area.
        .navigationTitle("History")
        // Adds controls to the system-managed navigation toolbar.
        .toolbar {
            // Places a custom toolbar item in the platform-appropriate location specified here.
            ToolbarItem(placement: .destructiveAction) {
                // Creates a button and begins the closure that runs when the user taps it.
                Button {
                    // Changes state to present the clear-history confirmation dialog.
                    showClearConfirmation = true
                // Ends the action or destination closure and begins the closure that describes the control’s visible label.
                } label : {
                    // Displays the specified SF Symbol as an image.
                    Image(systemName: "trash")
                }
                // Disables interaction when this Boolean condition evaluates to true.
                .disabled(game.matchHistory.isEmpty)
                // Adjusts visibility by choosing an opacity from the current state.
                .opacity(game.hasActiveMatchProgress ? 0 : 1)
                // Removes the control from assistive technologies when it is not meant to be available.
                .accessibilityHidden(!game.matchHistory.isEmpty)
            }
        }
        // Attaches a confirmation dialog to the view.
        .confirmationDialog(
            // Supplies the history-clearing dialog’s title text.
            "Clear all match history?",
            // Binds dialog or sheet presentation to the specified Boolean binding.
            isPresented: $showClearConfirmation,
            // Requests that the system show the dialog title.
            titleVisibility: .visible
        // Begins the scope or closure introduced by this line.
        ) {
            // Begins the scope or closure introduced by this line.
            Button("Clear History", role: .destructive) {
                // Deletes every saved match and persists the empty history.
                game.clearMatchHistory()
            }
            // Executes this statement as part of the surrounding view or action.
            Button("Cancel", role: .cancel) {}
        // Ends the dialog actions and begins the closure that supplies explanatory message text.
        } message: {
            // Creates a SwiftUI text view from the supplied string or value.
            Text("This cannot be undone.")
        }
    }
}

// Declares a file-private MatchHistoryRow value type that can only be used in this file.
private struct MatchHistoryRow: View {
    // Stores the match record this row will display.
    let record: MatchRecord
    // Stores the callback used to delete this row’s match.
    let delete: () -> Void

    // Defines the visual content for this SwiftUI view; `some View` hides the exact composed view type.
    var body: some View {
        // Arranges the enclosed child views horizontally.
        HStack(alignment: .top, spacing: 8) {
            // Arranges the enclosed child views vertically.
            VStack(alignment: .leading, spacing: 3) {
                // Creates a SwiftUI text view from the supplied string or value.
                Text("\(record.winner.displayName) won")
                    // Applies the specified semantic system font style.
                    .font(.headline)

                // Creates a SwiftUI text view from the supplied string or value.
                Text(record.games.map(\.displayScore).joined(separator: "  "))
                    // Applies the specified semantic system font style.
                    .font(.caption)
                    // Uses equal-width digits so changing scores do not make the layout jump.
                    .monospacedDigit()

                // Creates a SwiftUI text view from the supplied string or value.
                Text(record.playedAt, style: .date)
                    // Applies the specified semantic system font style.
                    .font(.caption2)
                    // Sets the foreground color or material for this view and its descendants.
                    .foregroundStyle(.secondary)
            }
            // Proposes size and alignment constraints for this view.
            .frame(maxWidth: .infinity, alignment: .leading)

            // Creates a destructive button whose action and label are supplied by closures.
            Button(role: .destructive, action: delete) {
                // Displays the specified SF Symbol as an image.
                Image(systemName: "trash")
            }
            // Applies the specified visual and interaction style to the button.
            .buttonStyle(.plain)
            // Provides a concise spoken name for VoiceOver.
            .accessibilityLabel("Delete match")
        }
        // Controls how this view’s children are grouped for assistive technologies.
        .accessibilityElement(children: .contain)
    }
}


// Declares a file-private Haptics namespace for related static functionality.
private enum Haptics {
    // Defines the haptic feedback used after an ordinary point.
    static func pointScored() {
        // Compiles the following code only when this source is being built for watchOS.
        #if os(watchOS)
        // Gets the current Watch hardware interface and asks it to play the specified haptic.
        WKInterfaceDevice.current().play(.click)
        // Ends the watchOS-only conditional-compilation section.
        #endif
    }

    // Defines the haptic feedback used when a game ends.
    static func gameCompleted() {
        // Compiles the following code only when this source is being built for watchOS.
        #if os(watchOS)
        // Gets the current Watch hardware interface and asks it to play the specified haptic.
        WKInterfaceDevice.current().play(.directionUp)
        // Ends the watchOS-only conditional-compilation section.
        #endif
    }

    // Defines the success feedback used when an entire match ends.
    static func matchCompleted() {
        // Compiles the following code only when this source is being built for watchOS.
        #if os(watchOS)
        // Gets the current Watch hardware interface and asks it to play the specified haptic.
        WKInterfaceDevice.current().play(.success)
        // Ends the watchOS-only conditional-compilation section.
        #endif
    }

    // Defines the downward-direction feedback used for Undo.
    static func undo() {
        // Compiles the following code only when this source is being built for watchOS.
        #if os(watchOS)
        // Gets the current Watch hardware interface and asks it to play the specified haptic.
        WKInterfaceDevice.current().play(.directionDown)
        // Ends the watchOS-only conditional-compilation section.
        #endif
    }
}
