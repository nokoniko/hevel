import Foundation
import Testing
@testable import Hevel

struct BatteryAlertsTests {
	let low = BatteryAlert(level: 20, direction: .down)
	let high = BatteryAlert(level: 80, direction: .up)

	@Test(arguments: [
		(21, 20, false, 20),
		(25, 19, false, 20),
		(79, 80, true, 80),
		(70, 85, true, 80),
	])
	func firesWhenTheLevelIsReachedTheRightWay(previous: Int, current: Int, pluggedIn: Bool, level: Int) {
		#expect(BatteryAlerts.triggered([low, high], from: previous, to: current, pluggedIn: pluggedIn)?.level == level)
	}

	@Test(arguments: [
		(21, 20, true),     // down, but charging
		(79, 80, false),    // up, but on battery
		(20, 19, false),    // already below
		(80, 81, true),     // already above
		(19, 21, false),    // the wrong way
		(50, 50, false),    // no change
	])
	func staysQuietOtherwise(previous: Int, current: Int, pluggedIn: Bool) {
		#expect(BatteryAlerts.triggered([low, high], from: previous, to: current, pluggedIn: pluggedIn) == nil)
	}

	@Test(arguments: [(51, 50, false, true), (49, 50, true, true), (50, 51, true, false), (50, 49, false, false), (51, 50, true, false)])
	func bothFiresEitherWay(previous: Int, current: Int, pluggedIn: Bool, fires: Bool) {
		let both = BatteryAlert(level: 50, direction: .both)
		#expect((BatteryAlerts.triggered([both], from: previous, to: current, pluggedIn: pluggedIn) != nil) == fires)
	}

	@Test func aBigJumpPicksTheNearestAlert() {
		let alerts = [BatteryAlert(level: 30, direction: .down), BatteryAlert(level: 20, direction: .down)]
		#expect(BatteryAlerts.triggered(alerts, from: 35, to: 18, pluggedIn: false)?.level == 20)
	}

	@Test(arguments: [(0.8, 80), (0.81, 80), (0.83, 85), (0.0, 5), (1.0, 100), (1.4, 100), (-0.2, 5)])
	func aClickPicksTheNearestFive(fraction: Double, level: Int) {
		#expect(BatteryAlerts.level(atFraction: fraction) == level)
	}

	@Test func addingGuessesTheDirectionAndSkipsDuplicates() {
		let added = BatteryAlerts.adding(level: 80, to: [low])
		#expect(added.map(\.level) == [20, 80])
		#expect(added.last?.direction == .up)
		#expect(BatteryAlerts.adding(level: 30, to: [low]).last?.direction == .down)
		#expect(BatteryAlerts.adding(level: 20, to: [low]) == [low])
	}

	@Test func draggingMovesThePinUnlessTheLevelIsTaken() {
		let moved = BatteryAlerts.moving(high.id, to: 90, in: [low, high])
		#expect(moved.map(\.level) == [20, 90])
		#expect(moved.last?.direction == .up)
		#expect(moved.last?.id == high.id)
		#expect(BatteryAlerts.moving(high.id, to: 20, in: [low, high]) == [low, high])
		#expect(BatteryAlerts.moving(high.id, to: 80, in: [low, high]) == [low, high])
	}

	@Test func thePreviewCyclesThroughTheAlerts() {
		let both = BatteryAlert(level: 50, direction: .both)
		let sequence = BatteryAlerts.previewSequence([low, both, high])
		#expect(sequence.map(\.level) == [80, 50, 50, 20])
		#expect(sequence.map(\.direction) == [.up, .down, .up, .down])
		#expect(BatteryAlerts.previewSequence([]) == BatteryAlerts.defaults)
	}

	@Test func survivesStorage() {
		let alerts = [low, high]
		#expect(BatteryAlerts.decode(BatteryAlerts.encode(alerts)) == alerts)
		#expect(BatteryAlerts.decode(nil) == BatteryAlerts.defaults)
		#expect(BatteryAlerts.decode(Data("nonsense".utf8)) == BatteryAlerts.defaults)
	}

	@Test func defaultsKeepTheOld20PercentAlert() {
		#expect(BatteryAlerts.defaults.map(\.level) == [20])
		#expect(BatteryAlerts.defaults.map(\.direction) == [.down])
	}
}
