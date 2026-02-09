//
//  ContentView.swift
//  iris
//
//  Created by David Nintang on 2/8/26.
//

import SwiftUI
import UserNotifications

#if canImport(UIKit)
import UIKit
#endif

#if canImport(AudioToolbox)
import AudioToolbox
#endif

struct ContentView: View {
    @State private var selectedFilter: RequestFilter = .all
    @State private var selectedResident: ResidentProfileContext?
    @State private var requests: [AssistanceRequest] = [
        AssistanceRequest(
            residentName: "Evelyn Carter",
            room: "A-203",
            requestType: "Medication Reminder",
            avatarURL: URL(string: "https://upload.wikimedia.org/wikipedia/commons/thumb/d/dc/Cicely_Tyson_1973.jpg/330px-Cicely_Tyson_1973.jpg"),
            urgency: .high,
            status: .pending,
            timeAgo: "2m ago",
            note: "Missed evening pill window."
        ),
        AssistanceRequest(
            residentName: "Samuel Brooks",
            room: "B-112",
            requestType: "Water Refill",
            avatarURL: URL(string: "https://upload.wikimedia.org/wikipedia/commons/thumb/b/b5/Morgan_Freeman%2C_2006.jpg/250px-Morgan_Freeman%2C_2006.jpg"),
            urgency: .normal,
            status: .attended,
            timeAgo: "6m ago",
            note: "Cup is empty."
        ),
        AssistanceRequest(
            residentName: "Grace Mensah",
            room: "C-021",
            requestType: "Bathroom Assistance",
            avatarURL: URL(string: "https://upload.wikimedia.org/wikipedia/commons/thumb/b/b6/Angela_Bassett.jpg/326px-Angela_Bassett.jpg"),
            urgency: .critical,
            status: .resolved,
            timeAgo: "1m ago",
            note: "Completed with caregiver support."
        ),
        AssistanceRequest(
            residentName: "Harold King",
            room: "A-118",
            requestType: "Adjust Bed Position",
            avatarURL: URL(string: "https://upload.wikimedia.org/wikipedia/commons/thumb/3/3e/Denzel_Washington.jpg/239px-Denzel_Washington.jpg"),
            urgency: .normal,
            status: .pending,
            timeAgo: "9m ago",
            note: "Back discomfort reported."
        )
    ]
    @State private var bannerText: String?
    private let notificationManager = DemoNotificationManager.shared

    private var filteredRequests: [AssistanceRequest] {
        requests.filter { selectedFilter.matches($0.status) }
    }

    private var pendingCount: Int {
        requests.filter { $0.status == .pending }.count
    }

    private var criticalCount: Int {
        requests.filter { $0.urgency == .critical }.count
    }

    var body: some View {
        NavigationStack {
            ZStack {
                ambientBackground

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 14) {
                        header
                        summaryCards
                        filterPicker
                        requestList
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 14)
                    .padding(.bottom, 28)
                }

                if let bannerText {
                    VStack {
                        Text(bannerText)
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(Color.black.opacity(0.72), in: Capsule())
                            .padding(.top, 10)
                        Spacer()
                    }
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .animation(.easeInOut(duration: 0.25), value: bannerText)
            .task {
                await notificationManager.requestAuthorizationIfNeeded()
            }
        }
        .sheet(item: $selectedResident) { context in
            ResidentProfileView(context: context)
        }
    }

