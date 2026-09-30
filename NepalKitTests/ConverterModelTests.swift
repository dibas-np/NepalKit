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
        #expect(model.daysInBSMonth(year: 2084, month: 3) == 32)
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
            direction: .bsToAD, bsYear: 2084, bsMonth: 3, bsDay: 32,
            adYear: 2026, adMonth: 9, adDay: 27
        )
        // Ashar 2084 has 32 days; Shrawan has 31 — the `bsMonth` setter
        // re-clamps, so writing the month alone must pull the day down.
        model.bsMonth = 4
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
        // Ashar 2084 runs 32 days, so the 40th has to come back as the 32nd.
        // A 30-day month would let an unclamped day pass unnoticed, which is
        // why this picks a month whose length is not 30.
        model.bsYear = 2084
        model.bsMonth = 3
        model.bsDay = 40
        #expect(model.bsDate == BSDay(year: 2084, month: 3, day: 32))
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
}
