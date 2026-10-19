import SwiftUI
import UnscrollKit

struct WelcomeStep: View {
    let next: () -> Void

    var body: some View {
        VStack(spacing: 28) {
            Spacer()
            Image(systemName: "leaf.circle.fill").font(.system(size: 96)).foregroundStyle(Theme.accent)
            Text("Unscroll").font(.system(size: 44, weight: .heavy, design: .rounded))
            Text("Spend less time on your phone and more time on your life. Free and open source.")
                .font(.title3).multilineTextAlignment(.center).foregroundStyle(.secondary)
            Spacer()
            Button("Get started", action: next).primaryButton()
        }
        .padding(24)
    }
}

struct QuizStep: View {
    let question: QuizQuestion
    let choose: (QuizOption) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text(question.prompt).font(.title.bold()).padding(.top, 24)
            ForEach(question.options) { option in
                Button { choose(option) } label: {
                    Text(option.label)
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(18)
                        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .foregroundStyle(.primary)
            }
            Spacer()
        }
        .padding(24)
    }
}

struct ScoreStep: View {
    let score: Int
    let next: () -> Void

    var body: some View {
        OnboardingPage(action: next) {
            Text("Your scroll score").font(.title.bold())
            ZStack {
                RingProgress(fraction: Double(score) / 100, lineWidth: 18, color: score > 60 ? Theme.danger : Theme.warm)
                VStack {
                    Text("\(score)").font(.system(size: 56, weight: .heavy, design: .rounded))
                    Text("out of 100").foregroundStyle(.secondary)
                }
            }
            .frame(width: 220, height: 220)
            .frame(maxWidth: .infinity)
            Text(score > 60
                 ? "Your phone has a strong grip on your attention. The good news: that makes it easier to see big improvements fast."
                 : "You're more mindful than most, and there's still time to reclaim.")
                .font(.body).foregroundStyle(.secondary)
        }
    }
}

struct ShockStep: View {
    let projection: LifetimeProjection
    let next: () -> Void

    var body: some View {
        OnboardingPage(action: next) {
            Text("At this rate, you'll spend").font(.title2).foregroundStyle(.secondary)
            Text(String(format: "%.1f years", projection.yearsOnPhone))
                .font(.system(size: 64, weight: .heavy, design: .rounded))
                .foregroundStyle(Theme.danger)
            Text("of the rest of your life looking at your phone.").font(.title2.bold())
            Text("That's \(Int(projection.daysPerYear)) full days every single year.")
                .foregroundStyle(.secondary)
        }
    }
}

struct ReframeStep: View {
    let projection: LifetimeProjection
    let next: () -> Void

    var body: some View {
        OnboardingPage(buttonTitle: "Let's get them back", action: next) {
            Text("But here's the thing…").font(.title2).foregroundStyle(.secondary)
            Text("Cut your screen time in half and you get back").font(.title2.bold())
            Text(String(format: "%.1f years", projection.yearsReclaimed))
                .font(.system(size: 64, weight: .heavy, design: .rounded))
                .foregroundStyle(Theme.accent)
            Text("Time for friends, sleep, books, sport, or doing nothing at all. Unscroll helps with blocking, intentions, streaks and a little friendly competition.")
                .foregroundStyle(.secondary)
        }
    }
}

struct MotivationStep: View {
    @Binding var selected: [Motivation]
    let next: () -> Void

    var body: some View {
        OnboardingPage(buttonDisabled: selected.isEmpty, action: next) {
            Text("What do you want more of?").font(.title.bold())
            Text("Pick all that apply.").foregroundStyle(.secondary)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(Motivation.allCases) { motivation in
                    let isOn = selected.contains(motivation)
                    Button {
                        selected = isOn ? selected.filter { $0 != motivation } : selected + [motivation]
                    } label: {
                        VStack(spacing: 8) {
                            Image(systemName: motivation.symbol).font(.title2)
                            Text(motivation.title).font(.subheadline.bold())
                        }
                        .frame(maxWidth: .infinity, minHeight: 90)
                        .background(isOn ? Theme.accent.opacity(0.18) : Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(isOn ? Theme.accent : .clear, lineWidth: 2))
                    }
                    .foregroundStyle(isOn ? Theme.accent : .primary)
                }
            }
        }
    }
}