    private var ambientBackground: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.92, green: 0.96, blue: 0.99),
                    Color(red: 0.89, green: 0.94, blue: 0.97),
                    Color(red: 0.94, green: 0.97, blue: 0.95)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            RadialGradient(
                colors: [Color.white.opacity(0.62), .clear],
                center: .topLeading,
                startRadius: 12,
                endRadius: 300
            )
            .offset(x: -50, y: -40)

            RadialGradient(
                colors: [Color.cyan.opacity(0.20), .clear],
                center: .bottomTrailing,
                startRadius: 20,
                endRadius: 260
            )
            .offset(x: 70, y: 120)
        }
        .ignoresSafeArea()
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 7) {
                Text("IRIS Caregiver Console")
                    .font(.title3.weight(.bold))
                Text("Monitor eye-triggered assistance requests from residents.")
                    .font(.subheadline)
                    .foregroundStyle(Color.primary.opacity(0.78))
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 8) {
                Button {
                    simulateIncomingRequest()
                } label: {
                    Label("Simulate Alert", systemImage: "bell.badge.fill")
                        .font(.caption.weight(.semibold))
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.capsule)
                .tint(.teal)

                Label("Live", systemImage: "dot.radiowaves.left.and.right")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.green)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.green.opacity(0.16), in: Capsule())

                Text("\(requests.count) requests")
                    .font(.caption)
                    .foregroundStyle(Color.primary.opacity(0.76))
            }
        }
        .padding(14)
        .glassPanel(cornerRadius: 22)
    }

    private func simulateIncomingRequest() {
        let simulated = AssistanceRequest.randomPending()
        requests.insert(simulated, at: 0)
        if requests.count > 40 {
            requests.removeLast(requests.count - 40)
        }
        selectedFilter = .all

        bannerText = "New request from \(simulated.residentName)"
        Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            await MainActor.run {
                bannerText = nil
            }
        }

        notificationManager.playImmediateAlertFeedback()
        notificationManager.scheduleIncomingRequestNotification(for: simulated)
    }

    private func openResidentProfile(for request: AssistanceRequest) {
        let history = requests.filter { $0.residentName == request.residentName }
        let profile = ResidentProfile.profile(for: request)
        selectedResident = ResidentProfileContext(profile: profile, history: history)
    }

    private var summaryCards: some View {
        let columns = [GridItem(.adaptive(minimum: 108), spacing: 10)]

        return LazyVGrid(columns: columns, spacing: 10) {
            SummaryCard(
                title: "Pending",
                value: "\(pendingCount)",
                icon: "clock.badge.exclamationmark",
                tint: .orange
            )
            SummaryCard(
                title: "Critical",
                value: "\(criticalCount)",
                icon: "exclamationmark.triangle.fill",
                tint: .red
            )
            SummaryCard(
                title: "Active Caregivers",
                value: "3",
                icon: "person.2.fill",
                tint: .teal
            )
        }
    }

    private var filterPicker: some View {
        Picker("Filter", selection: $selectedFilter) {
            ForEach(RequestFilter.allCases) { filter in
                Text(filter.title).tag(filter)
            }
        }
        .pickerStyle(.segmented)
        .padding(8)
        .glassPanel(cornerRadius: 18)
    }

    private var requestList: some View {
        LazyVStack(spacing: 12) {
            ForEach(filteredRequests) { request in
                RequestCard(request: request) {
                    openResidentProfile(for: request)
                }
            }
        }
    }
}

private struct SummaryCard: View {
    let title: String
    let value: String
    let icon: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: icon)
                .foregroundStyle(tint)
                .font(.subheadline.weight(.semibold))
            Text(value)
                .font(.title3.weight(.bold))
            Text(title)
                .font(.caption)
                .foregroundStyle(Color.primary.opacity(0.75))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .glassPanel(cornerRadius: 16)
    }
}

private struct RequestCard: View {
    let request: AssistanceRequest
    let onSelectResident: () -> Void
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                ResidentAvatarView(avatarURL: request.avatarURL, initials: request.initials)

                VStack(alignment: .leading, spacing: 2) {
                    Button(action: onSelectResident) {
                        Text(request.residentName)
                            .font(.headline)
                            .foregroundStyle(primaryTextColor)
                    }
                    .buttonStyle(.plain)

                    Text("Room \(request.room)  •  \(request.timeAgo)")
                        .font(.caption)
                        .foregroundStyle(secondaryTextColor)
                }
                Spacer(minLength: 8)
                urgencyBadge
            }

            Text(request.requestType)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(primaryTextColor)

            Text(request.note)
                .font(.subheadline)
                .foregroundStyle(secondaryTextColor)

            HStack(spacing: 10) {
                Button("Attend") {}
                    .buttonStyle(.borderedProminent)
                    .tint(.teal)
                    .disabled(request.status != .pending)
                    .buttonBorderShape(.capsule)

                Button("Resolve") {}
                    .buttonStyle(.bordered)
                    .disabled(request.status == .resolved)
                    .buttonBorderShape(.capsule)

                Spacer()
                Text(request.status.title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(request.status.tint)
            }
        }
        .padding(14)
        .glassPanel(cornerRadius: 20, useMaterial: false, backgroundOpacity: cardOpacity, addShadow: false)
    }

    private var urgencyBadge: some View {
        Text(request.urgency.title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(request.urgency.tint)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(request.urgency.tint.opacity(0.15), in: Capsule())
    }

    private var primaryTextColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.95) : Color(red: 0.12, green: 0.15, blue: 0.18)
    }

    private var secondaryTextColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.74) : Color(red: 0.30, green: 0.33, blue: 0.37)
    }

    private var cardOpacity: Double {
        colorScheme == .dark ? 0.22 : 0.90
    }
}

