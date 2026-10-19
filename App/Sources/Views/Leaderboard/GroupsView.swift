import SwiftUI
import UnscrollKit

struct GroupsView: View {
    @Environment(AppModel.self) private var model
    @State private var newName = ""
    @State private var code = ""

    var body: some View {
        List {
            if !model.social.isConnected {
                Section {
                    Label("Groups need a server", systemImage: "server.rack").font(.headline)
                    Text("Run the open-source Unscroll server (or use a friend's) and connect it in Profile › Social server. Groups are invite-only: strangers can't join.")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
            } else {
                Section("Your groups") {
                    if model.social.groups.isEmpty { Text("No groups yet.").foregroundStyle(.secondary) }
                    ForEach(model.social.groups) { group in
                        NavigationLink(value: group) {
                            VStack(alignment: .leading) {
                                Text(group.name).font(.headline)
                                Text("\(group.memberCount) member\(group.memberCount == 1 ? "" : "s")").font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                Section("Create a group") {
                    TextField("Group name", text: $newName)
                    Button("Create") {
                        Task { if await model.social.createGroup(name: newName) != nil { newName = "" } }
                    }
                    .disabled(newName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                Section("Join with invite code") {
                    TextField("ABCD2345", text: $code).textInputAutocapitalization(.characters).autocorrectionDisabled()
                    Button("Join") {
                        Task { if await model.social.joinGroup(code: code) != nil { code = "" } }
                    }
                    .disabled(code.count < 8)
                }
                if let error = model.social.lastError {
                    Section { Text(error).foregroundStyle(Theme.danger) }
                }
            }
        }
        .navigationDestination(for: GroupSummary.self) { GroupDetailView(summary: $0) }
        .task { await model.social.loadGroups() }
        .refreshable { await model.social.loadGroups() }
    }
}

struct GroupDetailView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let summary: GroupSummary
    @State private var detail: GroupDetail?

    var body: some View {
        List {
            Section {
                HStack {
                    Text("Invite code")
                    Spacer()
                    Text(summary.inviteCode).font(.body.monospaced().bold())
                    ShareLink(item: "Join my Unscroll group \"\(summary.name)\" with code \(summary.inviteCode)") {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
            }
            Section("This week") {
                ForEach(Array((detail?.members ?? []).enumerated()), id: \.element.id) { index, member in
                    HStack {
                        Text("\(index + 1)").font(.headline.monospacedDigit()).frame(width: 28)
                        Text(member.handle)
                        Spacer()
                        VStack(alignment: .trailing) {
                            Text("\(member.xp) XP").font(.subheadline.bold())
                            Text(TimeFormat.minutes(member.screenMinutes) + " screen").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }
            Section("Activity") {
                if detail?.feed.isEmpty ?? true { Text("Nothing yet. Start a group session!").foregroundStyle(.secondary) }
                ForEach(detail?.feed ?? []) { item in
                    Text(Self.describe(item)).font(.subheadline)
                }
            }
            Section {
                Button("Leave group", role: .destructive) {
                    Task { await model.social.leaveGroup(summary.id); dismiss() }
                }
            }
        }
        .navigationTitle(summary.name)
        .task { detail = await model.social.groupDetail(summary.id, week: model.currentWeek) }
        .refreshable { detail = await model.social.groupDetail(summary.id, week: model.currentWeek) }
    }

    static func describe(_ item: FeedItem) -> String {
        let minutes = item.minutes.map { " (\(TimeFormat.minutes($0)))" } ?? ""
        switch item.kind {
        case "sessionStarted": return "🌱 \(item.handle) started a session\(minutes)"
        case "sessionCompleted": return "✅ \(item.handle) completed a session\(minutes)"
        case "sessionBroken": return "💔 \(item.handle) ended a session early"
        case "goalMet": return "🔥 \(item.handle) hit their daily goal"
        case "goalMissed": return "😬 \(item.handle) missed their daily goal"
        default: return "\(item.handle): \(item.kind)"
        }
    }
}
