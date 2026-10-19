import FamilyControls
import SwiftUI
import UnscrollKit
import UnscrollScreenTime

/// Quiz → score → "shock" → reframe → motivations → Screen Time permission → track everything → goal → handle.
struct OnboardingFlow: View {
    enum Step: Int, CaseIterable { case welcome, quiz, score, shock, reframe, motivations, permission, tracking, goal, handle }

    @Environment(AppModel.self) private var model
    @State private var step: Step = .welcome
    @State private var answers: [String: Double] = [:]
    @State private var questionIndex = 0
    @State private var profile = Profile()

    var body: some View {
        VStack(spacing: 0) {
            ProgressView(value: Double(step.rawValue), total: Double(Step.allCases.count - 1))
                .padding(.horizontal)
                .opacity(step == .welcome ? 0 : 1)
            Group {
                switch step {
                case .welcome: WelcomeStep { advance() }
                case .quiz: quiz
                case .score: ScoreStep(score: OnboardingQuiz.habitScore(answers: answers)) { advance() }
                case .shock: ShockStep(projection: projection) { advance() }
                case .reframe: ReframeStep(projection: projection) { advance() }
                case .motivations: MotivationStep(selected: $profile.motivations) { advance() }
                case .permission: PermissionStep { advance() }
                case .tracking: TrackingStep { advance() }
                case .goal: GoalStep(goalMinutes: $profile.dailyGoalMinutes, reportedHours: profile.reportedDailyHours) { advance() }
                case .handle: HandleStep(handle: $profile.handle) {
                    Task { await model.completeOnboarding(profile: profile) }
                }
                }
            }
            .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .opacity))
            .id(step.rawValue * 100 + questionIndex)
        }
        .animation(.easeInOut(duration: 0.3), value: step)
        .animation(.easeInOut(duration: 0.3), value: questionIndex)
    }

    private var projection: LifetimeProjection {
        LifetimeProjection(dailyHours: profile.reportedDailyHours, age: profile.age)
    }

    private var quiz: some View {
        let question = OnboardingQuiz.all[questionIndex]
        return QuizStep(question: question) { option in
            answers[question.id] = option.value
            if question.id == OnboardingQuiz.dailyHours.id {
                profile.reportedDailyHours = option.value
                profile.dailyGoalMinutes = OnboardingQuiz.recommendedGoalMinutes(dailyHours: option.value)
            }
            if question.id == OnboardingQuiz.age.id { profile.age = Int(option.value) }
            if questionIndex + 1 < OnboardingQuiz.all.count {
                questionIndex += 1
            } else {
                advance()
            }
        }
    }

    private func advance() {
        guard let next = Step(rawValue: step.rawValue + 1) else { return }
        step = next
    }
}

struct OnboardingPage<Content: View>: View {
    var buttonTitle = "Continue"
    var buttonDisabled = false
    let action: () -> Void
    @ViewBuilder var content: Content

    var body: some View {
        VStack(spacing: 24) {
            ScrollView { VStack(alignment: .leading, spacing: 20) { content }.padding(24) }
            Button(buttonTitle, action: action)
                .primaryButton()
                .disabled(buttonDisabled)
                .opacity(buttonDisabled ? 0.5 : 1)
                .padding(.horizontal, 24)
                .padding(.bottom, 12)
        }
    }
}
