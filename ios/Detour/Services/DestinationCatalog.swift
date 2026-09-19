import Foundation

struct DestinationIdea: Identifiable, Sendable {
    let place: PlaceReference
    let interests: [TravelInterest]
    let summary: String
    let sourceURL: String
    var id: String { place.id }
}

// A curated prototype collection, with no live event, opening-time or rating claims.
enum DestinationCatalog {
    static let places: [DestinationIdea] = [
        idea("table-mountain", "Table Mountain", "Lower Cableway station", -33.9485, 18.4038, [.nature], "Take the cableway up for panoramic city and ocean views.", "tablemountain", "https://www.tablemountain.net/"),
        idea("lions-head", "Lion’s Head", "Signal Hill Drive · trail start", -33.9362, 18.3947, [.nature], "A mountain walk with the city at your feet.", "lionshead", "https://www.sanparks.org/parks/table-mountain/what-to-do/attractions/lions-head-signal-hill"),
        idea("zeitz", "Zeitz MOCAA", "Silo District · V&A Waterfront", -33.9083, 18.4228, [.arts, .culture], "Discover contemporary art from Africa and its diaspora.", "zeitz", "https://www.capetown.travel/listing/zeitz-mocaa/"),
        idea("bokaap", "Bo-Kaap", "Wale Street · Cape Town", -33.9217, 18.4150, [.culture, .history, .food], "Colourful streets, Cape Malay heritage and local flavours.", "bokaap", "https://www.capetown.travel/20-places-to-take-first-timers-to-cape-town/"),
        idea("boulders", "Boulders Beach", "Simon’s Town · penguin viewing", -34.1970, 18.4511, [.wildlife, .nature], "Meet the coast’s African penguin colony.", "boulders", "https://www.capetown.travel/listing/boulders-beach/"),
        idea("kirstenbosch", "Kirstenbosch Gardens", "Rhodes Drive · Newlands", -33.9880, 18.4320, [.nature, .arts], "Garden paths, sculpture and a canopy walk.", "kirstenbosch", "https://www.capetown.travel/listing/sanbi-kirstenbosch-gardens/"),
        idea("stadium", "DHL Stadium", "Green Point · Cape Town", -33.9031, 18.4113, [.sports], "A landmark destination for the sports fan in you.", "stadium", "https://dhlstadium.co.za/"),
        idea("aquarium", "Two Oceans Aquarium", "Dock Road · V&A Waterfront", -33.9075, 18.4176, [.wildlife, .nature], "Explore the ocean’s wildlife at the Waterfront.", "aquarium", "https://www.capetown.travel/listing/two-oceans-aquarium/"),
        DestinationIdea(place: Fixtures.nearby[0], interests: [.food, .shopping, .culture], summary: "Browse local makers and find something delicious.", sourceURL: "https://www.capetown.travel/20-places-to-take-first-timers-to-cape-town/"),
        idea("waterfront", "V&A Waterfront", "Victoria Wharf · Cape Town", -33.9037, 18.4207, [.shopping, .food, .culture], "Harbour-side browsing, places to eat and local discoveries.", "waterfront", "https://www.waterfront.co.za/"),
        idea("castle", "Castle of Good Hope", "Darling Street · Cape Town", -33.9259, 18.4271, [.history, .culture], "Explore a landmark that holds the city’s layered history.", "castle", "https://www.castleofgoodhope.co.za/"),
        DestinationIdea(place: Fixtures.nearby[1], interests: [.nature, .wildlife, .history], summary: "Take the scenic drive to the Cape Peninsula’s dramatic coast.", sourceURL: "https://www.sanparks.org/parks/table-mountain/what-to-do/attractions/cape-point")
    ]

