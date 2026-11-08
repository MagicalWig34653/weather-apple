import Testing
@testable import Weather

struct ModelLayerSourcesTests {
    @Test func noLinesWithoutModelLayers() {
        #expect(ModelLayerSources.lines(modelLayersAvailable: false, forest: ForestInfo.bundled).isEmpty)
        #expect(ModelLayerSources.visibleLayers(manifestPresent: { _ in false }).isEmpty)
    }

    @Test func iconAndWorldCoverLinesUseExactWording() throws {
        let forest = try #require(ForestInfo.bundled)
        let lines = ModelLayerSources.lines(modelLayersAvailable: true, forest: forest)
        #expect(lines.map(\.id) == ["icon", "worldcover"])
        #expect(lines[0].text.contains("DWD ICON-D2/ICON-EU Modelldaten (CC BY 4.0, Quelle: Deutscher Wetterdienst)"))
        #expect(lines[1].text.contains("© ESA WorldCover project 2021 / Contains modified Copernicus Sentinel data (2021) processed by ESA WorldCover consortium"))
    }

    @Test func forestLineOmittedWithoutForestData() {
        #expect(ModelLayerSources.lines(modelLayersAvailable: true, forest: nil).map(\.id) == ["icon"])
    }
}
