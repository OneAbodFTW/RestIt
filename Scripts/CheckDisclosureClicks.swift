// Requires a macOS GUI session. Sends local events to its own fixture window.
// swiftc -parse-as-library RestIt/DetailsDisclosureStyle.swift Scripts/CheckDisclosureClicks.swift -o /tmp/restit-disclosure-check
import AppKit
import SwiftUI
import Combine

@MainActor final class ExpansionState: ObservableObject {
    @Published var expanded = false
}
struct DisclosureFixture: View {
    @ObservedObject var state: ExpansionState
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            DisclosureGroup("Explanation details", isExpanded: $state.expanded) {
                Text("Expanded explanation").frame(maxWidth: .infinity, alignment: .leading)
            }
            Spacer(minLength: 0)
        }
        .padding(20)
        .frame(width: 400, height: 200)
        .disclosureGroupStyle(DetailsDisclosureStyle())
    }
}
@main struct Check {
    @MainActor static func main() {
        let app = NSApplication.shared
        let state = ExpansionState()
        let window = NSWindow(contentRect: NSRect(x: 100, y: 100, width: 400, height: 200), styleMask: [.titled], backing: .buffered, defer: false)
        window.contentView = NSHostingView(rootView: DisclosureFixture(state: state))
        window.makeKeyAndOrderFront(nil)
        func settle() { RunLoop.main.run(until: Date().addingTimeInterval(0.15)) }
        func click(_ x: CGFloat, _ y: CGFloat) {
            for type in [NSEvent.EventType.leftMouseDown, .leftMouseUp] {
                let event = NSEvent.mouseEvent(with: type, location: NSPoint(x: x, y: y), modifierFlags: [], timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: window.windowNumber, context: nil, eventNumber: 1, clickCount: 1, pressure: 1)!
                window.sendEvent(event)
            }
            settle()
        }
        settle()
        click(100, 170)
        precondition(state.expanded, "Clicking the title must expand the explanation")
        click(100, 170)
        precondition(!state.expanded, "Clicking the title again must collapse the explanation")
        state.expanded = false
        settle()
        click(27, 170)
        precondition(state.expanded, "The arrow must still expand the explanation")
        state.expanded = false
        settle()
        click(350, 170)
        precondition(state.expanded, "The full row must expand the explanation")
        click(350, 170)
        precondition(!state.expanded, "The full row must collapse the explanation")
        print("Disclosure click checks passed: title, arrow, row whitespace, expand, and collapse.")
        window.orderOut(nil)
        _ = app
    }
}
