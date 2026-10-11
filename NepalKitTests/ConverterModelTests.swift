// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel
import Foundation
import Testing
import NepalKitCore
@testable import NepalKit

@MainActor
struct ConverterModelTests {
    private func bsModel() -> ConverterModel {
        ConverterModel(
            direction: .bsToAD,
            bsYear: 2083, bsMonth: 6, bsDay: 11,
            adYear: 2026, adMonth: 9, adDay: 27
        )
    }

    @Test func bsToADKnownDateWithWeekday() {
        let model = bsModel()
        let settings = DisplaySettings(digits: .latin, monthNames: .transliterated)
        #expect(model.convertedText(settings: settings) == "27 September 2026 · Sunday")
    }

    @Test func adToBSKnownDateWithWeekday() {
        let model = ConverterModel(
            direction: .adToBS,
            bsYear: 2083, bsMonth: 6, bsDay: 11,
            adYear: 2026, adMonth: 9, adDay: 27
        )
        let settings = DisplaySettings(digits: .latin, monthNames: .transliterated)
        #expect(model.convertedText(settings: settings) == "11 Ashoj 2083 · Sunday")
    }

    @Test func outputHonorsDevanagariAndNepali() {
        let model = bsModel()
        let settings = DisplaySettings(digits: .devanagari, monthNames: .nepali)
        // Gregorian months stay English; digits and weekday honor settings.
        #expect(model.convertedText(settings: settings) == "२७ September २०२६ · आइत")
    }

    @Test func bsPickersBoundedToSupportedRange() {
        let model = bsModel()
        #expect(model.bsYears == Array(1975 ... 2084))
        #expect(model.daysInBSMonth(year: 2084, month: 2) == 32)
        #expect(model.daysInBSMonth(year: 1989, month: 8) == 29)
    }

    @Test func adDayPickerPreventsInvalidDates() {
        let model = bsModel()
        #expect(model.daysInADMonth(year: 2024, month: 2) == 29)
        #expect(model.daysInADMonth(year: 2023, month: 2) == 28)
        #expect(model.daysInADMonth(year: 2026, month: 9) == 30)
    }

    @Test func togglePreservesConvertedDateWithoutReentry() {
        let model = bsModel()
        model.toggleDirection()
        #expect(model.direction == .adToBS)
        #expect((model.adYear, model.adMonth, model.adDay) == (2026, 9, 27))
        // Toggling back restores the Bikram Sambat date.
        model.toggleDirection()
        #expect(model.direction == .bsToAD)
        #expect((model.bsYear, model.bsMonth, model.bsDay) == (2083, 6, 11))
    }

    @Test func changingMonthClampsDay() {
        let model = ConverterModel(
            direction: .bsToAD, bsYear: 2084, bsMonth: 2, bsDay: 32,
            adYear: 2026, adMonth: 9, adDay: 27
        )
        // Projected Jestha has 32 days; Ashar has 31. Changing only
        // the month must clamp the previously valid day 32 down to 31.
        model.bsMonth = 3
        #expect(model.bsDay == 31)
    }

    @Test func settingSameDirectionIsNoop() {
        let model = bsModel()
        model.setDirection(.bsToAD)
        #expect(model.direction == .bsToAD)
        #expect((model.bsYear, model.bsMonth, model.bsDay) == (2083, 6, 11))
    }

    @Test func adPickersBoundedToConvertibleSpan() {
        let model = bsModel()
        // Dataset 2.0.0: 1975-01-01 ↔ 1918-04-13, 2084-12-30 ↔ 2028-04-12.
        // The lower bound follows from the table's first year, not from a
        // constant here.
        #expect(model.minAD == GADay(year: 1918, month: 4, day: 13))
        #expect(model.maxAD == GADay(year: 2028, month: 4, day: 12))
        #expect(model.adMonths(year: 1918).first == 4)
        #expect(model.adMonths(year: 2028).last == 4)
        #expect(model.adMonths(year: 2026).count == 12)
    }

    @Test func adDateClampsIntoConvertibleSpan() {
        // Asked for 1 January 1913, five years before the range now starts.
        // The clamp must pull it forward to the first convertible day, not
        // leave it outside the span. `init` runs it, so an out-of-range
        // argument cannot leave the model holding a day it cannot convert.
        let model = ConverterModel(
            direction: .adToBS, bsYear: 2083, bsMonth: 6, bsDay: 11,
            adYear: 1913, adMonth: 1, adDay: 1
        )
        #expect((model.adYear, model.adMonth, model.adDay) == (1918, 4, 13))
    }

    // The bundled picker state is `private(set)`, so these four are the only
    // way a caller can change it. Each one therefore has to land the *stored*
    // date in range on its own: `bsDate`/`adDate` are read back directly, not
    // through the clamping accessors, so an unclamped value cannot hide behind
    // an accessor that re-clamps on the way out.