private struct ResidentAvatarView: View {
    let avatarURL: URL?
    let initials: String

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color(red: 0.10, green: 0.50, blue: 0.60), Color(red: 0.07, green: 0.33, blue: 0.44)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            if let avatarURL {
                AsyncImage(url: avatarURL, transaction: Transaction(animation: .none)) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    default:
                        Text(initials)
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.white)
                    }
                }
                .clipShape(Circle())
            } else {
                Text(initials)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)
            }
        }
        .frame(width: 40, height: 40)
        .overlay(Circle().stroke(Color.white.opacity(0.40), lineWidth: 0.8))
    }
}

private struct ResidentProfileContext: Identifiable {
    let id: String
    let profile: ResidentProfile
    let history: [AssistanceRequest]

    init(profile: ResidentProfile, history: [AssistanceRequest]) {
        self.id = profile.name
        self.profile = profile
        self.history = history
    }
}

private struct ResidentProfile {
    let name: String
    let room: String
    let age: Int
    let communicationStyle: String
    let careNotes: String
    let emergencyContact: String

    static func profile(for request: AssistanceRequest) -> ResidentProfile {
        switch request.residentName {
        case "Evelyn Carter":
            return ResidentProfile(
                name: request.residentName,
                room: request.room,
                age: 84,
                communicationStyle: "Eye-controlled selection board",
                careNotes: "Needs medication reminders and hydration monitoring.",
                emergencyContact: "Lena Carter (Daughter) • (555) 382-9182"
            )
        case "Samuel Brooks":
            return ResidentProfile(
                name: request.residentName,
                room: request.room,
                age: 79,
                communicationStyle: "Gaze + blink confirmation",
                careNotes: "Assistance usually needed for meals and movement setup.",
                emergencyContact: "Jordan Brooks (Son) • (555) 217-7730"
            )
        case "Grace Mensah":
            return ResidentProfile(
                name: request.residentName,
                room: request.room,
                age: 88,
                communicationStyle: "Eye tracking with large icon prompts",
                careNotes: "Priority fall-risk profile; transfer support required.",
                emergencyContact: "Ama Mensah (Niece) • (555) 639-2214"
            )
        case "Harold King":
            return ResidentProfile(
                name: request.residentName,
                room: request.room,
                age: 82,
                communicationStyle: "Eye focus dwell selection",
                careNotes: "Frequent bed positioning and back-comfort requests.",
                emergencyContact: "Nora King (Spouse) • (555) 140-6657"
            )
        default:
            return ResidentProfile(
                name: request.residentName,
                room: request.room,
                age: 80,
                communicationStyle: "Eye-controlled communication",
                careNotes: "General assistance profile; monitor request frequency.",
                emergencyContact: "Primary Contact • (555) 000-0000"
            )
        }
    }
}

private struct ResidentProfileView: View {
    let context: ResidentProfileContext
    @Environment(\.dismiss) private var dismiss

    private var pendingCount: Int {
        context.history.filter { $0.status == .pending }.count
    }

    private var attendedCount: Int {
        context.history.filter { $0.status == .attended }.count
    }

