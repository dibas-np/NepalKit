// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Dibas Sigdel

// Festivals and national days for 2083 BS, read from the national Panchanga
// for 2083 (SOURCES.md pins the file) and selected under ADR-0016. The Nepali
// names are the Panchanga's wording, with its outer brackets dropped for
// display: "(जितियापर्व)" and "(योमरीपून्हि, थिंलापून्हि)" are printed in brackets.
// Every entry was checked against its page by a second read.
//
// The selection also takes in every day the Home Ministry's gazette notice of
// public holidays and national days names (PublicHolidays2083.swift), so a
// holiday always has a name in the day's details. Where the Panchanga prints
// that day, its wording is used even though the selection had left it out:
// Labour Day, Caste Discrimination Day, Civil Service Day, Falgunanda
// Jayanti, Disability Day, Dura Mhaipru Nakuma, Prithvi Jayanti and Women's
// Day. Two the Panchanga does not print at all, Jyapu Diwas and GenZ Martyrs'
// Day, are named as the gazette names them and marked `source: .gazette`.

let festivals2083: [BSDay: [Festival]] = [
    BSDay(year: 2083, month: 1, day: 1): [
        Festival(nepali: "नववर्षारम्भ", english: "Nepali New Year"),
    ],
    BSDay(year: 2083, month: 1, day: 4): [
        Festival(nepali: "आमाको मुख हेर्ने", english: "Mother's Day (Mata Tirtha Aunsi)"),
    ],
    BSDay(year: 2083, month: 1, day: 7): [
        Festival(nepali: "अक्षयतृतीया", english: "Akshaya Tritiya"),
    ],
    BSDay(year: 2083, month: 1, day: 11): [
        Festival(nepali: "लोकतन्त्र दिवस", english: "Loktantra Diwas", kind: .nationalDay),
    ],
    BSDay(year: 2083, month: 1, day: 18): [
        Festival(nepali: "गौतमबुद्धजयन्ती", english: "Buddha Jayanti"),
        Festival(nepali: "उभौलीपर्व", english: "Ubhauli"),
        Festival(nepali: "मजदूर दिवस", english: "Labour Day", kind: .internationalDay),
    ],
    BSDay(year: 2083, month: 2, day: 15): [
        Festival(nepali: "गणतन्त्र दिवस", english: "Ganatantra Diwas (Republic Day)", kind: .nationalDay),
    ],
    BSDay(year: 2083, month: 2, day: 21): [
        Festival(nepali: "जातीय भेदभाव तथा छुवाछुत उन्मूलन राष्ट्रिय दिवस", english: "National Day against Caste Discrimination and Untouchability", kind: .nationalDay),
    ],
    BSDay(year: 2083, month: 3, day: 15): [
        Festival(nepali: "धानदिवस", english: "National Paddy Day", kind: .nationalDay),
    ],
    BSDay(year: 2083, month: 3, day: 29): [
        Festival(nepali: "भानुजयन्ती", english: "Bhanu Jayanti"),
    ],
    BSDay(year: 2083, month: 4, day: 13): [
        Festival(nepali: "गुरुपूर्णिमा", english: "Guru Purnima"),
    ],
    BSDay(year: 2083, month: 4, day: 26): [
        Festival(nepali: "घण्टाकर्ण चतुर्दशी", english: "Gathemangal (Ghantakarna)"),
    ],
    BSDay(year: 2083, month: 5, day: 1): [
        Festival(nepali: "नागपञ्चमी", english: "Nag Panchami"),
    ],
    BSDay(year: 2083, month: 5, day: 12): [
        Festival(nepali: "जनैपूर्णिमा", english: "Janai Purnima"),
        Festival(nepali: "रक्षाबन्धन", english: "Raksha Bandhan"),
    ],
    BSDay(year: 2083, month: 5, day: 13): [
        Festival(nepali: "गाईजात्रा", english: "Gai Jatra"),
    ],
    BSDay(year: 2083, month: 5, day: 19): [
        Festival(nepali: "श्रीकृष्णजन्माष्टमीव्रत", english: "Krishna Janmashtami"),
        Festival(nepali: "गौरापर्व", english: "Gaura Parva"),
    ],
    BSDay(year: 2083, month: 5, day: 22): [
        Festival(nepali: "निजामती सेवादिवस", english: "Civil Service Day", kind: .nationalDay),
    ],
    BSDay(year: 2083, month: 5, day: 23): [
        Festival(nepali: "जेनजी सहिद दिवस", english: "GenZ Martyrs' Day", kind: .nationalDay, source: .gazette),
    ],
    BSDay(year: 2083, month: 5, day: 26): [
        Festival(nepali: "बाबुको मुख हेर्नेदिन", english: "Father's Day (Kushe Aunsi)"),
    ],
    BSDay(year: 2083, month: 5, day: 29): [
        Festival(nepali: "हरितालिकाव्रत (तीज)", english: "Teej"),
    ],
    BSDay(year: 2083, month: 5, day: 30): [
        Festival(nepali: "ऋषिपञ्चमीव्रत", english: "Rishi Panchami"),
    ],
    BSDay(year: 2083, month: 6, day: 3): [
        Festival(nepali: "संविधानदिवस", english: "Sambidhan Diwas (Constitution Day)", kind: .nationalDay),
    ],
    BSDay(year: 2083, month: 6, day: 9): [
        Festival(nepali: "कुमारीइन्द्रयात्रा", english: "Indra Jatra"),
    ],
    BSDay(year: 2083, month: 6, day: 18): [
        Festival(nepali: "जितियापर्व", english: "Jitiya"),
    ],
    BSDay(year: 2083, month: 6, day: 25): [
        Festival(nepali: "घटस्थापना", english: "Ghatasthapana"),
    ],
    BSDay(year: 2083, month: 6, day: 31): [
        Festival(nepali: "फूलपाती", english: "Fulpati"),
    ],
    BSDay(year: 2083, month: 7, day: 1): [
        Festival(nepali: "महाष्टमीव्रत", english: "Maha Ashtami"),
    ],
    BSDay(year: 2083, month: 7, day: 3): [
        Festival(nepali: "महानवमी", english: "Maha Navami"),
    ],
    BSDay(year: 2083, month: 7, day: 4): [
        Festival(nepali: "विजयादशमी", english: "Vijaya Dashami (Dashain Tika)"),
    ],
    BSDay(year: 2083, month: 7, day: 8): [
        Festival(nepali: "कोजाग्रतव्रत", english: "Kojagrat Purnima"),
    ],
    BSDay(year: 2083, month: 7, day: 21): [
        Festival(nepali: "कागतिहार", english: "Kag Tihar"),
    ],
    BSDay(year: 2083, month: 7, day: 22): [
        Festival(nepali: "कुकुरतिहार", english: "Kukur Tihar"),
        Festival(nepali: "लक्ष्मीपूजा", english: "Laxmi Puja"),
    ],
    BSDay(year: 2083, month: 7, day: 23): [
        Festival(nepali: "गाईपूजा", english: "Gai Puja"),
    ],
    BSDay(year: 2083, month: 7, day: 24): [
        Festival(nepali: "गोवर्धनपूजा", english: "Govardhan Puja"),
        Festival(nepali: "म्हपूजा", english: "Mha Puja"),
        Festival(nepali: "ने.सं.११४७ प्रारम्भ", english: "Nepal Sambat New Year 1147"),
    ],
    BSDay(year: 2083, month: 7, day: 25): [
        Festival(nepali: "भाइटीका", english: "Bhai Tika"),
        Festival(nepali: "फाल्गुनन्दजयन्ती", english: "Falgunanda Jayanti"),
    ],
    BSDay(year: 2083, month: 7, day: 29): [
        Festival(nepali: "छठपर्व", english: "Chhath"),
    ],
    BSDay(year: 2083, month: 8, day: 8): [
        Festival(nepali: "गुरुनानकजयन्ती", english: "Guru Nanak Jayanti"),
    ],
    BSDay(year: 2083, month: 8, day: 17): [
        Festival(nepali: "विश्व अपाङ्ग दिवस", english: "International Day of Persons with Disabilities", kind: .internationalDay),
    ],
    BSDay(year: 2083, month: 8, day: 28): [
        Festival(nepali: "विवाहपञ्चमी", english: "Bibaha Panchami"),
    ],
    BSDay(year: 2083, month: 9, day: 9): [
        Festival(nepali: "उधौलीपर्व", english: "Udhauli"),
        Festival(nepali: "योमरीपून्हि", english: "Yomari Punhi"),
        Festival(nepali: "ज्यापू दिवस", english: "Jyapu Diwas", kind: .nationalDay, source: .gazette),
    ],
    BSDay(year: 2083, month: 9, day: 10): [
        Festival(nepali: "क्रिसमस डे", english: "Christmas"),
    ],
    BSDay(year: 2083, month: 9, day: 15): [
        Festival(nepali: "तमुल्होछार", english: "Tamu Lhosar"),
        Festival(nepali: "दुरा म्हैप्रु नकुमा", english: "Dura Mhaipru Nakuma"),
    ],
    BSDay(year: 2083, month: 9, day: 24): [
        Festival(nepali: "तोल ल्होसार", english: "Tol Lhosar"),
    ],
    BSDay(year: 2083, month: 9, day: 27): [
        Festival(nepali: "पृथ्वीजयन्ती", english: "Prithvi Jayanti"),
        Festival(nepali: "राष्ट्रिय एकता दिवस", english: "Rashtriya Ekata Diwas (National Unity Day)", kind: .nationalDay),
    ],
    BSDay(year: 2083, month: 10, day: 1): [
        Festival(nepali: "माघसङ्क्रान्ति", english: "Maghe Sankranti"),
        Festival(nepali: "माघीपर्व", english: "Maghi"),
    ],
    BSDay(year: 2083, month: 10, day: 16): [
        Festival(nepali: "सहिद दिवस", english: "Shahid Diwas (Martyrs' Day)", kind: .nationalDay),
    ],
    BSDay(year: 2083, month: 10, day: 24): [
        Festival(nepali: "सोनम ल्होसार/तामाङ ल्होछार", english: "Sonam Lhosar"),
    ],
    BSDay(year: 2083, month: 10, day: 28): [
        Festival(nepali: "श्रीपञ्चमी", english: "Basanta Panchami (Saraswati Puja)"),
    ],
    BSDay(year: 2083, month: 11, day: 7): [
        Festival(nepali: "राष्ट्रिय प्रजातन्त्र दिवस", english: "Prajatantra Diwas (Democracy Day)", kind: .nationalDay),
    ],
    BSDay(year: 2083, month: 11, day: 22): [
        Festival(nepali: "महाशिवरात्रिव्रत", english: "Maha Shivaratri"),
    ],
    BSDay(year: 2083, month: 11, day: 24): [
        Festival(nepali: "अन्तर्राष्ट्रिय नारी दिवस", english: "International Women's Day", kind: .internationalDay),
    ],
    BSDay(year: 2083, month: 11, day: 25): [
        Festival(nepali: "ग्याल्पो ल्होसार", english: "Gyalpo Lhosar"),
    ],
    BSDay(year: 2083, month: 12, day: 7): [
        Festival(nepali: "पहाडी जिल्लामा होली", english: "Holi (hill districts)"),
    ],
    BSDay(year: 2083, month: 12, day: 8): [
        Festival(nepali: "तराईमा होली", english: "Holi (Tarai)"),
    ],
    BSDay(year: 2083, month: 12, day: 23): [
        Festival(nepali: "घोडेजात्रा", english: "Ghode Jatra"),
    ],
]
