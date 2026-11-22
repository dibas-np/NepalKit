// SPDX-License-Identifier: MIT
// Copyright (C) 2026 Dibas Sigdel

// Festivals and national days for 2083 BS from the national Panchanga
// (pinned in SOURCES.md), selected under ADR-0016, in the Panchanga's wording
// with outer brackets dropped. Every gazetted day is included; the two the
// Panchanga does not print are marked `source: .gazette`.

let festivals2083: [BikramSambatDate: [Festival]] = [
    BikramSambatDate(year: 2083, month: 1, day: 1): [
        Festival(nepali: "नववर्षारम्भ", english: "Nepali New Year"),
    ],
    BikramSambatDate(year: 2083, month: 1, day: 4): [
        Festival(nepali: "आमाको मुख हेर्ने", english: "Mother's Day (Mata Tirtha Aunsi)"),
    ],
    BikramSambatDate(year: 2083, month: 1, day: 7): [
        Festival(nepali: "अक्षयतृतीया", english: "Akshaya Tritiya"),
    ],
    BikramSambatDate(year: 2083, month: 1, day: 11): [
        Festival(nepali: "लोकतन्त्र दिवस", english: "Loktantra Diwas", kind: .nationalDay),
    ],
    BikramSambatDate(year: 2083, month: 1, day: 18): [
        Festival(nepali: "गौतमबुद्धजयन्ती", english: "Buddha Jayanti"),
        Festival(nepali: "उभौलीपर्व", english: "Ubhauli"),
        Festival(nepali: "मजदूर दिवस", english: "Labour Day", kind: .internationalDay),
    ],
    BikramSambatDate(year: 2083, month: 2, day: 15): [
        Festival(nepali: "गणतन्त्र दिवस", english: "Ganatantra Diwas (Republic Day)", kind: .nationalDay),
    ],
    BikramSambatDate(year: 2083, month: 2, day: 21): [
        Festival(nepali: "जातीय भेदभाव तथा छुवाछुत उन्मूलन राष्ट्रिय दिवस", english: "National Day against Caste Discrimination and Untouchability", kind: .nationalDay),
    ],
    BikramSambatDate(year: 2083, month: 3, day: 15): [
        Festival(nepali: "धानदिवस", english: "National Paddy Day", kind: .nationalDay),
    ],
    BikramSambatDate(year: 2083, month: 3, day: 29): [
        Festival(nepali: "भानुजयन्ती", english: "Bhanu Jayanti"),
    ],
    BikramSambatDate(year: 2083, month: 4, day: 13): [
        Festival(nepali: "गुरुपूर्णिमा", english: "Guru Purnima"),
    ],
    BikramSambatDate(year: 2083, month: 4, day: 26): [
        Festival(nepali: "घण्टाकर्ण चतुर्दशी", english: "Gathemangal (Ghantakarna)"),
    ],
    BikramSambatDate(year: 2083, month: 5, day: 1): [
        Festival(nepali: "नागपञ्चमी", english: "Nag Panchami"),
    ],
    BikramSambatDate(year: 2083, month: 5, day: 12): [
        Festival(nepali: "जनैपूर्णिमा", english: "Janai Purnima"),
        Festival(nepali: "रक्षाबन्धन", english: "Raksha Bandhan"),
    ],
    BikramSambatDate(year: 2083, month: 5, day: 13): [
        Festival(nepali: "गाईजात्रा", english: "Gai Jatra"),
    ],
    BikramSambatDate(year: 2083, month: 5, day: 19): [
        Festival(nepali: "श्रीकृष्णजन्माष्टमीव्रत", english: "Krishna Janmashtami"),
        Festival(nepali: "गौरापर्व", english: "Gaura Parva"),
    ],
    BikramSambatDate(year: 2083, month: 5, day: 22): [
        Festival(nepali: "निजामती सेवादिवस", english: "Civil Service Day", kind: .nationalDay),
    ],
    BikramSambatDate(year: 2083, month: 5, day: 23): [
        Festival(nepali: "जेनजी सहिद दिवस", english: "GenZ Martyrs' Day", kind: .nationalDay, source: .gazette),
    ],
    BikramSambatDate(year: 2083, month: 5, day: 26): [
        Festival(nepali: "बाबुको मुख हेर्नेदिन", english: "Father's Day (Kushe Aunsi)"),
    ],
    BikramSambatDate(year: 2083, month: 5, day: 29): [
        Festival(nepali: "हरितालिकाव्रत (तीज)", english: "Teej"),
    ],
    BikramSambatDate(year: 2083, month: 5, day: 30): [
        Festival(nepali: "ऋषिपञ्चमीव्रत", english: "Rishi Panchami"),
    ],
    BikramSambatDate(year: 2083, month: 6, day: 3): [
        Festival(nepali: "संविधानदिवस", english: "Sambidhan Diwas (Constitution Day)", kind: .nationalDay),
    ],
    BikramSambatDate(year: 2083, month: 6, day: 9): [
        Festival(nepali: "कुमारीइन्द्रयात्रा", english: "Indra Jatra"),
    ],
    BikramSambatDate(year: 2083, month: 6, day: 18): [
        Festival(nepali: "जितियापर्व", english: "Jitiya"),
    ],
    BikramSambatDate(year: 2083, month: 6, day: 25): [
        Festival(nepali: "घटस्थापना", english: "Ghatasthapana"),
    ],
    BikramSambatDate(year: 2083, month: 6, day: 31): [
        Festival(nepali: "फूलपाती", english: "Fulpati"),
    ],
    BikramSambatDate(year: 2083, month: 7, day: 1): [
        Festival(nepali: "महाष्टमीव्रत", english: "Maha Ashtami"),
    ],
    BikramSambatDate(year: 2083, month: 7, day: 3): [
        Festival(nepali: "महानवमी", english: "Maha Navami"),
    ],
    BikramSambatDate(year: 2083, month: 7, day: 4): [
        Festival(nepali: "विजयादशमी", english: "Vijaya Dashami (Dashain Tika)"),
    ],
    BikramSambatDate(year: 2083, month: 7, day: 8): [
        Festival(nepali: "कोजाग्रतव्रत", english: "Kojagrat Purnima"),
    ],
    BikramSambatDate(year: 2083, month: 7, day: 21): [
        Festival(nepali: "कागतिहार", english: "Kag Tihar"),
    ],
    BikramSambatDate(year: 2083, month: 7, day: 22): [
        Festival(nepali: "कुकुरतिहार", english: "Kukur Tihar"),
        Festival(nepali: "लक्ष्मीपूजा", english: "Laxmi Puja"),
    ],
    BikramSambatDate(year: 2083, month: 7, day: 23): [
        Festival(nepali: "गाईपूजा", english: "Gai Puja"),
    ],
    BikramSambatDate(year: 2083, month: 7, day: 24): [
        Festival(nepali: "गोवर्धनपूजा", english: "Govardhan Puja"),
        Festival(nepali: "म्हपूजा", english: "Mha Puja"),
        Festival(nepali: "ने.सं.११४७ प्रारम्भ", english: "Nepal Sambat New Year 1147"),
    ],
    BikramSambatDate(year: 2083, month: 7, day: 25): [
        Festival(nepali: "भाइटीका", english: "Bhai Tika"),
        Festival(nepali: "फाल्गुनन्दजयन्ती", english: "Falgunanda Jayanti"),
    ],
    BikramSambatDate(year: 2083, month: 7, day: 29): [
        Festival(nepali: "छठपर्व", english: "Chhath"),
    ],
    BikramSambatDate(year: 2083, month: 8, day: 8): [
        Festival(nepali: "गुरुनानकजयन्ती", english: "Guru Nanak Jayanti"),
    ],
    BikramSambatDate(year: 2083, month: 8, day: 17): [
        Festival(nepali: "विश्व अपाङ्ग दिवस", english: "International Day of Persons with Disabilities", kind: .internationalDay),
    ],
    BikramSambatDate(year: 2083, month: 8, day: 28): [
        Festival(nepali: "विवाहपञ्चमी", english: "Bibaha Panchami"),
    ],
    BikramSambatDate(year: 2083, month: 9, day: 9): [
        Festival(nepali: "उधौलीपर्व", english: "Udhauli"),
        Festival(nepali: "योमरीपून्हि", english: "Yomari Punhi"),
        Festival(nepali: "ज्यापू दिवस", english: "Jyapu Diwas", kind: .nationalDay, source: .gazette),
    ],
    BikramSambatDate(year: 2083, month: 9, day: 10): [
        Festival(nepali: "क्रिसमस डे", english: "Christmas"),
    ],
    BikramSambatDate(year: 2083, month: 9, day: 15): [
        Festival(nepali: "तमुल्होछार", english: "Tamu Lhosar"),
        Festival(nepali: "दुरा म्हैप्रु नकुमा", english: "Dura Mhaipru Nakuma"),
    ],
    BikramSambatDate(year: 2083, month: 9, day: 24): [
        Festival(nepali: "तोल ल्होसार", english: "Tol Lhosar"),
    ],
    BikramSambatDate(year: 2083, month: 9, day: 27): [
        Festival(nepali: "पृथ्वीजयन्ती", english: "Prithvi Jayanti"),
        Festival(nepali: "राष्ट्रिय एकता दिवस", english: "Rashtriya Ekata Diwas (National Unity Day)", kind: .nationalDay),
    ],
    BikramSambatDate(year: 2083, month: 10, day: 1): [
        Festival(nepali: "माघसङ्क्रान्ति", english: "Maghe Sankranti"),
        Festival(nepali: "माघीपर्व", english: "Maghi"),
    ],
    BikramSambatDate(year: 2083, month: 10, day: 16): [
        Festival(nepali: "सहिद दिवस", english: "Shahid Diwas (Martyrs' Day)", kind: .nationalDay),
    ],
    BikramSambatDate(year: 2083, month: 10, day: 24): [
        Festival(nepali: "सोनम ल्होसार/तामाङ ल्होछार", english: "Sonam Lhosar"),
    ],
    BikramSambatDate(year: 2083, month: 10, day: 28): [
        Festival(nepali: "श्रीपञ्चमी", english: "Basanta Panchami (Saraswati Puja)"),
    ],
    BikramSambatDate(year: 2083, month: 11, day: 7): [
        Festival(nepali: "राष्ट्रिय प्रजातन्त्र दिवस", english: "Prajatantra Diwas (Democracy Day)", kind: .nationalDay),
    ],
    BikramSambatDate(year: 2083, month: 11, day: 22): [
        Festival(nepali: "महाशिवरात्रिव्रत", english: "Maha Shivaratri"),
    ],
    BikramSambatDate(year: 2083, month: 11, day: 24): [
        Festival(nepali: "अन्तर्राष्ट्रिय नारी दिवस", english: "International Women's Day", kind: .internationalDay),
    ],
    BikramSambatDate(year: 2083, month: 11, day: 25): [
        Festival(nepali: "ग्याल्पो ल्होसार", english: "Gyalpo Lhosar"),
    ],
    BikramSambatDate(year: 2083, month: 12, day: 7): [
        Festival(nepali: "पहाडी जिल्लामा होली", english: "Holi (hill districts)"),
    ],
    BikramSambatDate(year: 2083, month: 12, day: 8): [
        Festival(nepali: "तराईमा होली", english: "Holi (Tarai)"),
    ],
    BikramSambatDate(year: 2083, month: 12, day: 23): [
        Festival(nepali: "घोडेजात्रा", english: "Ghode Jatra"),
    ],
]