    @Test func bsYearAboveTheSupportedRangeClampsToItsUpperBound() {
        let model = bsModel()
        // The bundled dataset supports 1975...2084, so 3000 has no month row
        // to clamp against. The setter has to pull it back to 2084 rather than
        // leave a year the pickers' month-length lookup traps on.
        model.bsYear = 3000
        #expect(model.bsDate.year == 2084)
    }

    @Test func bsDayBeyondTheRealMonthLengthClampsToThatMonth() {
        let model = bsModel()
        // Projected Jestha 2084 has 32 days, so day 40 clamps to 32.
        // A 30-day month would let an unclamped day pass unnoticed, which is
        // why this picks a month whose length is not 30.
        model.bsYear = 2084
        model.bsMonth = 2
        model.bsDay = 40
        #expect(model.bsDate == BSDay(year: 2084, month: 2, day: 32))
    }

    @Test func adYearAboveTheConvertibleSpanClampsToItsLastDay() {
        let model = bsModel()
        // The dataset's convertible span ends on 12 April 2028, so 3000 has no
        // counterpart in the table at all. The setter has to land on that last
        // convertible day, not merely on the year 2028.
        model.adYear = 3000
        #expect(model.adDate == GADay(year: 2028, month: 4, day: 12))
    }

    @Test func adDayBeyondTheRealMonthLengthClampsToThatMonth() {
        let model = bsModel()
        // January 2026 runs 31 days, so the 40th has to come back as the 31st.
        model.adYear = 2026
        model.adMonth = 1
        model.adDay = 40
        #expect(model.adDate == GADay(year: 2026, month: 1, day: 31))
    }

    @Test func adDaysBoundedAtSpanEdges() {
        let model = bsModel()
        #expect(model.adDays(year: 1918, month: 4).first == 13)
        #expect(model.adDays(year: 1918, month: 4).last == 30)
        #expect(model.adDays(year: 2028, month: 4).last == 12)
        #expect(model.adDays(year: 2026, month: 9).count == 30)
    }

    @Test func bundledDatesMatchPickers() {
        let model = bsModel()
        #expect(model.bsDate == BSDay(year: 2083, month: 6, day: 11))
        #expect(model.adDate == GADay(year: 2026, month: 9, day: 27))
    }

    /// The picker bounds must come from the dataset, never from a range literal
    /// in this model. ADR-0010 relies on that: a future dataset release has to
    /// move the Gregorian span on its own. A single-year table is the proof —
    /// its span is nowhere near the bundled one, so a baked-in constant would
    /// fail here.
    ///
    /// The Gregorian dates below are not claims about the real calendar. They
    /// fall out of the fixture by construction: 1 Baisakh 2000 is the anchor,
    /// and the year is 365 days long, so the last day is 364 days later.
    @Test func pickerSpanFollowsTheDatasetNotAConstant() {
        let narrow = CalendarDataset(
            version: "test",
            years: [2000: [31, 31, 32, 31, 31, 31, 30, 29, 30, 29, 30, 30]],
            anchorBS: BSDay(year: 2000, month: 1, day: 1),
            anchorAD: GADay(year: 1943, month: 4, day: 14),
            supportedRange: 2000 ... 2000
        )
        let model = ConverterModel(dataset: narrow)

        #expect(model.bsYears == [2000])
        #expect(model.minAD == GADay(year: 1943, month: 4, day: 14))
        #expect(model.maxAD == GADay(year: 1944, month: 4, day: 12))
        #expect(model.adYears == [1943, 1944])
        #expect(model.adMonths(year: 1943) == Array(4 ... 12))
        #expect(model.adMonths(year: 1944) == Array(1 ... 4))
    }

    // The supported range is 1975-2084 BS, 13 April 1918 through 12 April 2028
    // (CONTEXT.md); 30 Chaitra 2084 is its last day (RoundTripTests).
    @Test("Past the supported range, both pickers open on its last day")
    func defaultsPastTheRangeNameTheLastSupportedDay() throws {
        // 06:00 UTC is 11:45 Nepal Time on 13 April 2028, the day after the range.
        for now in [try TestDates.utc(2028, 4, 13, 6, 0), try TestDates.utc(2030, 5, 12, 6, 0)] {
            let model = ConverterModel(now: now)
            #expect(model.adDate == GADay(year: 2028, month: 4, day: 12))
            #expect(model.bsDate == BSDay(year: 2084, month: 12, day: 30))
            #expect(bsToAD(model.bsDate, in: AppData.dataset) == model.adDate)
        }
    }

    @Test("Before the supported range, both pickers open on its first day")
    func defaultsBeforeTheRangeNameTheFirstSupportedDay() throws {
        let model = ConverterModel(now: try TestDates.utc(1900, 1, 1, 6, 0))
        #expect(model.adDate == GADay(year: 1918, month: 4, day: 13))
        #expect(model.bsDate == BSDay(year: 1975, month: 1, day: 1))
        #expect(bsToAD(model.bsDate, in: AppData.dataset) == model.adDate)
    }