    private static func idea(_ id: String, _ name: String, _ subtitle: String, _ lat: Double, _ lon: Double, _ interests: [TravelInterest], _ summary: String, _ image: String, _ source: String) -> DestinationIdea {
        DestinationIdea(place: PlaceReference(id: "demo-destination-\(id)", name: name, subtitle: subtitle,
                                             coordinate: .init(latitude: lat, longitude: lon),
                                             category: interests.contains(.food) ? .food : .scenic, photoName: "asset:destination-\(image)",
                                             photoAttributions: photoCredits[image].map { [$0] } ?? []),
                        interests: interests, summary: summary, sourceURL: source)
    }

    static func browse(interests: [TravelInterest], personalized: Bool, query: String = "") -> [DestinationIdea] {
        let selection = Set(interests)
        let collection = personalized ? places.enumerated().filter { !selection.isDisjoint(with: $0.element.interests) }.sorted { a, b in
            let firstMatches = selection.intersection(a.element.interests).count
            let secondMatches = selection.intersection(b.element.interests).count
            let first = firstMatches + (a.element.interests.count == 1 ? 1 : 0)
            let second = secondMatches + (b.element.interests.count == 1 ? 1 : 0)
            return first == second ? a.offset < b.offset : first > second
        }.map(\.element) : places
        let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return query.isEmpty ? collection : collection.filter {
            [$0.place.name, $0.place.subtitle, $0.summary] .joined(separator: " ").localizedCaseInsensitiveContains(query) ||
            $0.interests.contains { $0.title.localizedCaseInsensitiveContains(query) }
        }
    }

    static func details(_ id: String) -> PlaceReference? { places.first { $0.id == id }?.place }

    static func interests(for place: PlaceReference) -> [TravelInterest] {
        if let discovery = RouteDiscoveries.details(place.id) { return discovery.interests }
        if let idea = places.first(where: { $0.id == place.id }) { return idea.interests }
        switch place.id {
        case "demo-drostdy": return [.history, .culture]
        case "demo-goukamma": return [.wildlife, .nature]
        case "demo-map-africa", "demo-dolphin": return [.nature]
        default: return place.category == .food || place.category == .coffee ? [.food] : []
        }
    }

    static func isDetourExperience(_ id: String) -> Bool {
        RouteDiscoveries.details(id) != nil || places.contains { $0.id == id } || ["demo-drostdy", "demo-map-africa", "demo-goukamma"].contains(id)
    }

    static func categoryTitle(for place: PlaceReference) -> String {
        if isDetourExperience(place.id), let interest = interests(for: place).first { return interest.title }
        return place.category.title
    }

    static func summary(for id: String) -> String? {
        if let idea = places.first(where: { $0.id == id }) { return idea.summary }
        switch id {
        case "demo-drostdy": return "Leave the N2 for Swellendam’s history and the Drostdy Museum."
        case "demo-map-africa": return "Head into Wilderness Heights for a view over the river’s remarkable shape."
        case "demo-goukamma": return "Take Buffalo Bay Road off the N2 for coastal paths, dunes and the Goukamma estuary."
        default: return nil
        }
    }

