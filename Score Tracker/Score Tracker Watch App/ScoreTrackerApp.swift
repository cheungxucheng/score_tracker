// Imports SwiftUI, Apple’s framework for declaring the app’s user interface.
import SwiftUI

// Compiles the following code only when this source is being built for watchOS.
#if os(watchOS)
// Imports WatchKit so the app can use Apple Watch-specific APIs such as haptic feedback.
import WatchKit
// Ends the watchOS-only conditional-compilation section.
#endif

// Marks the following app type as the program’s entry point.
@main
// Declares the ScoreTrackerApp value type; conforming to View makes it a SwiftUI screen or component.
struct ScoreTrackerApp: App {
    // Defines the app’s scene hierarchy; `some Scene` hides the concrete scene type while preserving compile-time type safety.
    var body: some Scene {
        // Creates the app’s main window scene and supplies its root view.
        WindowGroup {
            // WindowGroup is a type of scene that manages 1 <= app windows
            // Think of it as a container for the ui
            // Creates and displays the app’s home screen.
            HomeView()
        }
    }
}

// Declares the HomeView value type; conforming to View makes it a SwiftUI screen or component.
struct HomeView: View {
    // Stores view-owned mutable state and tells SwiftUI to refresh the view when the value changes.
    @State private var game = GameState()

    // Defines the visual content for this SwiftUI view; `some View` hides the exact composed view type.
    var body: some View {
        // Creates a navigation container so links can push new screens and display navigation titles.
        NavigationView {
            // Creates a vertically scrolling, watchOS-styled list.
            List {
                // Creates a tappable navigation row whose closure supplies the destination screen.
                NavigationLink {
                    // Creates the scoring screen and passes a binding, indicated by `$`, to the shared game state.
                    BadmintonView(game: $game)
                } label: {
                    // Creates a label that combines readable text with the named SF Symbol.
                    Label("Start Match", systemImage: "plus.circle.fill")
                }

                // Creates a tappable navigation row whose closure supplies the destination screen.
                NavigationLink {
                    // Creates the history screen and passes it the same mutable game-state binding.
                    MatchHistoryView(game: $game)
                } label: {
                    // Creates a label that combines readable text with the named SF Symbol.
                    Label("Match History", systemImage: "clock.arrow.circlepath")
                }
            }
            // Sets the title that watchOS displays in this screen’s navigation area.
            .navigationTitle("Badminton")
        }
    }
}

// Declares the BadmintonView value type; conforming to View makes it a SwiftUI screen or component.
struct BadmintonView: View {
    // Receives a two-way reference to state owned by another view, so changes flow back to the owner.
    @Binding var game: GameState
    // Reads a value supplied by SwiftUI’s environment; here it provides the action for dismissing this screen.
    @Environment(\.dismiss) private var dismiss
    // Stores view-owned mutable state and tells SwiftUI to refresh the view when the value changes.
    @State private var showDiscardConfirmation = false

    // Creates a computed binding that becomes true when the match is ready for confirmation.
    private var showMatchCompletion: Binding<Bool> {
        // Constructs a custom two-way SwiftUI binding from explicit getter and setter closures.
        Binding(
            // The binding reads its Boolean value by evaluating this getter closure.
            get: { game.matchPhase == .awaitingConfirmation },
            // The binding requires a setter, but this closure intentionally ignores attempted changes.
            set: { _ in }
        )
    }