    private var resolvedCount: Int {
        context.history.filter { $0.status == .resolved }.count
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 14) {
                    profileHeader
                    profileDetails
                    historySection
                }
                .padding(16)
            }
            .background(
                LinearGradient(
                    colors: [Color(red: 0.94, green: 0.97, blue: 0.99), Color(red: 0.91, green: 0.95, blue: 0.98)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
            )
            .navigationTitle("Patient Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    private var profileHeader: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(context.profile.name)
                .font(.title3.weight(.bold))
            Text("Room \(context.profile.room) • Age \(context.profile.age)")
                .font(.subheadline)
                .foregroundStyle(Color.primary.opacity(0.75))

            HStack(spacing: 8) {
                historyStat(title: "Pending", value: "\(pendingCount)", tint: .orange)
                historyStat(title: "Attended", value: "\(attendedCount)", tint: .teal)
                historyStat(title: "Resolved", value: "\(resolvedCount)", tint: .green)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .glassPanel(cornerRadius: 18)
    }

    private var profileDetails: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Profile")
                .font(.headline)

            detailRow(title: "Communication", value: context.profile.communicationStyle)
            detailRow(title: "Care Notes", value: context.profile.careNotes)
            detailRow(title: "Emergency Contact", value: context.profile.emergencyContact)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .glassPanel(cornerRadius: 18)
    }

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Request History")
                .font(.headline)

            ForEach(context.history) { item in
                ResidentHistoryRow(item: item)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .glassPanel(cornerRadius: 18, useMaterial: false, backgroundOpacity: 0.80)
    }

    private func detailRow(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.primary.opacity(0.62))
            Text(value)
                .font(.subheadline)
                .foregroundStyle(Color.primary.opacity(0.84))
        }
    }

    private func historyStat(title: String, value: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.headline.weight(.bold))
                .foregroundStyle(tint)
            Text(title)
                .font(.caption)
                .foregroundStyle(Color.primary.opacity(0.72))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(tint.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private struct ResidentHistoryRow: View {
    let item: AssistanceRequest

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(item.requestType)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text(item.timeAgo)
                    .font(.caption)
                    .foregroundStyle(Color.primary.opacity(0.65))
            }

            Text(item.note)
                .font(.subheadline)
                .foregroundStyle(Color.primary.opacity(0.75))

            HStack(spacing: 8) {
                statusChip(text: item.status.title, tint: item.status.tint)
                statusChip(text: item.status.attendanceText, tint: item.status.attendanceTint)
                Spacer()
            }
        }
        .padding(12)
        .background(Color.white.opacity(0.86), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.black.opacity(0.06), lineWidth: 0.6)
        )
    }

    private func statusChip(text: String, tint: Color) -> some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .foregroundStyle(tint)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(tint.opacity(0.14), in: Capsule())
    }
}

private struct AssistanceRequest: Identifiable {
    let id = UUID()
    let residentName: String
    let room: String
    let requestType: String
    let avatarURL: URL?
    let urgency: Urgency
    let status: RequestStatus
    let timeAgo: String
    let note: String

    var initials: String {
        residentName
            .split(separator: " ")
            .prefix(2)
            .compactMap { $0.first }
            .map(String.init)
            .joined()
    }

    static func randomPending() -> AssistanceRequest {
        let residents = [
            ("Rose Daniels", "A-104", URL(string: "https://upload.wikimedia.org/wikipedia/commons/thumb/d/dc/Cicely_Tyson_1973.jpg/330px-Cicely_Tyson_1973.jpg")),
            ("Miguel Johnson", "B-221", URL(string: "https://upload.wikimedia.org/wikipedia/commons/thumb/b/b5/Morgan_Freeman%2C_2006.jpg/250px-Morgan_Freeman%2C_2006.jpg")),
            ("Anita Clarke", "C-014", URL(string: "https://upload.wikimedia.org/wikipedia/commons/thumb/b/b6/Angela_Bassett.jpg/326px-Angela_Bassett.jpg")),
            ("Peter Owusu", "A-310", URL(string: "https://upload.wikimedia.org/wikipedia/commons/thumb/3/3e/Denzel_Washington.jpg/239px-Denzel_Washington.jpg")),
            ("Helen Walsh", "B-009", URL(string: "https://upload.wikimedia.org/wikipedia/commons/thumb/3/3a/Alfre_Woodard.jpg/333px-Alfre_Woodard.jpg"))
        ]
        let requestTypes = [
            ("Meal Assistance", "Needs help opening meal tray."),
            ("Wheelchair Reposition", "Wants to move closer to window."),
            ("Blanket Adjustment", "Feels cold and needs blanket repositioned."),
            ("Nurse Check-in", "Would like a quick wellness check."),
            ("Call Family", "Asks for help placing a family call.")
        ]

        let resident = residents.randomElement() ?? ("Resident", "A-000", nil)
        let request = requestTypes.randomElement() ?? ("General Assistance", "Needs caregiver support.")
        let urgency: Urgency = [.normal, .high, .critical].randomElement() ?? .normal

        return AssistanceRequest(
            residentName: resident.0,
            room: resident.1,
            requestType: request.0,
            avatarURL: resident.2,
            urgency: urgency,
            status: .pending,
            timeAgo: "Just now",
            note: request.1
        )
    }
}

