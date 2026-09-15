import UIKit

/// What the platform's own notion of where an application is comes to, in the three states the engine has.
///
/// A platform distinguishes more moments than an application has any use for, and the ones that matter are
/// these three: in front and taking input, in front and not, and out of sight and possibly about to be
/// ended. Everything else a platform reports is one of those three arrived at by a different route.
enum VarnLifecycle {
    static let notices: [Notification.Name] = [
        UIApplication.didBecomeActiveNotification,
        UIApplication.willResignActiveNotification,
        UIApplication.didEnterBackgroundNotification,
        UIApplication.willEnterForegroundNotification,
    ]

    static func state(of application: UIApplication.State) -> String {
        switch application {
        case .active:
            return "active"
        case .inactive:
            return "inactive"
        case .background:
            return "background"
        @unknown default:
            return "inactive"
        }
    }

    /// Answers the state a notification means, which is not always the state the application is in yet.
    ///
    /// A notification arrives before the platform has moved: asking `applicationState` inside
    /// `willResignActive` still answers active, and inside `willEnterForeground` still answers background.
    /// So what the notification says is what is reported.
    static func state(for notice: Notification.Name) -> String? {
        switch notice {
        case UIApplication.didBecomeActiveNotification:
            return "active"
        case UIApplication.willResignActiveNotification:
            return "inactive"
        case UIApplication.didEnterBackgroundNotification:
            return "background"
        case UIApplication.willEnterForegroundNotification:
            return "inactive"
        default:
            return nil
        }
    }
}
