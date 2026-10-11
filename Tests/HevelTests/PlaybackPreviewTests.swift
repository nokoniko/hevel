import Testing
@testable import Hevel

@MainActor
struct PlaybackPreviewTests {
	@Test func showsAMadeUpTrackPlaying() {
		let model = NowPlayingModel()
		model.startPreview()
		#expect(model.isPreviewing)
		#expect(model.isPlaying)
		#expect(model.hasMedia)
		#expect(model.title == "Preview Track 1")
		#expect(model.artwork != nil)
	}

	@Test func stepsFlipThatWay() {
		let model = NowPlayingModel()
		model.startPreview()
		model.stepPreview(forward: true)
		#expect(model.title == "Preview Track 2")
		#expect(model.flipForward)
		model.stepPreview(forward: false)
		model.stepPreview(forward: false)
		#expect(model.title == "Preview Track 0")
		#expect(!model.flipForward)
	}

	@Test func steppingStartsThePreview() {
		let model = NowPlayingModel()
		model.stepPreview(forward: true)
		#expect(model.isPreviewing)
		#expect(model.isPlaying)
	}

	@Test func hidingLeavesNothingWhenNothingPlayed() {
		let model = NowPlayingModel()
		model.startPreview()
		model.stopPreview()
		#expect(!model.isPreviewing)
		#expect(!model.hasMedia)
		#expect(!model.isPlaying)
	}

	@Test func eachTrackGetsItsOwnCover() {
		#expect(NowPlayingModel.previewInfo(0).album != NowPlayingModel.previewInfo(1).album)
		#expect(NowPlayingModel.previewInfo(-1).artwork != nil)
	}
}
