import Foundation
import Testing
@testable import Awake

@Suite struct AwakeCommandTests {
    @Test func linksTurnAwakeOnOffOrToggle() {
        #expect(AwakeCommand(url: URL(string: "awake://on")!) == .on)
        #expect(AwakeCommand(url: URL(string: "awake://off")!) == .off)
        #expect(AwakeCommand(url: URL(string: "awake://toggle")!) == .toggle)
        #expect(AwakeCommand(url: URL(string: "AWAKE://ON")!) == .on)
    }

    @Test func anythingElseIsIgnored() {
        #expect(AwakeCommand(url: URL(string: "awake://maybe")!) == nil)
        #expect(AwakeCommand(url: URL(string: "awake://")!) == nil)
        #expect(AwakeCommand(url: URL(string: "https://on")!) == nil)
    }
}

// Asked to stay awake, Awake holds the Mac up on power and lets it sleep on battery (unless told not to pause).
@Suite struct AwakePolicyTests {
    @Test func offMeansRelease() {
        #expect(AwakePolicy.target(wantsAwake: false, pauseOnBattery: true, onPower: true) == .release)
        #expect(AwakePolicy.target(wantsAwake: false, pauseOnBattery: false, onPower: false) == .release)
    }

    @Test func onPowerHolds() {
        #expect(AwakePolicy.target(wantsAwake: true, pauseOnBattery: true, onPower: true) == .hold)
    }

    @Test func onBatteryPausesSoTheMacCanSleepInABag() {
        #expect(AwakePolicy.target(wantsAwake: true, pauseOnBattery: true, onPower: false) == .pause)
    }

    @Test func withPausingOffBatteryStillHolds() {
        #expect(AwakePolicy.target(wantsAwake: true, pauseOnBattery: false, onPower: false) == .hold)
    }
}
