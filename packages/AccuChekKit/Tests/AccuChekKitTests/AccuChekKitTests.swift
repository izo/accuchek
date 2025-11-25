import XCTest
@testable import AccuChekKit

final class AccuChekKitTests: XCTestCase {

    func testGlucoseSampleCategory() {
        let lowSample = GlucoseSample(id: 1, epoch: 0, timestamp: "", mgDL: 65, mmolL: 3.6)
        XCTAssertEqual(lowSample.category, .low)

        let normalSample = GlucoseSample(id: 2, epoch: 0, timestamp: "", mgDL: 90, mmolL: 5.0)
        XCTAssertEqual(normalSample.category, .normal)

        let elevatedSample = GlucoseSample(id: 3, epoch: 0, timestamp: "", mgDL: 110, mmolL: 6.1)
        XCTAssertEqual(elevatedSample.category, .elevated)

        let highSample = GlucoseSample(id: 4, epoch: 0, timestamp: "", mgDL: 200, mmolL: 11.1)
        XCTAssertEqual(highSample.category, .high)
    }

    func testGlucoseSampleCoding() throws {
        let sample = GlucoseSample(
            id: 1,
            epoch: 1700000000,
            timestamp: "2023-11-14 12:00:00",
            mgDL: 120,
            mmolL: 6.7
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(sample)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(GlucoseSample.self, from: data)

        XCTAssertEqual(decoded.id, sample.id)
        XCTAssertEqual(decoded.mgDL, sample.mgDL)
        XCTAssertEqual(decoded.mmolL, sample.mmolL, accuracy: 0.01)
    }

    func testStatisticsCalculation() async {
        let samples = [
            GlucoseSample(id: 1, epoch: 0, timestamp: "", mgDL: 80, mmolL: 4.4),
            GlucoseSample(id: 2, epoch: 0, timestamp: "", mgDL: 100, mmolL: 5.6),
            GlucoseSample(id: 3, epoch: 0, timestamp: "", mgDL: 120, mmolL: 6.7),
        ]

        let dataManager = await DataManager()
        let stats = await dataManager.statistics(for: samples)

        XCTAssertEqual(stats.count, 3)
        XCTAssertEqual(stats.average, 100.0, accuracy: 0.01)
        XCTAssertEqual(stats.min, 80)
        XCTAssertEqual(stats.max, 120)
    }

    func testCSVExport() async throws {
        let samples = [
            GlucoseSample(id: 1, epoch: 1700000000, timestamp: "2023-11-14 12:00:00", mgDL: 100, mmolL: 5.6),
        ]

        let dataManager = await DataManager()
        let csv = await dataManager.exportToCSV(samples: samples)

        XCTAssertTrue(csv.contains("ID,Timestamp,Epoch,mg/dL,mmol/L"))
        XCTAssertTrue(csv.contains("1,2023-11-14 12:00:00,1700000000,100,5.6"))
    }

    func testVersion() {
        XCTAssertEqual(AccuChekKit.version, "0.1.0")
    }
}