private enum Urgency {
    case normal
    case high
    case critical

    var title: String {
        switch self {
        case .normal: return "Normal"
        case .high: return "High"
        case .critical: return "Critical"
        }
    }

    var tint: Color {
        switch self {
        case .normal: return .blue
        case .high: return .orange
        case .critical: return .red
        }
    }
}

private enum RequestStatus {
    case pending
    case attended
    case resolved

    var title: String {
        switch self {
        case .pending: return "Pending"
        case .attended: return "Attended"
        case .resolved: return "Resolved"
        }
    }

    var tint: Color {
        switch self {
        case .pending: return .orange
        case .attended: return .teal
        case .resolved: return .green
        }
    }

    var attendanceText: String {
        switch self {
        case .pending:
            return "Not Attended"
        case .attended, .resolved:
            return "Attended"
        }
    }

    var attendanceTint: Color {
        switch self {
        case .pending:
            return .orange
        case .attended:
            return .teal
        case .resolved:
            return .green
        }
    }
}

private enum RequestFilter: CaseIterable, Identifiable, Hashable {
    case all
    case pending
    case attended
    case resolved

    var id: String { title }

    var title: String {
        switch self {
        case .all: return "All"
        case .pending: return "Pending"
        case .attended: return "Attended"
        case .resolved: return "Resolved"
        }
    }

    func matches(_ status: RequestStatus) -> Bool {
        switch self {
        case .all:
            return true
        case .pending:
            return status == .pending
        case .attended:
            return status == .attended
        case .resolved:
            return status == .resolved
        }
    }
}

private struct GlassPanelModifier: ViewModifier {
    let cornerRadius: CGFloat
    let useMaterial: Bool
    let backgroundOpacity: Double
    let addShadow: Bool

    private var fillStyle: AnyShapeStyle {
        if useMaterial {
            return AnyShapeStyle(.regularMaterial)
        }
        return AnyShapeStyle(Color.white.opacity(backgroundOpacity))
    }

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(fillStyle)
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .stroke(Color.white.opacity(0.46), lineWidth: 1)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .stroke(Color.black.opacity(0.06), lineWidth: 0.5)
                    )
            )
            .shadow(
                color: addShadow ? Color.black.opacity(0.08) : .clear,
                radius: addShadow ? 8 : 0,
                x: 0,
                y: addShadow ? 4 : 0
            )
    }
}

private extension View {
    func glassPanel(
        cornerRadius: CGFloat,
        useMaterial: Bool = true,
        backgroundOpacity: Double = 0.78,
        addShadow: Bool = true
    ) -> some View {
        modifier(
            GlassPanelModifier(
                cornerRadius: cornerRadius,
                useMaterial: useMaterial,
                backgroundOpacity: backgroundOpacity,
                addShadow: addShadow
            )
        )
    }
}

private final class DemoNotificationManager {
    static let shared = DemoNotificationManager()

    private var requestedAuth = false

    private init() {}

    func requestAuthorizationIfNeeded() async {
        guard !requestedAuth else { return }
        requestedAuth = true
        do {
            _ = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            // Demo app: ignore permission failures.
        }
    }

    func scheduleIncomingRequestNotification(for request: AssistanceRequest) {
        let content = UNMutableNotificationContent()
        content.title = "IRIS: New Assistance Request"
        content.body = "\(request.residentName) in room \(request.room): \(request.requestType)"
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 2, repeats: false)
        let notificationRequest = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: trigger
        )
        UNUserNotificationCenter.current().add(notificationRequest)
    }

    func playImmediateAlertFeedback() {
        #if canImport(UIKit) && canImport(AudioToolbox)
        let feedback = UINotificationFeedbackGenerator()
        feedback.prepare()
        feedback.notificationOccurred(.warning)

        AudioServicesPlaySystemSound(1005)
        AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
        #else
        // Haptics and system sounds are unavailable on this platform.
        #endif
    }
}

#Preview {
    ContentView()
}
