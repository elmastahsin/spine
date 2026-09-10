import Foundation
import Testing
@testable import Spine

struct AudioNudgerTests {
    @Test func nudgeMessagesAreLocalizedToTurkish() {
        let messages = AudioNudger.nudgeMessages(locale: Locale(identifier: "tr"))
        #expect(messages.contains("Dik dur"))
        #expect(!messages.contains("Sit up straight"))
    }

    @Test func nudgeMessagesAreLocalizedToEnglish() {
        let messages = AudioNudger.nudgeMessages(locale: Locale(identifier: "en"))
        #expect(messages.contains("Sit up straight"))
        #expect(!messages.contains("Dik dur"))
    }
}
