import SwiftUI
import PhotosUI
import DibsCore

struct HomeView: View {
    @State private var scan = ScanViewModel()
    @State private var flow = AppFlow()

    @Environment(\.scenePhase) private var scenePhase

    @State private var showSourceDialog = false
    @State private var showCamera = false
    @State private var showPhotoPicker = false
    @State private var photoItem: PhotosPickerItem?

    @State private var showHistory = false
    @State private var hasHistory = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// The logo stamps itself onto the screen the first time it shows.
    @State private var stamped = false

    var body: some View {
        NavigationStack(path: $flow.path) {
            ScrollView {
                VStack(spacing: Theme.Spacing.large) {
                    ZStack {
                        if stamped {
                            DibsStamp(text: "DIBS", size: 60)
                                .transition(reduceMotion ? .opacity : .scale(scale: 2.6).combined(with: .opacity))
                        }
                    }
                    .frame(height: 128)
                    .onAppear {
                        withAnimation(Theme.Motion.stamp) { stamped = true }
                    }
                    .sensoryFeedback(.impact(weight: .heavy), trigger: stamped)

                    VStack(spacing: Theme.Spacing.small) {
                        Text("Call Dibs")
                            .font(.largeTitle.bold())
                        Text("Split the bill by what each person actually had.")
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.secondary)
                    }

                    VStack(alignment: .leading, spacing: Theme.Spacing.medium) {
                        HomeStep(symbol: "camera.viewfinder", title: "Scan", detail: "Photograph the receipt. It's read on your phone.")
                            .printIn(index: 3)
                        HomeStep(symbol: "hand.draw", title: "Call dibs", detail: "Swipe right on what was yours.")
                            .printIn(index: 6)
                        HomeStep(symbol: "arrow.triangle.2.circlepath", title: "Pass it on", detail: "Hand the phone around until the bill is covered.")
                            .printIn(index: 9)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(Theme.Spacing.medium)
                    .padding(.bottom, Theme.Spacing.small)
                    .paperCard()
                    .padding(.top, Theme.Spacing.small)

                }
                .padding(Theme.Spacing.large)
                .padding(.top, Theme.Spacing.xLarge)
            }
            .scrollBounceBehavior(.basedOnSize)
            .actionBar {
                VStack(spacing: Theme.Spacing.medium) {
                    PrimaryButton("Scan a receipt", systemImage: "camera.fill") {
                        showSourceDialog = true
                    }
                    .disabled(scan.isParsing)

                    if hasHistory {
                        Button("History", systemImage: "clock.arrow.circlepath") { showHistory = true }
                    }
                }
            }
            .paperScreen()
            .overlay {
                if scan.isParsing {
                    ZStack {
                        Theme.Palette.ground.opacity(0.7)
                            .ignoresSafeArea()
                        ReadingReceiptCard()
                    }
                    .transition(.opacity)
                }
            }
            .animation(.smooth, value: scan.isParsing)
            .sheet(isPresented: $showHistory, onDismiss: refreshHistory) {
                HistoryView(onOpen: flow.reopen)
            }
            .onAppear(perform: restoreBill)
            .onAppear(perform: refreshHistory)
            .onChange(of: scenePhase) { saveBill() }
            .onChange(of: flow.path) {
                saveBill()
                refreshHistory()
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willTerminateNotification)) { _ in
                flow.archive()
                discardBill()
            }
            .navigationDestination(for: Route.self) { route in
                RouteDestination(route: route, flow: flow)
            }
            .confirmationDialog("Scan a receipt", isPresented: $showSourceDialog) {
                if CameraPicker.isAvailable {
                    Button("Take a photo") { showCamera = true }
                }
                Button("Choose from library") { showPhotoPicker = true }
                Button("Enter items manually") { flow.start(with: Receipt()) }
            }
            .fullScreenCover(isPresented: $showCamera) {
                CameraPicker { image in
                    Task { await handle(image) }
                } onError: { error in
                    scan.errorMessage = "The camera couldn't scan that: \(error.localizedDescription)"
                }
                .ignoresSafeArea()
            }
            .photosPicker(isPresented: $showPhotoPicker, selection: $photoItem, matching: .images)
            .onChange(of: photoItem) { _, item in
                guard let item else { return }
                photoItem = nil
                Task { await load(item) }
            }
            .alert("Couldn't read that receipt", isPresented: errorIsPresented) {
                Button("Enter items manually") { flow.start(with: Receipt()) }
                Button("OK", role: .cancel) {}
            } message: {
                Text(scan.errorMessage ?? "")
            }
        }
    }

    // A bill in progress is written to disk as it changes, so it survives
    // the app being closed, evicted in the background, or crashing. iOS only
    // sometimes tells an app it is being terminated (never once suspended),
    // so clearing on that notice is best effort; "Start a new bill" is the
    // dependable way to put one away. Either way a bill that anyone called
    // dibs on goes to History first.
    private func restoreBill() {
        #if DEBUG
        // Lets UI tests start from a clean home screen.
        if ProcessInfo.processInfo.arguments.contains("-resetBill") {
            BillStore.clear()
            HistoryStore.clear()
            return
        }
        if let path = UserDefaults.standard.string(forKey: "seedScan"), flow.session == nil {
            // `-seedScan <image path>` scans a photo on launch, to check the
            // whole scan without the camera or the photo picker.
            if let image = UIImage(contentsOfFile: path) { Task { await handle(image) } }
            return
        }
        #endif
        if let saved = BillStore.load() { flow.restore(from: saved, scanImage: BillStore.loadScan()) }
    }

    private func saveBill() {
        BillStore.save(flow.savedState)
    }

    private func discardBill() {
        BillStore.clear()
    }

    private func refreshHistory() {
        hasHistory = !HistoryStore.isEmpty
    }

    private var errorIsPresented: Binding<Bool> {
        Binding(
            get: { scan.errorMessage != nil },
            set: { if !$0 { scan.errorMessage = nil } }
        )
    }

    private func load(_ item: PhotosPickerItem) async {
        guard let data = try? await item.loadTransferable(type: Data.self),
              let image = UIImage(data: data) else {
            scan.errorMessage = ReceiptParserError.unreadableImage.localizedDescription
            return
        }
        await handle(image)
    }

    private func handle(_ image: UIImage) async {
        if let scanned = await scan.parse(image) {
            flow.start(with: scanned)
            let photo = scanned.image
            Task.detached(priority: .utility) { BillStore.saveScan(photo) }
        }
    }
}

#Preview {
    HomeView()
}