    // Defines the visual content for this SwiftUI view; `some View` hides the exact composed view type.
    var body: some View {
        // Creates the live score interface and gives it two-way access to the current game state.
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
                // Supplies the dialog’s title text.
                "Discard the current match?",
                // Binds dialog or sheet presentation to the specified Boolean binding.
                isPresented: $showDiscardConfirmation,
                // Requests that the system show the dialog title.
                titleVisibility: .visible
            ) {
                // Creates a destructive dialog button and starts its action closure.
                Button("Discard Match", role: .destructive) {
                    // Resets and abandons the current unsaved match.
                    game.discardCurrentMatch()
                    // Asks SwiftUI to close the currently presented or pushed screen.
                    dismiss()
                }

                // Creates a cancel button with an intentionally empty action because dismissal is automatic.
                Button("Keep Playing", role: .cancel) {}
            } message: {
                // Creates a SwiftUI text view from the supplied string or value.
                Text("The unfinished match and its Undo history will be lost.")
            }
            // Presents a modal sheet whenever the supplied binding becomes true.
            .sheet(isPresented: showMatchCompletion) {
                // Safely unwraps the optional match winner and runs this block only when a winner exists.
                if let winner = game.matchWinner {
                    // Creates the modal screen used to confirm and save a completed match.
                    MatchCompletionView(
                        // Passes the unwrapped winning team into the completion screen.
                        winner: winner,
                        // Passes all completed game results into the completion screen.
                        games: game.completedGames,
                        // Passes whether an Undo operation is currently available.
                        canUndo: game.canUndo,
                        // Begins the callback the completion screen invokes to undo the last point.
                        undo: {
                            // Restores the game state saved immediately before the most recent point.
                            game.undoLastPoint()
                            // Plays the haptic pattern associated with undoing an action.
                            Haptics.undo()
                        // Supplies this argument or value and continues the surrounding multiline expression.
                        },
                        // Begins the callback that saves the result and starts another match.
                        saveAndStartNew: {
                            // Converts the finished match into a saved history record.
                            game.confirmCompletedMatch()
                            // Resets all active-match values for a new match.
                            game.startNewMatch()
                        // Supplies this argument or value and continues the surrounding multiline expression.
                        },
                        // Begins the callback that saves the result and exits the scoring screen.
                        saveAndFinish: {
                            // Converts the finished match into a saved history record.
                            game.confirmCompletedMatch()
                            // Resets all active-match values for a new match.
                            game.startNewMatch()
                            // Asks SwiftUI to close the currently presented or pushed screen.
                            dismiss()
                        }
                    )
                    // Prevents swiping the completion sheet away without choosing an explicit action.
                    .interactiveDismissDisabled()
                }
            }
    }
}

// Declares the ScoreView value type; conforming to View makes it a SwiftUI screen or component.
struct ScoreView: View {
    // Receives a two-way reference to state owned by another view, so changes flow back to the owner.
    @Binding var game: GameState

    // Declares a computed, file-internal string used to summarize the scores of finished games.
    private var completedScores: String {
        // Starts with the collection of games already completed in this match.
        game.completedGames
            // Transforms every collection element into the displayed value described by the key path or closure.
            .map(\.displayScore)
            // Combines the transformed strings using the supplied separator.
            .joined(separator: "  ")
    }