    private static let photoCredits: [String: Attribution] = [
        "tablemountain": Attribution(name: "Danie van der Merwe · CC BY 2.0", uri: "https://commons.wikimedia.org/wiki/File:Table_Mountain_DanieVDM.jpg", licenseURI: "https://creativecommons.org/licenses/by/2.0/"),
        "lionshead": Attribution(name: "Daniel Case · CC BY-SA 3.0", uri: "https://commons.wikimedia.org/wiki/File:Fynbos,_Lion%27s_Head_and_trees_from_Table_Mountain_trail.jpg", licenseURI: "https://creativecommons.org/licenses/by-sa/3.0/"),
        "zeitz": Attribution(name: "Matti Blume · CC BY-SA 4.0", uri: "https://commons.wikimedia.org/wiki/File:Zeitz_Museum_of_Contemporary_Art_Africa,_Cape_Town_(_1050775).jpg", licenseURI: "https://creativecommons.org/licenses/by-sa/4.0/"),
        "bokaap": Attribution(name: "SkyPixels · CC BY-SA 4.0", uri: "https://commons.wikimedia.org/wiki/File:Boe-Kaap.jpg", licenseURI: "https://creativecommons.org/licenses/by-sa/4.0/"),
        "boulders": Attribution(name: "Olga Ernst · CC BY-SA 4.0", uri: "https://commons.wikimedia.org/wiki/File:Boulders_Beach_Suedafrika.jpg", licenseURI: "https://creativecommons.org/licenses/by-sa/4.0/"),
        "kirstenbosch": Attribution(name: "Discott · CC BY-SA 4.0", uri: "https://commons.wikimedia.org/wiki/File:Kirstenbosch_National_Botanical_Garden_2024_7th_batch_09.jpg", licenseURI: "https://creativecommons.org/licenses/by-sa/4.0/"),
        "stadium": Attribution(name: "Hansueli Krapf · CC BY-SA 4.0", uri: "https://en.wikipedia.org/wiki/File:South_Africa_-_Cape_Town_Drieankerbaai_from_Lion%27s_head.jpg", licenseURI: "https://creativecommons.org/licenses/by-sa/4.0/"),
        "aquarium": Attribution(name: "Jim.henderson · CC BY-SA 4.0", uri: "https://commons.wikimedia.org/wiki/File:Two_Oceans_Aquarium_CT_jeh.jpg", licenseURI: "https://creativecommons.org/licenses/by-sa/4.0/"),
        "waterfront": Attribution(name: "Daniel Case · CC BY-SA 3.0", uri: "https://commons.wikimedia.org/wiki/File:Signal_Hill_and_Ferris_wheel_from_Victoria_Wharf_balcony,_Cape_Town.jpg", licenseURI: "https://creativecommons.org/licenses/by-sa/3.0/"),
        "castle": Attribution(name: "Bernard Gagnon · CC BY-SA 4.0", uri: "https://commons.wikimedia.org/wiki/File:Castle_of_Good_Hope,_Cape_Town_01.jpg", licenseURI: "https://creativecommons.org/licenses/by-sa/4.0/")
    ]
}

struct RouteDiscovery: Identifiable, Sendable {
    let place: PlaceReference
    let interests: [TravelInterest]
    let reason: String
    let visitMinutes: Int
    let label: String
    let sourceURL: String
    var id: String { place.id }
}

