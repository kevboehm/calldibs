import SwiftUI

/// Builds the screen for a route and decides where each screen leads next.
struct RouteDestination: View {
    let route: Route
    let flow: AppFlow

    var body: some View {
        if let session = flow.session {
            switch route {
            case .edit:
                ReceiptSummaryView(session: session) { flow.path.append(.name) }
            case .name:
                NameEntryView(session: session) {
                    session.confirmName()
                    flow.path.append(.claim(.swipe))
                } onShowSplit: {
                    session.endTurn()
                    flow.path = [.overview]
                }
            case .claim(let mode):
                ClaimView(session: session, mode: mode) { flow.path.append(.summary) }
            case .summary:
                // The split sits under each new turn, so Back from the name
                // screen leads to where earlier people can be edited.
                MiniReceiptView(session: session) {
                    session.endTurn()
                    flow.path = [.overview, .name]
                } onFinish: {
                    session.endTurn()
                    flow.path = [.overview]
                }
            case .overview:
                SplitOverviewView(session: session) {
                    session.endTurn()
                    flow.path = [.overview, .name]
                } onEdit: { person in
                    session.beginEditing(person)
                    flow.path = [.overview, .name]
                } onNewBill: {
                    flow.path.removeAll()
                }
            }
        }
    }
}
