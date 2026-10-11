// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel

// Public holidays for 2083 BS, from the Home Ministry's notice in the Nepal
// Gazette (खण्ड ७५ संख्या ६७, भाग ५, 2082-11-18), pages 2-6. One row per
// gazette item, in the gazette's own wording, with its section in a trailing
// comment so each row can be checked against the page. A day can carry
// several rows: 18 Baisakh is three nationwide items, 13 Bhadra is one for
// the Newar community and one for Kathmandu Valley. Jitiya (3 ख) is only for
// women employees who observe it, which is narrower than Teej (3 क).
//
// Left out because the gazette gives no date: Eid ul-Fitr and Eid ul-Adha
// (2.1 त, थ), Siruwa Pawani (2.2 घ), Bhoto Jatra (5 ग) and Mohammad Jayanti
// (7.2 ख). Guru Nanak Jayanti (7.2 ग) has no gazette date either; it sits on
// 8 Mangsir, where the Panchanga prints it. The national days kept with
// offices open (section 8) are not holidays and are festival entries instead.

let publicHolidays2083: [BSDay: [PublicHoliday]] = [
    BSDay(year: 2083, month: 1, day: 1): [
        PublicHoliday(scope: .nationwide, nepali: "नव वर्ष"), // 2.1(क)
    ],
    BSDay(year: 2083, month: 1, day: 18): [
        PublicHoliday(scope: .nationwide, nepali: "चण्डी पूर्णिमा - बुद्ध जयन्ती, उभौली पर्व"), // 2.1(ख)
        PublicHoliday(scope: .nationwide, nepali: "विश्व मजदुर दिवस"), // 6.1(क)
        PublicHoliday(scope: .nationwide, nepali: "बुद्ध जयन्ती"), // 7.1(क)
    ],
    BSDay(year: 2083, month: 2, day: 15): [
        PublicHoliday(scope: .nationwide, nepali: "गणतन्त्र दिवस"), // 6.1(ख)
    ],
    BSDay(year: 2083, month: 5, day: 12): [
        PublicHoliday(scope: .nationwide, nepali: "रक्षाबन्धन"), // 2.1(ग)
    ],
    BSDay(year: 2083, month: 5, day: 13): [
        PublicHoliday(scope: .newarCommunity, nepali: "गाईजात्रा (देशभरका नेवार समुदायका लागि मात्र)"), // 2.2(क)
        PublicHoliday(scope: .kathmanduValley, nepali: "गाईजात्रा"), // 5(क)
    ],
    BSDay(year: 2083, month: 5, day: 19): [
        PublicHoliday(scope: .nationwide, nepali: "श्रीकृष्ण जन्माष्टमी"), // 2.1(घ)
        PublicHoliday(scope: .gauraRegion, nepali: "गौरा पर्व"), // 2.2(ख)
    ],
    BSDay(year: 2083, month: 5, day: 29): [
        PublicHoliday(scope: .womenEmployees, nepali: "हरितालिका (तीज) व्रत"), // 3(क)
    ],
    BSDay(year: 2083, month: 6, day: 3): [
        PublicHoliday(scope: .nationwide, nepali: "संविधान दिवस (राष्ट्रिय दिवस)"), // 6.1(ग)
    ],
    BSDay(year: 2083, month: 6, day: 9): [
        PublicHoliday(scope: .kathmanduValley, nepali: "इन्द्रजात्रा"), // 5(ख)
    ],
    BSDay(year: 2083, month: 6, day: 18): [
        PublicHoliday(scope: .womenObservingJitiya, nepali: "जितिया पर्व"), // 3(ख)
    ],
    BSDay(year: 2083, month: 6, day: 25): [
        PublicHoliday(scope: .nationwide, nepali: "घटस्थापना"), // 2.1(ङ)
    ],
    BSDay(year: 2083, month: 6, day: 31): [
        PublicHoliday(scope: .nationwide, nepali: "दशैं बिदा"), // 2.1(च)
    ],
    BSDay(year: 2083, month: 7, day: 1): [
        PublicHoliday(scope: .nationwide, nepali: "दशैं बिदा"), // 2.1(च)
    ],
    BSDay(year: 2083, month: 7, day: 2): [
        PublicHoliday(scope: .nationwide, nepali: "दशैं बिदा"), // 2.1(च)
    ],
    BSDay(year: 2083, month: 7, day: 3): [
        PublicHoliday(scope: .nationwide, nepali: "दशैं बिदा"), // 2.1(च)
    ],
    BSDay(year: 2083, month: 7, day: 4): [
        PublicHoliday(scope: .nationwide, nepali: "दशैं बिदा"), // 2.1(च)
    ],
    BSDay(year: 2083, month: 7, day: 5): [
        PublicHoliday(scope: .nationwide, nepali: "दशैं बिदा"), // 2.1(च)
    ],
    BSDay(year: 2083, month: 7, day: 6): [
        PublicHoliday(scope: .nationwide, nepali: "दशैं बिदा"), // 2.1(च)
    ],
    BSDay(year: 2083, month: 7, day: 22): [
        PublicHoliday(scope: .nationwide, nepali: "तिहार बिदा"), // 2.1(छ)
    ],
    BSDay(year: 2083, month: 7, day: 23): [
        PublicHoliday(scope: .nationwide, nepali: "तिहार बिदा"), // 2.1(छ)
    ],
    BSDay(year: 2083, month: 7, day: 24): [
        PublicHoliday(scope: .nationwide, nepali: "तिहार बिदा"), // 2.1(छ)
    ],
    BSDay(year: 2083, month: 7, day: 25): [
        PublicHoliday(scope: .nationwide, nepali: "तिहार बिदा"), // 2.1(छ)
        PublicHoliday(scope: .kiratCommunity, nepali: "फाल्गुनन्द जयन्ती"), // 7.2(क)
    ],
    BSDay(year: 2083, month: 7, day: 26): [
        PublicHoliday(scope: .nationwide, nepali: "तिहार बिदा"), // 2.1(छ)
    ],
    BSDay(year: 2083, month: 7, day: 29): [
        PublicHoliday(scope: .nationwide, nepali: "छठ पर्व"), // 2.1(ज)
    ],
    BSDay(year: 2083, month: 8, day: 8): [
        PublicHoliday(scope: .sikhCommunity, nepali: "गुरु नानक जयन्ती"), // 7.2(ग)
    ],
    BSDay(year: 2083, month: 8, day: 17): [
        PublicHoliday(scope: .employeesWithDisabilities, nepali: "अन्तर्राष्ट्रिय अपाङ्गता दिवस"), // 6.2
    ],
    BSDay(year: 2083, month: 9, day: 9): [
        PublicHoliday(scope: .nationwide, nepali: "धान्य पूर्णिमा - उधौली पर्व, योमरी पुन्हि, ज्यापू दिवस"), // 2.1(झ)
    ],
    BSDay(year: 2083, month: 9, day: 10): [
        PublicHoliday(scope: .nationwide, nepali: "क्रिसमस डे"), // 2.1(ञ)
    ],
    BSDay(year: 2083, month: 9, day: 15): [
        PublicHoliday(scope: .nationwide, nepali: "तमू ल्होछार"), // 2.1(ट)
        PublicHoliday(scope: .duraCommunity, nepali: "दुरा म्हैप्रु नकुमा"), // 2.2(ग)
    ],
    BSDay(year: 2083, month: 9, day: 27): [
        PublicHoliday(scope: .nationwide, nepali: "पृथ्वी जयन्ती (राष्ट्रिय एकता दिवस)"), // 7.1(ख)
    ],
    BSDay(year: 2083, month: 10, day: 1): [
        PublicHoliday(scope: .nationwide, nepali: "माघी पर्व/माघे सङ्क्रान्ति"), // 2.1(ठ)
    ],
    BSDay(year: 2083, month: 10, day: 16): [
        PublicHoliday(scope: .nationwide, nepali: "सहिद दिवस"), // 6.1(घ)
    ],
    BSDay(year: 2083, month: 10, day: 24): [
        PublicHoliday(scope: .nationwide, nepali: "सोनम ल्होछार"), // 2.1(ड)
    ],
    BSDay(year: 2083, month: 10, day: 28): [
        PublicHoliday(scope: .educationalInstitutions, nepali: "वसन्त पञ्चमी"), // 4
    ],
    BSDay(year: 2083, month: 11, day: 7): [
        PublicHoliday(scope: .nationwide, nepali: "राष्ट्रिय प्रजातन्त्र दिवस"), // 6.1(ङ)
    ],
    BSDay(year: 2083, month: 11, day: 22): [
        PublicHoliday(scope: .nationwide, nepali: "महाशिवरात्री"), // 2.1(ढ)
    ],
    BSDay(year: 2083, month: 11, day: 24): [
        PublicHoliday(scope: .nationwide, nepali: "अन्तर्राष्ट्रिय महिला दिवस"), // 6.1(च)
    ],
    BSDay(year: 2083, month: 11, day: 25): [
        PublicHoliday(scope: .nationwide, nepali: "ग्याल्पो ल्होसार"), // 2.1(ण)
    ],
    BSDay(year: 2083, month: 12, day: 7): [
        PublicHoliday(scope: .hillAndMountainDistricts, nepali: "फागुपूर्णिमा"), // 2.1(द)
    ],
    BSDay(year: 2083, month: 12, day: 8): [
        PublicHoliday(scope: .taraiDistricts, nepali: "फागुपूर्णिमा"), // 2.1(द)
    ],
    BSDay(year: 2083, month: 12, day: 23): [
        PublicHoliday(scope: .kathmanduValley, nepali: "घोडेजात्रा"), // 5(घ)
    ],
]
