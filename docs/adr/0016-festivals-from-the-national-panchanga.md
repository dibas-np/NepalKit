# Festivals and national days from the national Panchanga

Date: 2026-10-11
Status: accepted

## Context

A Nepali calendar without its festivals is half a calendar. The month grid
(1.7.0) shows every day of the month, so the question of which days matter
now has a place to be answered.

Festival dates cannot be computed from the month table. Most follow the lunar
calendar (tithi), and their placement is a determination, not arithmetic. The
government's Nepal Panchanga Nirnayak Samiti publishes that determination each
year as the national Panchanga (राष्ट्रिय पञ्चाङ्ग). SOURCES.md already pins the
2083 edition and uses it to confirm that year's month lengths.

Each day's row in the Panchanga lists observances (व्रतपर्व विवरण): festivals,
fasts, local jatras, Newar observances, national and international days, and
timing notes. That is several hundred entries a year. Shown in full they would
put a mark on almost every day and stop meaning anything.

## Decision

1. **One source.** Festival and national-day dates come only from the national
   Panchanga for the year, pinned by URL and SHA-256 in SOURCES.md. Nothing is
   added that the Panchanga does not print on that day, and no other calendar,
   website or app is consulted for dates.

2. **A named selection, not the Panchanga's emphasis.** The Panchanga's bold
   type is not a guide to importance: it prints प्रदोषव्रत in bold and the New
   Year (नववर्षारम्भ) in regular type. NepalKit includes:
   - **Major festivals**, observed across Nepal or by a large community, once a
     year: for example Nepali New Year, Buddha Jayanti, Janai Purnima, Teej,
     Krishna Janmashtami, the main days of Dashain and Tihar, Chhath, Maghe
     Sankranti, Sonam and Gyalpo Lhosar, Maha Shivaratri, Holi, Ram Navami,
     Ubhauli and Udhauli, Indra Jatra and Christmas, where the Panchanga
     prints them.
   - **National days** of Nepal that the Panchanga prints, such as Ganatantra
     Diwas and Sambidhan Diwas.
   It excludes observances that recur every fortnight or month (Ekadashi,
   Pradosh, the monthly Purnima and Aunsi fasts, monthly Sankranti), local
   jatras, the international days, and the timing notes. A once-a-year
   festival that happens to fall on a Purnima or an Aunsi is still a yearly
   festival and is included: Kojagrat Purnima, Mata Tirtha Aunsi (Mother's
   Day) and Kushe Aunsi (Father's Day). The selected list is in the
   year's data file; each entry falls under one of the two bullets above.

3. **Typed by hand, checked twice.** The Panchanga is an image-only PDF. Each
   year's entries are read from it and typed in, with the Panchanga's own
   wording kept beside an English name. A second read checks every selected
   entry against the page it came from.

4. **Festivals, not holidays.** The Panchanga lists observances; public
   holidays are declared separately by the Government of Nepal. NepalKit says
   "festival" and "national day", never "public holiday".

5. **Only years with a Panchanga.** A year gets festivals once its Panchanga is
   published and read. 2084 has none until then, and the provisional 2084 row
   (ADR-0014) is not used to guess them.

## Consequences

- Each year costs a few hours of careful reading. The selection rule keeps that
  bounded and repeatable.
- The app shows nothing for years before 2083. That is a gap, not an error.
- Dates are facts from a government publication. No image or page layout is
  copied, only the day and the observance name.

## Amendment: public holidays from the Nepal Gazette (2026-10-11)

The Panchanga determines when observances fall; it does not say which days
are public holidays. The Government of Nepal decides that each year and
publishes it in the Nepal Gazette as a Ministry of Home Affairs notice
(for 2083: खण्ड ७५ संख्या ६७, भाग ५, dated 2082-11-18, pinned in SOURCES.md).

1. **Holiday status from the Gazette only.** A day is shown as a public
   holiday, and with what scope (nationwide, a community, a region, the
   Kathmandu Valley, women employees, educational institutions, employees
   with disabilities), only as the Gazette notice states it. Decision 4's
   "never public holiday" is replaced by this: the app says "public holiday"
   exactly where the Gazette does.
2. **Dates still from the Panchanga, with two exceptions.** Every holiday the
   Gazette gives a date for matches the Panchanga, except two national days
   the Panchanga does not print (ज्यापू दिवस and जेनजी सहिद दिवस). Those are
   added with the Gazette as their recorded source. Guru Nanak Jayanti has no
   Gazette date; its holiday sits on the day the Panchanga prints it.
3. **Holiday days join the festival list.** Days the Gazette makes holidays
   that decision 2's rule had left out (Labour Day, Women's Day, the
   disability day, Falgunanda Jayanti, Dura Mhaipru Nakuma, Prithvi Jayanti)
   and its national days with offices open are included, so a red day always
   has a name.
4. **Undated holidays are left out.** Eid ul-Fitr, Eid ul-Adha, Mohammad
   Jayanti, Siruwa Pawani and the Bhoto Jatra are listed "on the day" with no
   date, so there is no day to mark.
5. **Only nationwide holidays are red** in the month grid, alongside the
   weekly Saturday holiday. Limited holidays are named in the day's details.