    @Test("Inside the supported range, both pickers open on today in Nepal Time")
    func defaultsInsideTheRangeNameToday() throws {
        // 27 September 2026 is 11 Ashoj 2083 (see `bsToADKnownDateWithWeekday`).
        let model = ConverterModel(now: try TestDates.utc(2026, 9, 27, 12, 0))
        #expect(model.adDate == GADay(year: 2026, month: 9, day: 27))
        #expect(model.bsDate == BSDay(year: 2083, month: 6, day: 11))
        #expect(bsToAD(model.bsDate, in: AppData.dataset) == model.adDate)
    }

    // 22 Bhadra 2084 is 8 September 2027 (Projected2084Tests); 2084 is the
    // dataset's provisional row, 2083 is attested (SOURCES.md).
    @Test("A Bikram Sambat to Gregorian result from 2084 is provisional, shown and spoken")
    func bsToADResultInAProvisionalYear() {
        let model = ConverterModel(direction: .bsToAD, bsYear: 2084, bsMonth: 5, bsDay: 22, adYear: 2027, adMonth: 9, adDay: 8)
        let settings = DisplaySettings(digits: .latin, monthNames: .transliterated)
        #expect(model.resultIsProvisional)
        #expect(model.convertedText(settings: settings) == "8 September 2027 · Wednesday")
        #expect(model.spokenResult(settings: settings) == "8 September 2027, Wednesday. Provisional projection, not yet in the official Nepali Patro")
    }

    @Test("A Gregorian to Bikram Sambat result landing in 2084 is provisional")
    func adToBSResultInAProvisionalYear() {
        let model = ConverterModel(direction: .adToBS, bsYear: 2083, bsMonth: 6, bsDay: 11, adYear: 2027, adMonth: 9, adDay: 8)
        let settings = DisplaySettings(digits: .latin, monthNames: .transliterated)
        #expect(model.resultIsProvisional)
        #expect(model.spokenResult(settings: settings)?.hasSuffix(". Provisional projection, not yet in the official Nepali Patro") == true)
    }

    @Test("Results in attested years carry no provisional note, both directions")
    func attestedResultsAreNotProvisional() {
        let settings = DisplaySettings(digits: .latin, monthNames: .transliterated)
        let bsSide = bsModel()
        #expect(!bsSide.resultIsProvisional)
        #expect(bsSide.spokenResult(settings: settings) == "27 September 2026, Sunday")
        // 13 April 2027 is the last day of 2083 (Chaitra 30); 2084 starts the next day.
        let adSide = ConverterModel(direction: .adToBS, bsYear: 2083, bsMonth: 6, bsDay: 11, adYear: 2027, adMonth: 4, adDay: 13)
        #expect(!adSide.resultIsProvisional)
        #expect(adSide.spokenResult(settings: settings)?.contains("Provisional") == false)
    }

    @Test("The About note is generated from the dataset's provisional years")
    func provisionalYearsNoteFollowsTheDataset() {
        #expect(Strings.provisionalYearsNote([2084]) == "2084 BS is a provisional projection until the official Nepali Patro is published.")
        #expect(Strings.provisionalYearsNote([]) == nil)
        #expect(Strings.provisionalYearsNote(AppData.dataset.provisionalYears) != nil)
    }

    @Test func showingABikramSambatDateOpensBSToADOnIt() {
        let model = ConverterModel(
            direction: .adToBS,
            bsYear: 2083, bsMonth: 6, bsDay: 11,
            adYear: 2026, adMonth: 9, adDay: 27
        )
        let settings = DisplaySettings(digits: .latin, monthNames: .transliterated)
        model.show(bikramSambat: BSDay(year: 2082, month: 1, day: 1))
        #expect(model.direction == .bsToAD)
        #expect(model.bsDate == BSDay(year: 2082, month: 1, day: 1))
        #expect(model.convertedText(settings: settings) == "14 April 2025 · Monday")
    }

    @Test func showingADateOutsideTheTableClampsIt() {
        let model = bsModel()
        model.show(bikramSambat: BSDay(year: 2200, month: 12, day: 40))
        #expect(model.bsDate.year == AppData.dataset.supportedRange.upperBound)
        #expect(model.bsDate.month == 12)
        #expect(model.bsDate.day == model.daysInBSMonth(year: model.bsDate.year, month: 12))
    }

    @Test func theDirectionPickerBindingCarriesTheDateAcross() {
        let model = bsModel()
        #expect(model.directionSelection == .bsToAD)
        model.directionSelection = .adToBS
        #expect(model.direction == .adToBS)
        #expect(model.adDate == GADay(year: 2026, month: 9, day: 27))
        model.directionSelection = .adToBS
        #expect(model.direction == .adToBS)
    }
}
