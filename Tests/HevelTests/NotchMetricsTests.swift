import Foundation
import Testing
@testable import Hevel

struct NotchMetricsTests {
	@Test func collapsedGeometryIsDerivedFromTheNotch() {
		let metrics = NotchMetrics(notchWidth: 185, notchHeight: 37, hasNotch: true)
		#expect(metrics.collapsedWidth == 245)
		#expect(metrics.restHeight == 38)
	}

	@Test func theSizeSliderScalesThePopOut() {
		var metrics = NotchMetrics(notchWidth: 185, notchHeight: 37, hasNotch: true)
		metrics.scale = 1.3
		#expect(metrics.collapsedSidePadding == 39)
		#expect(metrics.restHeight == 38)
		metrics.scale = 0.8
		#expect(metrics.collapsedSidePadding == 24)
	}

	@Test(arguments: [NotchMetrics.scaleRange.lowerBound, 1, NotchMetrics.scaleRange.upperBound])
	func contentNeverOutgrowsTheNotch(scale: CGFloat) {
		var metrics = NotchMetrics(notchWidth: 185, notchHeight: 37, hasNotch: true)
		metrics.scale = scale
		#expect(metrics.artworkSize <= metrics.notchHeight - 4)
		#expect(metrics.ringSize <= metrics.notchHeight - 2)
	}

	@Test func canvasFitsTheLargestPopOut() {
		var metrics = NotchMetrics(notchWidth: 260, notchHeight: 37, hasNotch: true)
		metrics.scale = NotchMetrics.scaleRange.upperBound
		#expect(metrics.maxWindowSize.width >= metrics.collapsedWidth)
		#expect(metrics.maxWindowSize.width >= metrics.alertWidth)
	}

	@Test func canvasFitsThePopOut() {
		let metrics = NotchMetrics(notchWidth: 185, notchHeight: 37, hasNotch: true)
		#expect(metrics.maxWindowSize.width >= metrics.collapsedWidth)
		#expect(metrics.maxWindowSize.height >= metrics.restHeight)
	}
}
