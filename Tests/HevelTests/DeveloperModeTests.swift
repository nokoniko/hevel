import Foundation
import Testing
@testable import Hevel

struct DeveloperModeTests {
	@Test(arguments: [
		("hevel://preview/charging", DeveloperMode.Command.preview(.charging)),
		("hevel://preview/lowBattery", .preview(.lowBattery)),
		("hevel://preview/lock", .preview(.lock)),
		("hevel://hide/lowBattery", .hide(.lowBattery)),
		("hevel://hide/lock", .hide(.lock)),
		("hevel://preview/music", .preview(.music)),
		("hevel://track/next", .track(forward: true)),
		("hevel://track/previous", .track(forward: false)),
		("hevel://settings", .openSettings),
	])
	func readsTheLinks(link: String, command: DeveloperMode.Command) {
		#expect(DeveloperMode.command(for: URL(string: link)!) == command)
	}

	@Test(arguments: [
		"hevel://preview/nope",
		"hevel://preview",
		"hevel://hide/everything",
		"hevel://track/sideways",
		"hevel://something",
		"https://preview/charging",
		"other://settings",
	])
	func ignoresAnythingElse(link: String) {
		#expect(DeveloperMode.command(for: URL(string: link)!) == nil)
	}

	@Test func everyEventHasAScriptName() {
		#expect(PreviewEvent.allCases.map(\.rawValue) == ["music", "charging", "lowBattery", "lock"])
	}
}