    // Defines the visual content for this SwiftUI view; `some View` hides the exact composed view type.
    var body: some View {
        // Layers the screen-level Undo wedge above the normal score interface.
        ZStack(alignment: .bottomTrailing) {
            // Arranges the header and score panels vertically.
            VStack(spacing: 4) {
                // Arranges the enclosed child views horizontally.
                HStack(spacing: 6) {
                    // Creates a SwiftUI text view from the supplied string or value.
                    Text("Game \(game.gameNum)")
                    // Applies the specified semantic system font style.
                        .font(.caption2)
                    // Changes the text weight to make it visually stronger.
                        .fontWeight(.semibold)
                    
                    // Shows the completed-game summary only when that string contains content.
                    if !completedScores.isEmpty {
                        // Adds flexible empty space that pushes neighboring content apart.
                        Spacer(minLength: 2)
                        // Creates a SwiftUI text view from the supplied string or value.
                        Text(completedScores)
                        // Applies the specified semantic system font style.
                            .font(.caption2)
                        // Limits this text to the specified number of rendered lines.
                            .lineLimit(1)
                        // Allows the text to shrink to this fraction of its normal size before truncating.
                            .minimumScaleFactor(0.65)
                    }
                }
                // Sets the foreground color or material for this view and its descendants.
                .foregroundStyle(.primary)
                // Proposes size and alignment constraints for this view.
                .frame(maxWidth: .infinity)
                // Adds empty space around the view using the specified edges and amount.
                .padding(.horizontal, 8)
                // Adds empty space around the view using the specified edges and amount.
                .padding(.vertical, 3)
                // Draws the specified color or style behind the view’s current bounds.
                .background(.gray.opacity(0.3))
                // Clips everything drawn by the view to the supplied shape.
                .clipShape(Capsule())
                // Controls how this view’s children are grouped for assistive technologies.
                .accessibilityElement(children: .combine)
                
                // Arranges the enclosed child views vertically.
                VStack(spacing: 2) {
                    // Calls the reusable helper that constructs one team’s score button.
                    scoreButton(
                        // Passes the team represented by this score button.
                        team: .teamA,
                        // Passes the current numeric score to display.
                        score: game.scoreA,
                        // Passes the background color associated with this team.
                        color: .red
                    )
                    // Clips everything drawn by the view to the supplied shape.
                    .clipShape(
                        // Creates a rectangle with the given smooth corner radius.
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                    )
                    
                    // Calls the reusable helper that constructs Team B's score button.
                    scoreButton(
                        // Passes the team represented by this score button.
                        team: .teamB,
                        // Passes the current numeric score to display.
                        score: game.scoreB,
                        // Passes the background color associated with this team.
                        color: .blue
                    )
                    // Clips Team B's score panel to its rounded rectangle.
                    .clipShape(
                        // Uses the same smooth rounded rectangle as Team A's panel.
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                    )
                }
                // Proposes size and alignment constraints for this view.
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            // Adds empty space between the score interface and the screen's horizontal edges.
            .padding(.horizontal, 4)

            // Creates the Undo wedge at the lower-right edge of the entire Watch screen.
            Button {
                // Restores the state from before the most recent point.
                game.undoLastPoint()
                // Plays tactile confirmation that Undo succeeded.
                Haptics.undo()
            } label: {
                // Layers the wedge fill, curved border, and Undo symbol.
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
                // Anchors the circle's geometry at the lower-right corner without limiting its drawing.
                .frame(width: 60, height: 60)
            }
            // Prevents watchOS from drawing a second system button background.
            .buttonStyle(.plain)
            // Lowers the complete circular control so the physical Watch edge clips its bottom.
            .offset(x: -20, y: 10)
            // Disables Undo when no previous scoring state exists.
            .disabled(!game.canUndo)
            // Provides a concise spoken name for VoiceOver.
            .accessibilityLabel("Undo last point")
            // Explains to VoiceOver users what activating the control will do.
            .accessibilityHint("Restores the score before the most recent point")
        }
    }

    // Declares a private helper function that returns a reusable score-button view.
    private func scoreButton(
        // Passes the team represented by this score button.
        team: Team,
        // Passes the current numeric score to display.
        score: Int,
        // Passes the background color associated with this team.
        color: Color
    // Ends the parameter list and declares that the function returns an opaque SwiftUI view.
    ) -> some View {
        // Creates a button and begins the closure that runs when the user taps it.
        Button {
            // Captures the current completed-game count so the code can detect whether this tap finished a game.
            let completedGameCount = game.completedGames.count
            // Tells the game model that this team won a point.
            game.pointWon(by: team)

            // Checks whether scoring this point completed the entire match.
            if game.matchPhase == .awaitingConfirmation {
                // Plays the success haptic used for a completed match.
                Haptics.matchCompleted()
            // Otherwise, checks whether the point increased the completed-game count.
            } else if game.completedGames.count > completedGameCount {
                // Plays an upward-direction haptic to signal a completed game.
                Haptics.gameCompleted()
            // Begins the fallback branch when the preceding conditions are false.
            } else {
                // Plays a light click for an ordinary scored point.
                Haptics.pointScored()
            }
        // Ends the action or destination closure and begins the closure that describes the control’s visible label.
        } label: {
            // Arranges the enclosed child views vertically.
            VStack(spacing: 2) {
                // Creates a SwiftUI text view from the supplied string or value.
                Text(team.displayName)
                    // Applies the specified semantic system font style.
                    .font(.caption2)
                    // Changes the text weight to make it visually stronger.
                    .fontWeight(.semibold)

                // Creates a SwiftUI text view from the supplied string or value.
                Text("\(score)")
                    // Applies the specified semantic system font style.
                    .font(.title)
                    // Changes the text weight to make it visually stronger.
                    .fontWeight(.bold)
                    // Uses equal-width digits so changing scores do not make the layout jump.
                    .monospacedDigit()
            }
            // Sets the foreground color or material for this view and its descendants.
            .foregroundStyle(.white)
            // Proposes size and alignment constraints for this view.
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            // Defines the shape SwiftUI uses for hit testing this control.
            .contentShape(Rectangle())
            // Draws the specified color or style behind the view’s current bounds.
            .background(color)
        }
        // Applies the specified visual and interaction style to the button.
        .buttonStyle(ScorePanelButtonStyle())
        // Proposes size and alignment constraints for this view.
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // Disables interaction when this Boolean condition evaluates to true.
        .disabled(game.matchPhase != .playing)
        // Provides a concise spoken name for VoiceOver.
        .accessibilityLabel(team.displayName)
        // Provides VoiceOver with the control’s current value.
        .accessibilityValue("\(score) points")
        // Explains to VoiceOver users what activating the control will do.
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