// Small, real discoveries have their own collection; destinations keep their landmark collection.
// Visit lengths and ratings are prototype suggestions, not live venue facts.
enum RouteDiscoveries {
    static let places: [RouteDiscovery] = [
        gem("blue-cafe", "The Blue Café", "13 Brownlow Road · Tamboerskloof", -33.9277577, 18.4051054, .food, [.culture, .food, .history], "A neighbourhood café since 1904, with local produce and a little Cape Town history.", 30, "Hidden gem", "https://thebluecafe.co.za/"),
        gem("book-lounge", "The Book Lounge", "71 Roeland Street · Gardens", -33.92906, 18.42156, .scenic, [.arts, .culture, .shopping], "Find local authors and new reads in an independent bookshop, with a cosy space to browse.", 25, "Hidden gem", "https://booklounge.co.za/contact-us/"),
        gem("a4", "A4 Arts Foundation", "23 Buitenkant Street · District Six", -33.927468, 18.424139, .scenic, [.arts, .culture], "A free public art library and exhibitions in an independent District Six arts space.", 35, "Hidden gem", "https://www.a4arts.org/about/faq"),
        gem("honest", "Honest Chocolate Café", "64A Wale Street · City centre", -33.922538, 18.4171398, .food, [.food], "Duck into a tucked-away courtyard for bean-to-bar chocolate, hot chocolate and handmade treats.", 25, "Hidden gem", "https://honestchocolate.co.za/honest-chocolate-cafe/"),
        gem("rosetta", "Rosetta Roastery", "97 Bree Street · City centre", -33.9212615, 18.4183377, .coffee, [.food], "Try a single-origin brew at a specialist coffee bar, with pastries for a smaller stop.", 20, "Local favourite", "https://www.rosettaroastery.com/pages/locations"),
        gem("clarkes", "Clarke’s", "133 Bree Street · City centre", -33.922426, 18.41713, .food, [.food], "A neighbourhood diner for burgers and all-day breakfasts on Bree Street.", 45, "Local favourite", "https://www.clarkesdining.co.za/clarkes"),
        gem("de-waal", "De Waal Park", "Upper Orange Street · Gardens", -33.9369493, 18.4123371, .scenic, [.nature, .wildlife, .sports], "Take a short stroll among mature trees and garden birds, or stretch your legs on the park paths.", 25, "Quieter discovery", "https://www.capetown.gov.za/Family%20and%20home/See-all-city-facilities/Our-recreational-facilities/District%20parks/De%20Waal%20Park"),
        gem("company-garden", "Company’s Garden", "Queen Victoria Street · Gardens", -33.9272153, 18.4173344, .scenic, [.nature, .wildlife, .history], "Pause by the fish pond and garden birds for a little nature within the historic city.", 20, "Local favourite", "https://www.capetown.travel/attractions/the-companys-garden/"),
        gem("green-point", "Green Point Park", "Green Point Park · Cape Town", -33.904122, 18.401107, .scenic, [.nature, .wildlife, .sports], "Explore indigenous plants and the wetland garden, with easy paths for a gentle outdoor break.", 30, "Quieter discovery", "https://www.capetown.gov.za/family%20and%20home/see-all-city-facilities/our-recreational-facilities/biodiversity%20parks")
    ]

    private static func gem(_ id: String, _ name: String, _ subtitle: String, _ lat: Double, _ lon: Double, _ category: StopCategory, _ interests: [TravelInterest], _ reason: String, _ minutes: Int, _ label: String, _ source: String) -> RouteDiscovery {
        RouteDiscovery(place: PlaceReference(id: "demo-gem-\(id)", name: name, subtitle: subtitle,
                        coordinate: .init(latitude: lat, longitude: lon), category: category,
                        photoName: "asset:gem-\(id)", photoAttributions: credits[id].map { [$0] } ?? []),
                       interests: interests, reason: reason, visitMinutes: minutes, label: label, sourceURL: source)
    }

    static func details(_ id: String) -> RouteDiscovery? { places.first { $0.id == id } }
    static func isMajorAttraction(_ id: String) -> Bool { DestinationCatalog.places.contains { $0.id == id } }
    static func label(for id: String) -> String? {
        if let discovery = details(id) { return discovery.label }
        if isMajorAttraction(id) { return "Landmark stop" }
        if ["demo-drostdy", "demo-map-africa", "demo-goukamma"].contains(id) { return "Quieter discovery" }
        if ["demo-peregrine", "demo-tredici", "demo-houw-hoek"].contains(id) { return "Local favourite" }
        return nil
    }
    static func visitMinutes(for id: String) -> Int {
        if let discovery = details(id) { return discovery.visitMinutes }
        switch id {
        case "demo-destination-table-mountain": return 90
        case "demo-destination-lions-head", "demo-cape-point": return 120
        case "demo-destination-zeitz", "demo-destination-aquarium", "demo-destination-boulders", "demo-destination-kirstenbosch": return 60
        case "demo-destination-castle", "demo-market", "demo-destination-waterfront": return 45
        case "demo-drostdy", "demo-goukamma": return 35
        case "demo-tredici": return 40
        default: return 20
        }
    }
    static func recommendationReason(for place: PlaceReference, interests: [TravelInterest]) -> String? {
        let descriptions = [
            "demo-peregrine": "A farm-stall coffee and pie break near Grabouw, with local flavours along the N2.",
            "demo-tredici": "Leave time for a bakery meal in Swellendam, a smaller food discovery along the journey.",
            "demo-houw-hoek": "Pick up a pie and a coffee at a local farm stall before continuing along the N2.",
            "demo-dolphin": "Pull over for a short coastal view over Wilderness, without committing to a full hike."
        ]
        let description = details(place.id)?.reason ?? DestinationCatalog.summary(for: place.id) ?? descriptions[place.id]
        guard let description else { return nil }
        let matching = interests.first { DestinationCatalog.interests(for: place).contains($0) }
        let prefix = matching.map { "For your \($0.title.lowercased()) interest: " } ?? "A discovery along your journey: "
        return prefix + description
    }

    static func photoCredits(for key: String) -> [Attribution] { credits[key].map { [$0] } ?? [] }

    private static let credits: [String: Attribution] = [
        "drostdy": Attribution(name: "Josep M. Gracia · CC BY-SA 4.0", uri: "https://commons.wikimedia.org/wiki/File:SWE_-_Drostdy_Museum_in_Swellendam,_South_Africa,_2017.jpg", licenseURI: "https://creativecommons.org/licenses/by-sa/4.0"),
        "map-africa": Attribution(name: "Mart Bouter · CC BY-SA 3.0", uri: "https://commons.wikimedia.org/wiki/File:RSA_Wilderness_MapOfAfrica.JPG", licenseURI: "https://creativecommons.org/licenses/by-sa/3.0"),
        "dolphin": Attribution(name: "Axel Bührmann from Here, South Africa · CC BY 4.0", uri: "https://commons.wikimedia.org/wiki/File:Panorama_-_Dolphin_Point_Overlooking_Wilderness_-_Featured_on_Flickr_Explore._-_Flickr_-_Axel_B%C3%BChrmann.jpg", licenseURI: "https://creativecommons.org/licenses/by/4.0"),
        "goukamma": Attribution(name: "Scott Ramsay · CapeNature · official venue photo", uri: "https://www.capenature.co.za/reserves/goukamma-nature-reserve"),
        "book-lounge": Attribution(name: "Nick-D · CC BY-SA 4.0", uri: "https://commons.wikimedia.org/wiki/File:Basement_of_The_Book_Lounge_June_2026.jpg", licenseURI: "https://creativecommons.org/licenses/by-sa/4.0/"),
        "de-waal": Attribution(name: "Magemu · CC BY-SA 4.0", uri: "https://commons.wikimedia.org/wiki/File:De_Waal_Park_Bench.jpg", licenseURI: "https://creativecommons.org/licenses/by-sa/4.0/"),
        "green-point": Attribution(name: "warrenski · CC BY-SA 2.0", uri: "https://commons.wikimedia.org/wiki/File:Green_Point_Urban_Park.jpg", licenseURI: "https://creativecommons.org/licenses/by-sa/2.0/"),
        "company-garden": Attribution(name: "LKD2018 · CC BY-SA 4.0", uri: "https://commons.wikimedia.org/wiki/File:Company%27s_Garden_Cape_Town.jpg", licenseURI: "https://creativecommons.org/licenses/by-sa/4.0/"),
        "rosetta": Attribution(name: "Rosetta Roastery · official venue photo", uri: "https://www.rosettaroastery.com/pages/locations"),
        "honest": Attribution(name: "Honest Chocolate · official venue photo", uri: "https://honestchocolate.co.za/honest-chocolate-cafe/"),
        "a4": Attribution(name: "A4 Arts Foundation · official venue photo", uri: "https://www.a4arts.org/about"),
        "blue-cafe": Attribution(name: "The Blue Café · photo via CapeTownMagazine", uri: "https://www.capetownmagazine.com/blue-cafe"),
        "clarkes": Attribution(name: "Clarke’s · official venue photo", uri: "https://www.clarkesdining.co.za/clarkes")
    ]
}
