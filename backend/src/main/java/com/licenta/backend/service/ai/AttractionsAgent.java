package com.licenta.backend.service.ai;

import com.licenta.backend.entity.PreferenceTag;
import com.licenta.backend.entity.ScheduleType;
import com.licenta.backend.entity.Trip;
import org.springframework.stereotype.Service;

import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;
import java.util.Locale;
import java.util.Set;
import java.util.concurrent.ConcurrentHashMap;
import java.text.Normalizer;

@Service
public class AttractionsAgent {


    private static final long FINAL_CACHE_TTL_MILLIS = 30 * 60 * 1000; // 30 minute

    private final GeoapifyAttractionsClient geoapifyAttractionsClient;
    private final WikimediaEnrichmentClient wikimediaEnrichmentClient;


    private final ConcurrentHashMap<String, FinalCacheEntry> finalPoisCache = new ConcurrentHashMap<>();

    public AttractionsAgent(
            GeoapifyAttractionsClient geoapifyAttractionsClient,
            WikimediaEnrichmentClient wikimediaEnrichmentClient
    ) {
        this.geoapifyAttractionsClient = geoapifyAttractionsClient;
        this.wikimediaEnrichmentClient = wikimediaEnrichmentClient;
    }

    public List<Poi> getPoisForTrip(Trip trip) {
        Set<PreferenceTag> preferences =
                trip.getPreferences() == null ? Set.of() : trip.getPreferences();

        System.out.println("=== ATTRACTIONS AGENT ===");
        System.out.println("Trip city: " + trip.getCity());
        System.out.println("Trip accommodation: " + trip.getAccommodationLat() + ", " + trip.getAccommodationLng());
        System.out.println("Preferences: " + preferences);


        String cacheKey = buildFinalCacheKey(trip);
        FinalCacheEntry cached = finalPoisCache.get(cacheKey);

        if (cached != null) {
            if (!cached.isExpired()) {
                System.out.println("AttractionsAgent final cache HIT");
                System.out.println("Cached final POIs count: " + cached.pois().size());
                return cached.pois();
            }


            finalPoisCache.remove(cacheKey);
        }

        List<Poi> result;

        List<Poi> externalPois = fetchExternalPois(trip);
        System.out.println("External POIs count: " + externalPois.size());

        if (!externalPois.isEmpty()) {
            List<Poi> localSeedPois = buildLocalSeedPoisIfAvailable(trip);

            if (!localSeedPois.isEmpty()) {
                System.out.println("Using EXTERNAL POIs + LOCAL SEED POIs");
                List<Poi> combinedPois = new ArrayList<>(externalPois);
                combinedPois.addAll(localSeedPois);
                result = scoreAndSelectPois(trip, deduplicatePois(combinedPois), preferences);
            } else {
                System.out.println("Using EXTERNAL POIs");
                result = scoreAndSelectPois(trip, externalPois, preferences);
            }
        } else {
            System.out.println("Using FALLBACK LOCAL POIs");

            List<Poi> localPois = buildLocalSeedPoisIfAvailable(trip);

            if (localPois.isEmpty()) {
                localPois = buildFallbackPois(trip);
            }

            result = scoreAndSelectPois(trip, localPois, preferences);
        }


        if (!result.isEmpty()) {
            finalPoisCache.put(
                    cacheKey,
                    new FinalCacheEntry(
                            List.copyOf(result),
                            System.currentTimeMillis() + FINAL_CACHE_TTL_MILLIS
                    )
            );
            System.out.println("AttractionsAgent final cache PUT");
        }

        return result;
    }

    private List<Poi> fetchExternalPois(Trip trip) {
        if (!geoapifyAttractionsClient.isEnabled()) {
            return List.of();
        }

        if (trip.getCity() == null || trip.getCity().isBlank()) {
            return List.of();
        }

        List<Poi> pois = geoapifyAttractionsClient.fetchCityPois(trip.getCity());
        return deduplicatePois(pois);
    }

    private List<Poi> scoreAndSelectPois(Trip trip, List<Poi> pois, Set<PreferenceTag> preferences) {
        if (pois == null || pois.isEmpty()) {
            return List.of();
        }

        List<PoiScore> preliminary = new ArrayList<>();

        for (Poi poi : pois) {
            if (poi == null || poi.title() == null || poi.title().isBlank()) {
                continue;
            }

            if (trip.getCity() != null
                    && normalizeTitle(poi.title()).equals(normalizeTitle(trip.getCity()))) {
                continue;
            }

            if (isClearlyWrongEntity(poi, trip.getCity())) {
                continue;
            }

            int baseScore = calculateBaseScore(
                    poi,
                    preferences,
                    trip.getCity()
            );

            String bucket = detectPrimaryBucket(poi);

            preliminary.add(new PoiScore(
                    poi,
                    baseScore,
                    bucket
            ));
        }

        preliminary.sort(Comparator.comparingInt(PoiScore::score).reversed());


        int enrichCount = Math.min(12, preliminary.size());
        List<PoiScore> finalScored = new ArrayList<>();

        for (int i = 0; i < preliminary.size(); i++) {
            PoiScore item = preliminary.get(i);
            int finalScore = item.score();

            if (i < enrichCount) {
                int wikiBoost = wikimediaEnrichmentClient.getPopularityBoost(
                        item.poi().title(),
                        trip.getCity()
                );
                finalScore += wikiBoost;
            }

            System.out.println("POI: " + item.poi().title()
                    + " | score=" + finalScore
                    + " | bucket=" + item.bucket());

            finalScored.add(new PoiScore(
                    item.poi(),
                    finalScore,
                    item.bucket()
            ));
        }

        finalScored.sort(Comparator.comparingInt(PoiScore::score).reversed());

        return selectTopPois(finalScored, getDesiredPoiCount(trip), trip.getCity());
    }

    private int calculateBaseScore(
            Poi poi,
            Set<PreferenceTag> preferences,
            String city
    ) {
        int headlinerBoost = calculateHeadlinerBoost(poi, city);
        int attractionTypeScore = calculateAttractionTypeScore(poi);
        int majorLandmarkScore = calculateMajorLandmarkScore(poi);
        int preferenceScore = calculatePreferenceScore(poi, preferences);
        int nichePenalty = calculateNichePenalty(poi);
        int obscurePenalty = calculateObscurePenalty(poi);

        return headlinerBoost
                + attractionTypeScore
                + majorLandmarkScore
                + preferenceScore
                - nichePenalty
                - obscurePenalty;
    }


    private int calculateAttractionTypeScore(Poi poi) {
        String text = buildSearchText(poi);
        int score = 0;

        if (containsAny(text,
                "unesco", "world heritage",
                "royal palace", "state opera", "staatsoper", "opera house",
                "cathedral", "basilica", "duomo",
                "historic center", "historic centre", "old town",
                "national museum", "nationalmuseum", "nationales museum", "art museum",
                "botanical garden", "botanic garden", "botanical", "palmengarten", "ferris wheel",
                "observatory", "observator","temple", "odeon", "forum", "agora", "acropolis", "propylaea",
                "ναος", "ωδειο", "αγορα", "ακροπολη", "προπυλαια",
                "castelo", "observatorio", "reservatorio", "teatro romano",
                "cathedrale", "cattedrale", "catedral", "basilique", "basilica",
                "centre historique", "centro historico", "centro storico",
                "musee national", "museo nacional", "museo nazionale",
                "jardin botanique", "jardin botanico", "giardino botanico",
                "opera nacional", "opera nazionale",
                "anfiteatro", "anfiteatre", "amphitheatre",
                "sitio arqueologico", "site archeologique", "sito archeologico",

                "παρθενωνας", "παρθενώνας",
                "μουσειο ακροπολης", "μουσείο ακρόπολης",
                "αρχαιολογικο", "αρχαιολογικό",
                "αρχαιολογικος χωρος", "αρχαιολογικός χώρος",
                "ναος", "ναός",
                "πλατεια", "πλατεία",
                "καστρο", "κάστρο",

                "ayasofya",
                "sultanahmet",
                "topkapi", "topkapi sarayi", "topkapi sarayı",
                "dolmabahce", "dolmabahce sarayi", "dolmabahçe sarayı",
                "yerebatan", "yerebatan sarnici", "yerebatan sarnıcı",
                "saray", "sarayi", "sarayı",
                "cami", "camii",
                "kale", "kalesi",

                "hallgrimskirkja", "hallgrímskirkja",
                "harpa",
                "perlan",
                "þjóðminjasafn", "thjodminjasafn",
                "listasafn")) {
            score += 28;
        }

        if (containsAny(text,
                "castle", "fortress",
                "monument", "landmark",
                "main square", "central square", "plaza mayor",
                "music hall", "concert venue", "concert hall",
                "modernist", "modernisme", "gaudi",
                "bridge", "tower", "skyscraper",
                "palatul", "parlament", "parliament", "athenaeum", "ateneu",
                "palais royal", "palacio real", "palazzo reale",
                "pont", "puente", "torre", "tour", "plaza", "piazza", "place",
                "arco", "arc de triomphe", "triumphal arch",

                "πυργος", "πύργος",
                "γεφυρα", "γέφυρα",
                "ανακτορο", "ανάκτορο",

                "galata", "galata kulesi",
                "kule", "kulesi",
                "kopru", "köprü", "koprusu", "köprüsü",
                "meydan", "meydani", "meydanı",
                "kapali carsi", "kapalı çarşı",

                "solfar", "sólfar",
                "sun voyager")) {
            score += 20;
        }

        if (containsAny(text,
                "heimatmuseum", "local museum", "small museum",
                "sammlungsdepot", "visitor center", "visitors center",
                "museum depot", "technische sammlung", "kabinett")) {
            score += 4;
        } else if (containsAny(text,
                "museum", "gallery",
                "pinakothek", "glyptothek", "kunsthalle", "kunstmuseum", "sammlung",
                "musee", "museo", "museu", "galleria", "galeria", "galerie",

                "μουσειο", "μουσείο",

                "muze", "muzesi", "müzesi", "müze",

                "safn", "listasafn", "thjodminjasafn", "þjodminjasafn", "þjóðminjasafn",

                "muzeum", "múzeum", "muzeu", "muzeul",

                "arkeoloji muzesi", "arkeoloji müzesi",
                "sanat muzesi", "sanat müzesi",
                "ulusal muze", "ulusal müze",
                "εθνικο μουσειο", "εθνικό μουσείο",
                "αρχαιολογικο μουσειο", "αρχαιολογικό μουσείο")) {
            score += 14;
        }

        if (containsAny(text,
                "park", "garten", "garden", "gardens",
                "volkspark", "naturpark", "schlosspark",
                "arboretum", "botanischer garten", "botanischer volkspark",
                "viewpoint", "observation",
                "square", "plaza", "piazza","parque", "parc", "parco",
                "jardin", "jardim", "giardino",
                "mirador", "belvedere", "panorama")) {
            score += 7;
        }

        if (containsAny(text,
                "historic square", "market hall", "town square",
                "cathedral square", "river promenade", "castle hill")) {
            score += 8;
        }

        if (containsAny(text,
                "church", "kirkja", "monastery", "theatre", "theater",
                "market", "quartier", "quarter")) {
            score += 3;
        }

        if (containsAny(text, "palace")) {
            score += 5;
        }

        if (containsAny(text, "palais", "palacio", "palatul")) {
            score += 3;
        }

        if (poi.tags() != null) {
            if (poi.tags().contains(PreferenceTag.MUSEUMS)) score += 5;
            if (poi.tags().contains(PreferenceTag.HISTORY)) score += 4;
            if (poi.tags().contains(PreferenceTag.ARCHITECTURE)) score += 4;
            if (poi.tags().contains(PreferenceTag.MUSIC)) score += 3;
            if (poi.tags().contains(PreferenceTag.NATURE)) score += 3;
            if (poi.tags().contains(PreferenceTag.SHOPPING)) score += 2;
        }

        return score;
    }



    private int calculateMajorLandmarkScore(Poi poi) {
        String text = buildSearchText(poi);

        int score = 0;

        if (containsAny(text,
                "parliament", "parlament",
                "royal palace", "palatul regal", "palacio real",
                "palace of justice", "palatul de justitie",
                "national theatre", "teatrul national",
                "national opera", "opera nationala", "state opera", "staatsoper", "opera house",
                "athenaeum", "ateneul", "ateneu",
                "astronomical observatory", "observatory", "observator",
                "military circle", "cercul militar",
                "city museum", "history museum", "historical museum",
                "botanical garden", "botanic garden", "gradina botanica", "gr dina botanic",
                "palmengarten",
                "national art museum", "muzeul national de arta",
                "national museum of art",
                "national museum of natural history",
                "national history museum",
                "palatul parlamentului","temple", "odeon", "forum", "agora", "acropolis", "propylaea",
                "ναος", "ωδειο", "αγορα", "ακροπολη", "προπυλαια",
                "castelo", "observatorio", "reservatorio", "teatro romano",
                "palais royal", "palazzo reale",
                "theatre national", "teatro nacional", "teatro nazionale",
                "musee national", "museo nacional", "museo nazionale",
                "jardin botanique", "jardim botanico", "giardino botanico",
                "assemblee nationale", "parlamento", "parlamento nazionale",
                "observatoire", "osservatorio",

                "παρθενωνας", "παρθενώνας",
                "μουσειο ακροπολης", "μουσείο ακρόπολης",
                "εθνικο αρχαιολογικο μουσειο", "εθνικό αρχαιολογικό μουσείο",
                "συνταγμα", "σύνταγμα",
                "καλλιμαρμαρο", "καλλιμάρμαρο",

                "ayasofya",
                "sultanahmet camii",
                "topkapi sarayi", "topkapi sarayı",
                "dolmabahce sarayi", "dolmabahçe sarayı",
                "galata kulesi",
                "yerebatan sarnici", "yerebatan sarnıcı",
                "kapali carsi", "kapalı çarşı",

                "hallgrimskirkja", "hallgrímskirkja",
                "harpa",
                "perlan",
                "solfar", "sólfar",
                "þjóðminjasafn", "thjodminjasafn")) {
            score += 24;
        }

        if (containsAny(text,
                "palatul", "palace",
                "opera",
                "observator", "observatory",
                "athenaeum", "ateneu",
                "justice", "justitie",
                "parliament", "parlament",
                "royal",
                "national museum", "muzeul national",
                "castelo", "observatorio", "reservatorio",
                "palazzo", "palacio",
                "teatro", "theatre",
                "musee", "museo", "museu",
                "parlement", "parlamento", "real", "reale",
                "saray", "sarayi", "sarayı",
                "cami", "camii",
                "kule", "kulesi",
                "kale", "kalesi",
                "meydan", "meydani", "meydanı",
                "μουσειο", "μουσείο",
                "ναος", "ναός",
                "πλατεια", "πλατεία",
                "καστρο", "κάστρο",
                "safn", "listasafn", "kirkja")) {
            score += 10;
        }

        return score;
    }


    private int calculateHeadlinerBoost(Poi poi, String city) {
        String text = buildSearchText(poi);
        String normalizedCity = city == null ? "" : normalizeTitle(city);

        List<String> headliners = new ArrayList<>();

        if (normalizedCity.contains("vienna")) {
            headliners = List.of(
                    "schonbrunn", "schloss schonbrunn",
                    "stephansdom", "st stephen", "st stephen cathedral", "st stephen s cathedral", "stephansplatz",
                    "hofburg",
                    "belvedere", "belvedere palace", "schloss belvedere", "oberes belvedere", "unteres belvedere",
                    "prater", "riesenrad",
                    "albertina",
                    "kunsthistorisches museum", "kunsthistorisches",
                    "naturhistorisches museum", "naturhistorisches",
                    "state opera", "vienna state opera", "wiener staatsoper",
                    "musikverein",
                    "secession",
                    "mozarthaus",
                    "burgtheater",
                    "leopold museum",
                    "haus der musik",
                    "prunksaal",
                    "austrian national library", "osterreichische nationalbibliothek",
                    "technisches museum",
                    "museum hundertwasser", "hundertwasser"
            );
        } else if (normalizedCity.contains("madrid")) {
            headliners = List.of(
                    "palacio real", "palacio real de madrid",
                    "prado", "museo del prado",
                    "retiro", "parque del retiro",
                    "plaza mayor", "puerta del sol",
                    "reina sofia",
                    "thyssen",
                    "templo de debod",
                    "mercado de san miguel",
                    "almudena"
            );
        } else if (normalizedCity.contains("barcelona")) {
            headliners = List.of(
                    "sagrada familia",
                    "park guell", "parc guell",
                    "casa batllo",
                    "la pedrera", "casa mila",
                    "palau de la musica",
                    "barcelona cathedral", "catedral de la santa creu", "catedral",
                    "montjuic", "castell de montjuic",
                    "boqueria",
                    "palau guell",
                    "liceu"
            );
        } else if (normalizedCity.contains("prague")) {
            headliners = List.of(
                    "prazsky hrad", "prague castle",
                    "charles bridge", "karluv most",
                    "old town square", "staromestske namesti",
                    "astronomical clock", "orloj",
                    "katedrala svateho vita", "st vitus",
                    "tyn", "matka bozi pred tynem",
                    "petrinska rozhledna"
            );
        } else if (normalizedCity.contains("reykjavik")) {
            headliners = List.of(
                    "hallgrimskirkja", "hallgrímskirkja",
                    "perlan",
                    "solfar", "sólfar", "sun voyager",
                    "harpa",
                    "thjodminjasafn islands", "þjóðminjasafn íslands", "national museum of iceland",
                    "listasafn reykjavikur", "reykjavik art museum",
                    "safnahusid", "safnahúsið",
                    "tjornin", "tjörnin",
                    "thingvellir", "þingvellir"
            );
        } else if (normalizedCity.contains("new york")) {
            headliners = List.of(
                    "central park",
                    "times square",
                    "statue of liberty",
                    "empire state building",
                    "metropolitan museum of art", "the met",
                    "museum of modern art", "moma",
                    "brooklyn bridge",
                    "rockefeller center",
                    "grand central", "grand central terminal",
                    "st patrick s cathedral",
                    "broadway",
                    "one world observatory",
                    "high line",
                    "radio city music hall",
                    "lincoln center",
                    "american museum of natural history"
            );
        } else if (normalizedCity.contains("frankfurt")) {
            headliners = List.of(
                    "palmengarten",
                    "kaiserdom", "kaiserdom st bartholomaus", "st bartholomaus",
                    "stadel museum", "stadel",
                    "historisches museum",
                    "paulskirche",
                    "romerberg", "romer",
                    "goethe haus", "goethehaus",
                    "senckenberg",
                    "alte oper"
            );
        } else if (normalizedCity.contains("athens")) {
            headliners = List.of(
                    "acropolis", "ακροπολη", "ακρόπολη",
                    "parthenon", "παρθενωνας", "παρθενώνας",
                    "acropolis museum", "μουσειο ακροπολης", "μουσείο ακρόπολης",
                    "propylaea", "προπυλαια", "προπύλαια",
                    "odeon of herodes atticus", "ηρωδου αττικου", "ηρώδου αττικού",
                    "temple of athena nike", "ναος αθηνας νικης", "ναός αθηνάς νίκης",
                    "ancient agora", "αρχαια αγορα", "αρχαία αγορά",
                    "roman agora", "ρωμαικη αγορα", "ρωμαϊκή αγορά",
                    "temple of olympian zeus", "ναος ολυμπιου διος", "ναός ολυμπίου διός",
                    "syntagma", "συνταγμα", "σύνταγμα",
                    "panathenaic stadium", "καλλιμαρμαρο", "καλλιμάρμαρο",
                    "national archaeological museum", "εθνικο αρχαιολογικο μουσειο", "εθνικό αρχαιολογικό μουσείο",
                    "philopappos monument", "μνημειο φιλοπαππου", "μνημείο φιλοπάππου",
                    "βουλη των ελληνων", "βουλή των ελλήνων"
            );
        } else if (normalizedCity.contains("lisbon")) {
            headliners = List.of(
                    "castelo de sao jorge",
                    "se de lisboa",
                    "museu nacional de arte antiga",
                    "torre de belem",
                    "basilica da estrela",
                    "teatro nacional de sao carlos",
                    "observatorio astronomico de lisboa",
                    "museu de lisboa teatro romano",
                    "reservatorio da mae d agua das amoreiras",
                    "reservatorio da patriarcal"
            );
        } else if (normalizedCity.contains("istanbul")) {
            headliners = List.of(
                    "hagia sophia", "ayasofya",
                    "blue mosque", "sultanahmet camii",
                    "topkapi", "topkapi palace", "topkapi sarayi", "topkapi sarayı",
                    "galata tower", "galata kulesi",
                    "grand bazaar", "kapali carsi", "kapalı çarşı",
                    "basilica cistern", "yerebatan sarnici", "yerebatan sarnıcı",
                    "dolmabahce", "dolmabahce palace", "dolmabahce sarayi", "dolmabahçe sarayı",
                    "suleymaniye", "suleymaniye camii", "süleymaniye camii",
                    "maiden s tower", "kiz kulesi", "kız kulesi",
                    "istanbul archaeological museums", "istanbul arkeoloji muzeleri", "istanbul arkeoloji müzeleri"
            );
        }

        for (String token : headliners) {
            if (text.contains(token)) {
                return 35;
            }
        }

        return 0;
    }



    private int calculatePreferenceScore(Poi poi, Set<PreferenceTag> preferences) {
        if (preferences == null || preferences.isEmpty() || poi.tags() == null || poi.tags().isEmpty()) {
            return 0;
        }

        int score = 0;

        for (PreferenceTag pref : preferences) {
            if (poi.tags().contains(pref)) {
                score += 6;
            }
        }

        return score;
    }




    private int calculateNichePenalty(Poi poi) {
        String text = buildSearchText(poi);
        int penalty = 0;

        if (containsAny(text,
                "theatre", "theater", "teatro",
                "concert hall", "exhibition centre", "exposition center", "exposicions")
                && !containsAny(text,
                "national theatre", "national opera", "opera nationala", "state opera", "staatsoper",
                "athenaeum", "ateneu")) {
            penalty += 3;
        }

        if (containsAny(text,
                "market", "mercat", "local market")) {
            penalty += 2;
        }

        if (containsAny(text,
                "church", "kirkja", "monastery", "klosterkirche", "place_of_worship")
                && !containsAny(text,
                "cathedral", "basilica", "duomo",
                "kaiserdom", "st bartholomaus", "stephansdom")) {
            penalty += 4;
        }

        if (containsAny(text, "palais", "palacio", "palace")
                && !containsAny(text,
                "royal palace", "palacio real",
                "palatul regal", "palace of justice", "palatul de justitie",
                "palatul parlamentului")) {
            penalty += 2;
        }

        if (containsAny(text, "cafe", "café")) {
            penalty += 12;
        }

        if (containsAny(text, "kapelle", "kabinett")) {
            penalty += 4;
        }

        if (containsAny(text, "kloster", "turm")
                && !containsAny(text,
                "kaiserdom", "cathedral", "basilica", "observatory",
                "foisorul de foc", "observator", "observatory")) {
            penalty += 2;
        }

        if (containsAny(text,
                "heimatmuseum", "local museum", "small museum",
                "sammlungsdepot", "visitor center", "visitors center",
                "museum depot", "technische sammlung")) {
            penalty += 6;
        }


        if (containsAny(text,
                "chiesa", "iglesia", "eglise", "church", "kirche")
                && !containsAny(text,
                "cathedral", "catedral", "cathedrale", "cattedrale",
                "basilica",
                "notre dame", "san pietro", "st peter",
                "stephansdom", "se de lisboa", "sagrada familia")) {
            penalty += 5;
        }

        return penalty;
    }



    private int calculateObscurePenalty(Poi poi) {
        String text = buildSearchText(poi);
        int penalty = 0;

        if (containsAny(text,
                "statue of liberty",
                "liberty island")) {
            return penalty;
        }

        if (containsAny(text,
                "hotel", "hostel", "apartment", "apartments",
                "office", "administrative")) {
            penalty += 40;
        }

        if (containsAny(text,
                "archeological",
                "archaeological",
                "historical",
                "cultural",
                "viewpoint")
                && poi.title() != null
                && normalizeTitle(poi.title()).split(" ").length <= 2) {
            penalty += 18;
        }

        if (containsAny(text,
                "small museum", "private museum", "local museum",
                "bezirksmuseum",
                "district museum",
                "town museum",
                "firehouse museum",
                "fire museum",
                "police museum",
                "railway museum",
                "transportation museum",
                "telecommunications museum",
                "zoology museum",
                "museum of zoology",
                "folklore museum",
                "folk museum",
                "local history society",
                "historical society",
                "visitor center",
                "visitors center",

                "λαογραφικο", "λαογραφικό",
                "πυροσβεστικο", "πυροσβεστικό",
                "τηλεπικοινωνιων", "τηλεπικοινωνιών",
                "σιδηροδρομικο", "σιδηροδρομικό",
                "ζωολογιας", "ζωολογίας",
                "δημου", "δήμου")) {
            penalty += 14;
        }

        if (containsAny(text,
                "plaque",
                "bust",
                "skulptur",
                "sculpture",
                "memorial",
                "gedenk",
                "monument to",
                "artist unknown")) {
            penalty += 12;
        }

        if (looksLikeRandomPersonName(poi.title())) {
            penalty += 14;
        }

        if (text.matches(".*\\b\\d{3,}\\b.*")) {
            penalty += 5;
        }

        return penalty;
    }



    private boolean looksLikeMajorAttraction(Poi poi, String city) {
        if (poi == null) {
            return false;
        }

        String text = buildSearchText(poi);

        if (calculateHeadlinerBoost(poi, city) > 0) {
            return true;
        }

        if (calculateMajorLandmarkScore(poi) >= 20) {
            return true;
        }

        if (containsAny(text,
                "unesco", "world heritage",
                "royal palace", "palacio real",
                "state opera", "staatsoper", "opera house",
                "cathedral", "basilica", "duomo",
                "national museum", "nationalmuseum", "nationales museum", "art museum",
                "old town", "historic center", "historic centre",
                "main square", "central square", "plaza mayor",
                "castle", "fortress",
                "bridge", "tower",
                "observatory", "observator", "ferris wheel",
                "museum of art", "museum of modern art",
                "pinakothek", "glyptothek", "kunsthalle", "kunstmuseum",
                "botanischer garten", "botanical garden", "botanic garden",
                "parliament", "parlament",
                "athenaeum", "ateneu",
                "palace of justice", "palatul de justitie",
                "national opera", "opera nationala",
                "palatul regal", "palatul parlamentului",
                "central park", "times square",
                "statue of liberty", "empire state building",
                "rockefeller center", "grand central",
                "anne frank", "rijksmuseum", "van gogh",
                "hallgrimskirkja", "perlan", "sun voyager", "solfar",
                "sydney opera house",
                "secession",
                "temple", "odeon", "forum", "agora", "acropolis", "propylaea",
                "archaeological site",
                "ναος", "ωδειο", "αγορα", "ακροπολη", "προπυλαια",
                "castelo", "observatorio", "reservatorio", "teatro romano",
                "se de lisboa", "musee", "museo", "museu",
                "cathedrale", "cattedrale", "catedral",
                "basilique",
                "palacio", "palazzo",
                "pont", "puente",
                "tour", "torre",
                "amphitheatre", "anfiteatro", "anfiteatre",
                "site archeologique", "sitio arqueologico", "sito archeologico",
                "monastere", "monasterio", "monastero", "piazza",

                "μουσειο", "μουσείο",
                "ναος", "ναός",
                "ακροπολη", "ακρόπολη",
                "παρθενωνας", "παρθενώνας",
                "αγορα", "αγορά",
                "πλατεια", "πλατεία",
                "καστρο", "κάστρο",
                "αρχαιολογικο", "αρχαιολογικό",

                "muze", "müze", "muzesi", "müzesi",
                "cami", "camii",
                "saray", "sarayi", "sarayı",
                "kale", "kalesi",
                "kule", "kulesi",
                "kopru", "köprü",
                "meydan", "meydani", "meydanı",
                "ayasofya",
                "sultanahmet",
                "topkapi",
                "galata",
                "yerebatan",

                "safn", "listasafn",
                "kirkja",
                "hallgrimskirkja", "hallgrímskirkja",
                "harpa",
                "perlan",
                "solfar", "sólfar")) {
            return true;
        }

        String bucket = detectPrimaryBucket(poi);

        if (("landmark".equals(bucket) || "religious".equals(bucket))
                && containsAny(text,
                "cathedral", "basilica", "castle", "fortress", "bridge", "tower",
                "palace", "square", "parliament", "parlament", "justice", "palatul",
                "temple", "odeon", "forum", "agora", "acropolis", "propylaea",
                "ναος", "ωδειο", "αγορα", "ακροπολη", "προπυλαια",
                "castelo", "observatorio", "reservatorio")) {
            return true;
        }

        if ("museum".equals(bucket) && containsAny(text,
                "national museum", "nationalmuseum", "nationales museum",
                "art museum", "museum of art", "museum of modern art",
                "pinakothek", "glyptothek", "kunsthalle", "kunstmuseum",
                "musee national", "museo nacional", "museo nazionale",
                "musee d art", "museo de arte", "museo d arte",
                "musee d art moderne", "museo de arte moderno", "museo d arte moderna",
                "μουσειο ακροπολης", "μουσείο ακρόπολης",
                "εθνικο μουσειο", "εθνικό μουσείο",
                "αρχαιολογικο μουσειο", "αρχαιολογικό μουσείο",
                "arkeoloji muzesi", "arkeoloji müzesi",
                "sanat muzesi", "sanat müzesi",
                "ulusal muze", "ulusal müze",
                "þjóðminjasafn", "thjodminjasafn",
                "listasafn")) {
            return true;
        }

        if ("culture".equals(bucket) && containsAny(text,
                "opera", "theatre", "theater", "odeon", "ωδειο",
                "burgtheater", "ronacher", "teatro", "teatro romano")) {
            return true;
        }

        if ("nature".equals(bucket) && containsAny(text,
                "botanical garden", "botanic garden", "gradina botanica",
                "palmengarten", "arboretum", "garten",
                "jardin botanique", "jardim botanico", "giardino botanico",
                "real jardin botanico",
                "retiro", "central park", "prater", "tiergarten")) {
            return true;
        }

        return false;
    }



    private boolean isClearlyWrongEntity(Poi poi, String city) {
        if (calculateHeadlinerBoost(poi, city) > 0) {
            return false;
        }

        String titleText = normalizeTitle(poi.title());
        String addressText = normalizeTitle(poi.locationAddress());
        String fullText = normalizeTitle(titleText + " " + addressText);

        String[] hardRejectInTitle = {
                "hotel", "hostel", "apartment", "apartments",
                "embassy", "consulate",
                "pharmacy", "apotheke", "supermarket", "grocery",
                "bank",
                "junta de freguesia", "freguesia",
                "municipality", "city council",
                "administration", "government",
                "embajada", "ambassade", "ambasciata",
                "farmacia", "pharmacie",
                "banco", "banque", "banca",
                "ayuntamiento", "mairie", "municipio",
                "ministerio", "ministere", "ministero"
        };

        for (String term : hardRejectInTitle) {
            if (titleText.contains(term)) {
                System.out.println("Rejected wrong entity by TITLE: " + poi.title()
                        + " | term=" + term
                        + " | title=" + titleText);
                return true;
            }
        }

        String[] titleOrAddressButOnlyIfTitleIsWeak = {
                "university", "universitat", "egyetem",
                "institute", "institut", "intezet",
                "academy", "akademie",
                "municipality", "city council", "onkormanyzat",
                "administration", "office building", "administrative",
                "government", "embassy", "consulate", "freguesia",
                "universidad", "universite", "universita",
                "instituto", "institut", "istituto",
                "academia", "academie", "accademia",
                "municipio", "mairie",
                "ministerio", "ministere", "ministero"
        };

        boolean titleLooksAttraction = containsAny(titleText,
                "museum", "opera", "theatre", "theater", "theatro", "teatro",
                "cathedral", "basilica", "church", "kirkja",
                "palace", "palatul", "castle", "fortress",
                "bridge", "tower", "garden", "park",
                "observatory", "observator",
                "parliament", "parlament",
                "monument", "memorial",
                "temple", "odeon", "forum", "agora", "acropolis", "propylaea",
                "ναος", "ωδειο", "αγορα", "ακροπολη", "προπυλαια",
                "castelo", "basilica", "observatorio", "reservatorio",
                "teatro romano", "burgtheater", "ronacher", "secession",
                "se de lisboa","musee", "museo", "museu",
                "cathedrale", "catedral", "cattedrale",
                "eglise", "iglesia", "chiesa",
                "monastere", "monasterio", "monastero",
                "parque", "parc", "parco",
                "jardin", "jardim", "giardino",
                "palazzo", "palacio",
                "pont", "puente",
                "tour", "torre",
                "anfiteatro", "anfiteatre", "amphitheatre",

                "μουσειο", "μουσείο",
                "ναος", "ναός",
                "εκκλησια", "εκκλησία",
                "ακροπολη", "ακρόπολη",
                "αγορα", "αγορά",
                "πλατεια", "πλατεία",
                "καστρο", "κάστρο",

                "muze", "müze", "muzesi", "müzesi",
                "cami", "camii",
                "saray", "sarayi", "sarayı",
                "kale", "kalesi",
                "kule", "kulesi",
                "kopru", "köprü",
                "meydan", "meydani", "meydanı",

                "safn", "listasafn",
                "kirkja",
                "hallgrimskirkja", "hallgrímskirkja",
                "harpa",
                "perlan",

                "πυργος", "πύργος",
                "γεφυρα", "γέφυρα",
                "παρκο", "πάρκο",
                "βοτανικο", "βοτανικό",
                "αρχαιολογικη", "αρχαιολογική",
                "αρχαιολογικος", "αρχαιολογικός",
                "πλανηταριο", "πλανητάριο",
                "πινακοθηκη", "πινακοθήκη");

        for (String term : titleOrAddressButOnlyIfTitleIsWeak) {
            if (fullText.contains(term) && !titleLooksAttraction) {
                System.out.println("Rejected wrong entity by WEAK TITLE + bad term: " + poi.title()
                        + " | term=" + term
                        + " | fullText=" + fullText);
                return true;
            }
        }

        return false;
    }



    private String detectPrimaryBucket(Poi poi) {
        Set<PreferenceTag> tags = poi.tags() == null ? Set.of() : poi.tags();
        String text = buildSearchText(poi);


        if (containsAny(text,
                "cathedral", "basilica", "duomo",
                "church", "kirkja",
                "synagogue", "mosque",
                "se de lisboa", "cathedrale", "cattedrale",
                "catedral", "basilique",
                "eglise", "iglesia", "chiesa",
                "monastere", "monasterio", "monastero",

                "ναος", "ναός",
                "εκκλησια", "εκκλησία",
                "μητροπολη", "μητρόπολη",

                "cami", "camii",
                "ayasofya",
                "kilise", "kilisesi",

                "mosquee", "mezquita")) {
            return "religious";
        }

        if (containsAny(text,
                "temple of", "ancient temple",
                "temple", "ναος",
                "acropolis", "ακροπολη",
                "propylaea", "προπυλαια",
                "agora", "forum", "αγορα",
                "archaeological site", "αρχαιολογικος χωρος",
                "castelo", "observatorio", "reservatorio",
                "palace", "palacio", "palais", "palatul",
                "castle", "fortress",
                "monument", "gate",
                "tower", "square", "plaza", "piazza",
                "belvedere", "bridge",
                "observatory", "observator",
                "parliament", "parlament", "justice",
                "secession", "palazzo",
                "torre", "tour", "puente", "pont", "arco",
                "site archeologique", "sitio arqueologico", "sito archeologico",
                "anfiteatro", "anfiteatre",

                "παρθενωνας", "παρθενώνας",
                "πυργος", "πύργος",
                "γεφυρα", "γέφυρα",
                "πλατεια", "πλατεία",
                "καστρο", "κάστρο",
                "ανακτορο", "ανάκτορο",

                "saray", "sarayi", "sarayı",
                "kale", "kalesi",
                "kule", "kulesi",
                "kopru", "köprü", "koprusu", "köprüsü",
                "meydan", "meydani", "meydanı",
                "galata", "topkapi", "ayasofya", "yerebatan")) {
            return "landmark";
        }

        if (containsAny(text,
                "opera", "staatsoper",
                "theatre", "theater", "theatro", "teatro",
                "concert", "philharm",
                "music hall", "recital hall",
                "athenaeum", "ateneu", "odeon", "ωδειο",
                "burgtheater", "ronacher",
                "teatro romano", "teatre", "teatro",
                "opera nacional", "opera nazionale",
                "filarmonica", "philharmonie", "philarmonie",

                "harpa",
                "ωδειο", "ωδείο",
                "odeio",
                "konser", "konser salonu",
                "kultur merkezi", "kültür merkezi")) {
            return "culture";
        }


        if (containsAny(text,
                "park", "garten", "garden", "gardens",
                "volkspark", "naturpark", "schlosspark",
                "arboretum", "botanischer garten", "botanischer volkspark",
                "gradina botanica", "botanical garden", "botanic garden",
                "zoo", "parque", "parc", "parco",
                "jardin", "jardim", "giardino",
                "mirador")) {
            return "nature";
        }

        if (containsAny(text,
                "museum", "gallery",
                "pinakothek", "glyptothek",
                "kunsthalle", "kunstmuseum",
                "sammlung", "musee", "museo", "museu",
                "galerie", "galeria", "galleria",

                "μουσειο", "μουσείο",

                "muze", "müze", "muzesi", "müzesi",

                "safn", "listasafn", "thjodminjasafn", "þjodminjasafn", "þjóðminjasafn",

                "muzeum", "múzeum", "muzeu", "muzeul")) {
            return "museum";
        }

        if (tags.contains(PreferenceTag.MUSEUMS)) return "museum";
        if (tags.contains(PreferenceTag.NATURE)) return "nature";
        if (tags.contains(PreferenceTag.SHOPPING) || text.contains("market") || text.contains("shopping")) return "shopping";

        return "general";
    }





    private List<Poi> selectTopPois(List<PoiScore> scored, int desiredCount, String city) {
        List<Poi> result = new ArrayList<>();
        java.util.Map<String, Integer> bucketCounts = new java.util.HashMap<>();

        int maxPerBucket = Math.max(4, desiredCount / 2);
        int strictMinimumScore = 18;
        int relaxedMinimumScore = 10;

        int museumCap = Math.max(5, desiredCount / 3);
        int religiousCap = Math.max(3, desiredCount / 3);


        for (PoiScore candidate : scored) {
            if (result.size() >= desiredCount) {
                break;
            }

            if (candidate.score() < strictMinimumScore) {
                continue;
            }

            if (!looksLikeMajorAttraction(candidate.poi(), city)) {
                continue;
            }

            if (containsVerySimilarTitle(result, candidate.poi().title())) {
                continue;
            }

            String bucket = candidate.bucket();
            int currentBucketCount = bucketCounts.getOrDefault(bucket, 0);

            if ("museum".equals(bucket) && currentBucketCount >= museumCap) {
                continue;
            }

            if ("religious".equals(bucket) && currentBucketCount >= religiousCap) {
                continue;
            }

            if (currentBucketCount >= maxPerBucket && result.size() >= desiredCount / 2) {
                continue;
            }

            result.add(candidate.poi());
            bucketCounts.put(bucket, currentBucketCount + 1);
        }


        for (PoiScore candidate : scored) {
            if (result.size() >= desiredCount) {
                break;
            }

            if (candidate.score() < relaxedMinimumScore) {
                continue;
            }

            if (containsVerySimilarTitle(result, candidate.poi().title())) {
                continue;
            }

            String bucket = candidate.bucket();
            int currentBucketCount = bucketCounts.getOrDefault(bucket, 0);

            if ("museum".equals(bucket) && currentBucketCount >= museumCap) {
                continue;
            }

            result.add(candidate.poi());
            bucketCounts.put(bucket, currentBucketCount + 1);
        }


        for (PoiScore candidate : scored) {
            if (result.size() >= desiredCount) {
                break;
            }

            if (candidate.score() < 0) {
                continue;
            }

            if (containsVerySimilarTitle(result, candidate.poi().title())) {
                continue;
            }

            result.add(candidate.poi());
        }

        System.out.println("Selected final POIs count: " + result.size()
                + " / desired=" + desiredCount);

        return result;
    }

    private boolean containsVerySimilarTitle(List<Poi> pois, String title) {
        String normalized = normalizeTitle(title);

        for (Poi poi : pois) {
            String existing = normalizeTitle(poi.title());

            if (existing.equals(normalized)) {
                return true;
            }

            if (!normalized.isBlank() && !existing.isBlank()) {
                if (existing.contains(normalized) || normalized.contains(existing)) {
                    return true;
                }
            }
        }

        return false;
    }

    private String buildFinalCacheKey(Trip trip) {
        String city = normalizeTitle(trip.getCity());
        String pace = trip.getTravelPace() == null ? "" : trip.getTravelPace().name();

        int tripDays = 1;
        if (trip.getStartDate() != null && trip.getEndDate() != null
                && !trip.getEndDate().isBefore(trip.getStartDate())) {
            tripDays = (int) (trip.getEndDate().toEpochDay() - trip.getStartDate().toEpochDay()) + 1;
        }

        List<String> prefs = trip.getPreferences() == null
                ? List.of()
                : trip.getPreferences().stream()
                .map(Enum::name)
                .sorted()
                .toList();

        return city + "|" + pace + "|" + tripDays + "|" + String.join(",", prefs);
    }

    private String normalizeTitle(String value) {
        if (value == null) {
            return "";
        }

        String normalized = Normalizer.normalize(value, Normalizer.Form.NFD)
                .replaceAll("\\p{M}+", "");

        return normalized.toLowerCase(Locale.ROOT)
                .replace("ß", "ss")
                .replace("þ", "th")
                .replace("ð", "d")
                .replaceAll("[^\\p{L}\\p{N} ]", " ")
                .replaceAll("\\s+", " ")
                .trim();
    }

    private boolean looksLikeRandomPersonName(String title) {
        if (title == null || title.isBlank()) {
            return false;
        }

        String normalized = normalizeTitle(title);
        String[] parts = normalized.split(" ");

        if (parts.length < 2 || parts.length > 4) {
            return false;
        }

        boolean allWordsSimple = true;
        for (String part : parts) {
            if (part.length() < 3 || !part.matches("\\p{L}+")) {
                allWordsSimple = false;
                break;
            }
        }

        boolean hasTouristSignal = containsAny(normalized,
                "museum", "palace", "castle", "cathedral", "church", "opera",
                "gallery", "park", "garden", "square", "market", "bridge", "tower");

        return allWordsSimple && !hasTouristSignal;
    }

    private String buildSearchText(Poi poi) {
        String title = poi.title() == null ? "" : poi.title();
        String address = poi.locationAddress() == null ? "" : poi.locationAddress();

        String tagsText = "";
        if (poi.tags() != null && !poi.tags().isEmpty()) {
            tagsText = poi.tags().toString();
        }

        return normalizeTitle(title + " " + address + " " + tagsText);
    }

    private boolean containsAny(String text, String... terms) {
        if (text == null || text.isBlank()) {
            return false;
        }

        String normalizedText = normalizeTitle(text);

        for (String term : terms) {
            if (term == null || term.isBlank()) {
                continue;
            }

            String normalizedTerm = normalizeTitle(term);

            if (!normalizedTerm.isBlank() && normalizedText.contains(normalizedTerm)) {
                return true;
            }
        }

        return false;
    }

    private int getDesiredPoiCount(Trip trip) {
        int tripDays = 1;

        if (trip.getStartDate() != null && trip.getEndDate() != null && !trip.getEndDate().isBefore(trip.getStartDate())) {
            tripDays = (int) (trip.getEndDate().toEpochDay() - trip.getStartDate().toEpochDay()) + 1;
        }

        int perDay = switch (trip.getTravelPace()) {
            case RELAXED -> 2;
            case BALANCED -> 3;
            case PACKED -> 4;
            default -> 3;
        };

        int desired = tripDays * perDay;

        if (desired < 8) return 8;
        if (desired > 18) return 18;

        return desired;
    }

    private List<Poi> deduplicatePois(List<Poi> pois) {
        List<Poi> result = new ArrayList<>();

        for (Poi candidate : pois) {
            boolean exists = result.stream().anyMatch(existing ->
                    normalizeTitle(existing.title()).equals(normalizeTitle(candidate.title()))
            );

            if (!exists) {
                result.add(candidate);
            }
        }

        return result;
    }

    private List<Poi> buildLocalSeedPoisIfAvailable(Trip trip) {
        String city = trip.getCity() == null
                ? ""
                : normalizeTitle(trip.getCity());

        if (city.contains("rome")) {
            return buildRomePois();
        } else if (city.contains("paris")) {
            return buildParisPois();
        } else if (city.contains("berlin")) {
            return buildBerlinPois();
        } else if (city.contains("vienna")) {
            return buildViennaPois();
        } else if (city.contains("new york")) {
            return buildNewYorkPois();
        } else if (city.contains("prague")) {
            return buildPraguePois();
        } else if (city.contains("barcelona")) {
            return buildBarcelonaPois();
        } else if (city.contains("madrid")) {
            return buildMadridPois();
        }

        return List.of();
    }


    private List<Poi> buildViennaPois() {
        return List.of(
                new Poi("Schönbrunn Palace", 48.184516, 16.312224, "Schönbrunner Schloßstraße 47, Vienna, Austria",
                        ScheduleType.ATTRACTION, Set.of(PreferenceTag.HISTORY, PreferenceTag.ARCHITECTURE)),
                new Poi("St. Stephen's Cathedral", 48.208174, 16.373819, "Stephansplatz 3, Vienna, Austria",
                        ScheduleType.ATTRACTION, Set.of(PreferenceTag.HISTORY, PreferenceTag.ARCHITECTURE)),
                new Poi("Hofburg Palace", 48.206544, 16.366514, "Michaelerkuppel, Vienna, Austria",
                        ScheduleType.ATTRACTION, Set.of(PreferenceTag.HISTORY, PreferenceTag.ARCHITECTURE)),
                new Poi("Belvedere Palace", 48.191307, 16.380215, "Prinz Eugen-Straße 27, Vienna, Austria",
                        ScheduleType.ATTRACTION, Set.of(PreferenceTag.HISTORY, PreferenceTag.ARCHITECTURE, PreferenceTag.MUSEUMS)),
                new Poi("Prater", 48.216500, 16.395700, "Prater, Vienna, Austria",
                        ScheduleType.ATTRACTION, Set.of(PreferenceTag.KIDS_FRIENDLY, PreferenceTag.NATURE)),
                new Poi("Albertina Museum", 48.204525, 16.368789, "Albertinaplatz 1, Vienna, Austria",
                        ScheduleType.ATTRACTION, Set.of(PreferenceTag.MUSEUMS, PreferenceTag.HISTORY)),
                new Poi("Vienna State Opera", 48.202556, 16.369722, "Opernring 2, Vienna, Austria",
                        ScheduleType.ATTRACTION, Set.of(PreferenceTag.MUSIC, PreferenceTag.ARCHITECTURE)),
                new Poi("Kunsthistorisches Museum", 48.203000, 16.361600, "Maria-Theresien-Platz, Vienna, Austria",
                        ScheduleType.ATTRACTION, Set.of(PreferenceTag.MUSEUMS, PreferenceTag.HISTORY)),
                new Poi("MuseumsQuartier", 48.203000, 16.359600, "Museumsplatz 1, Vienna, Austria",
                        ScheduleType.ATTRACTION, Set.of(PreferenceTag.MUSEUMS, PreferenceTag.MUSIC)),
                new Poi("Mozarthaus Vienna", 48.208390, 16.376819, "Domgasse 5, Vienna, Austria",
                        ScheduleType.ATTRACTION, Set.of(PreferenceTag.MUSIC, PreferenceTag.HISTORY))
        );
    }


    private List<Poi> buildNewYorkPois() {
        return List.of(
                new Poi("Central Park", 40.782865, -73.965355, "Central Park, New York, USA",
                        ScheduleType.ATTRACTION, Set.of(PreferenceTag.NATURE, PreferenceTag.KIDS_FRIENDLY)),
                new Poi("Times Square", 40.758000, -73.985500, "Times Square, Manhattan, New York, USA",
                        ScheduleType.ATTRACTION, Set.of(PreferenceTag.NIGHTLIFE, PreferenceTag.SHOPPING)),
                new Poi("Empire State Building", 40.748817, -73.985428, "20 W 34th St, New York, USA",
                        ScheduleType.ATTRACTION, Set.of(PreferenceTag.ARCHITECTURE, PreferenceTag.HISTORY)),
                new Poi("Brooklyn Bridge", 40.706086, -73.996864, "Brooklyn Bridge, New York, USA",
                        ScheduleType.ATTRACTION, Set.of(PreferenceTag.ARCHITECTURE, PreferenceTag.HISTORY)),
                new Poi("Statue of Liberty", 40.689249, -74.044500, "Liberty Island, New York, USA",
                        ScheduleType.ATTRACTION, Set.of(PreferenceTag.HISTORY, PreferenceTag.ARCHITECTURE)),
                new Poi("Rockefeller Center", 40.758740, -73.978674, "45 Rockefeller Plaza, New York, USA",
                        ScheduleType.ATTRACTION, Set.of(PreferenceTag.ARCHITECTURE, PreferenceTag.SHOPPING)),
                new Poi("Grand Central Terminal", 40.752726, -73.977229, "89 E 42nd St, New York, USA",
                        ScheduleType.ATTRACTION, Set.of(PreferenceTag.ARCHITECTURE, PreferenceTag.HISTORY)),
                new Poi("The Metropolitan Museum of Art", 40.779437, -73.963244, "1000 5th Ave, New York, USA",
                        ScheduleType.ATTRACTION, Set.of(PreferenceTag.MUSEUMS, PreferenceTag.HISTORY)),
                new Poi("Museum of Modern Art", 40.761433, -73.977622, "11 W 53rd St, New York, USA",
                        ScheduleType.ATTRACTION, Set.of(PreferenceTag.MUSEUMS)),
                new Poi("High Line", 40.7480, -74.0048, "High Line, New York, USA",
                        ScheduleType.ATTRACTION, Set.of(PreferenceTag.NATURE, PreferenceTag.ARCHITECTURE))
        );
    }

    private List<Poi> buildPraguePois() {
        return List.of(
                new Poi("Prague Castle", 50.090903, 14.400512, "Prague Castle, Prague, Czech Republic",
                        ScheduleType.ATTRACTION, Set.of(PreferenceTag.HISTORY, PreferenceTag.ARCHITECTURE)),
                new Poi("Charles Bridge", 50.086500, 14.411400, "Charles Bridge, Prague, Czech Republic",
                        ScheduleType.ATTRACTION, Set.of(PreferenceTag.HISTORY, PreferenceTag.ARCHITECTURE)),
                new Poi("Old Town Square", 50.087000, 14.420800, "Old Town Square, Prague, Czech Republic",
                        ScheduleType.ATTRACTION, Set.of(PreferenceTag.HISTORY, PreferenceTag.ARCHITECTURE)),
                new Poi("Astronomical Clock", 50.0870, 14.4207, "Staroměstské náměstí 1, Prague, Czech Republic",
                        ScheduleType.ATTRACTION, Set.of(PreferenceTag.HISTORY, PreferenceTag.ARCHITECTURE)),
                new Poi("St. Vitus Cathedral", 50.090903, 14.400512, "III. nádvoří 48/2, Prague, Czech Republic",
                        ScheduleType.ATTRACTION, Set.of(PreferenceTag.HISTORY, PreferenceTag.ARCHITECTURE)),
                new Poi("Petrin Tower", 50.0835, 14.3950, "Petřínské sady, Prague, Czech Republic",
                        ScheduleType.ATTRACTION, Set.of(PreferenceTag.ARCHITECTURE, PreferenceTag.NATURE))
        );
    }

    private List<Poi> buildBarcelonaPois() {
        return List.of(
                new Poi("Sagrada Família", 41.403629, 2.174356, "Carrer de Mallorca, 401, Barcelona, Spain",
                        ScheduleType.ATTRACTION, Set.of(PreferenceTag.ARCHITECTURE, PreferenceTag.HISTORY)),
                new Poi("Park Güell", 41.414494, 2.152694, "08024 Barcelona, Spain",
                        ScheduleType.ATTRACTION, Set.of(PreferenceTag.ARCHITECTURE, PreferenceTag.NATURE)),
                new Poi("Casa Batlló", 41.391650, 2.164918, "Passeig de Gràcia, 43, Barcelona, Spain",
                        ScheduleType.ATTRACTION, Set.of(PreferenceTag.ARCHITECTURE)),
                new Poi("La Pedrera", 41.395390, 2.161961, "Passeig de Gràcia, 92, Barcelona, Spain",
                        ScheduleType.ATTRACTION, Set.of(PreferenceTag.ARCHITECTURE)),
                new Poi("Barcelona Cathedral", 41.383962, 2.176199, "Pla de la Seu, Barcelona, Spain",
                        ScheduleType.ATTRACTION, Set.of(PreferenceTag.ARCHITECTURE, PreferenceTag.HISTORY)),
                new Poi("Palau de la Música Catalana", 41.387610, 2.175191, "Carrer Palau de la Música, 4-6, Barcelona, Spain",
                        ScheduleType.ATTRACTION, Set.of(PreferenceTag.MUSIC, PreferenceTag.ARCHITECTURE))
        );
    }

    private List<Poi> buildMadridPois() {
        return List.of(
                new Poi("Royal Palace of Madrid", 40.417955, -3.714312, "Calle de Bailén, Madrid, Spain",
                        ScheduleType.ATTRACTION, Set.of(PreferenceTag.HISTORY, PreferenceTag.ARCHITECTURE)),
                new Poi("Prado Museum", 40.413782, -3.692127, "Calle de Ruiz de Alarcón 23, Madrid, Spain",
                        ScheduleType.ATTRACTION, Set.of(PreferenceTag.MUSEUMS, PreferenceTag.HISTORY)),
                new Poi("Retiro Park", 40.415260, -3.684418, "Retiro, Madrid, Spain",
                        ScheduleType.ATTRACTION, Set.of(PreferenceTag.NATURE)),
                new Poi("Plaza Mayor", 40.415511, -3.707399, "Plaza Mayor, Madrid, Spain",
                        ScheduleType.ATTRACTION, Set.of(PreferenceTag.HISTORY, PreferenceTag.ARCHITECTURE)),
                new Poi("Puerta del Sol", 40.416900, -3.703500, "Puerta del Sol, Madrid, Spain",
                        ScheduleType.ATTRACTION, Set.of(PreferenceTag.HISTORY)),
                new Poi("Reina Sofía Museum", 40.408735, -3.694204, "Calle de Santa Isabel, 52, Madrid, Spain",
                        ScheduleType.ATTRACTION, Set.of(PreferenceTag.MUSEUMS))
        );
    }

    private List<Poi> buildRomePois() {
        return List.of(
                new Poi("Colosseum", 41.8902, 12.4922, "Piazza del Colosseo, 1, Rome, Italy",
                        ScheduleType.ATTRACTION, Set.of(PreferenceTag.HISTORY, PreferenceTag.ARCHITECTURE)),
                new Poi("Roman Forum", 41.8925, 12.4853, "Via della Salara Vecchia, Rome, Italy",
                        ScheduleType.ATTRACTION, Set.of(PreferenceTag.HISTORY, PreferenceTag.ARCHITECTURE)),
                new Poi("Trevi Fountain", 41.9009, 12.4833, "Piazza di Trevi, Rome, Italy",
                        ScheduleType.ATTRACTION, Set.of(PreferenceTag.ARCHITECTURE, PreferenceTag.HISTORY)),
                new Poi("Pantheon", 41.8986, 12.4768, "Piazza della Rotonda, Rome, Italy",
                        ScheduleType.ATTRACTION, Set.of(PreferenceTag.HISTORY, PreferenceTag.ARCHITECTURE)),
                new Poi("Piazza Navona", 41.8992, 12.4731, "Piazza Navona, Rome, Italy",
                        ScheduleType.ATTRACTION, Set.of(PreferenceTag.ARCHITECTURE, PreferenceTag.HISTORY)),
                new Poi("Vatican Museums", 41.9065, 12.4536, "Viale Vaticano, Rome, Italy",
                        ScheduleType.ATTRACTION, Set.of(PreferenceTag.MUSEUMS, PreferenceTag.HISTORY, PreferenceTag.ARCHITECTURE)),
                new Poi("St. Peter's Basilica", 41.9022, 12.4539, "Piazza San Pietro, Vatican City",
                        ScheduleType.ATTRACTION, Set.of(PreferenceTag.ARCHITECTURE, PreferenceTag.HISTORY)),
                new Poi("Spanish Steps", 41.9059, 12.4823, "Piazza di Spagna, Rome, Italy",
                        ScheduleType.ATTRACTION, Set.of(PreferenceTag.ARCHITECTURE)),
                new Poi("Castel Sant'Angelo", 41.9031, 12.4663, "Lungotevere Castello, 50, Rome, Italy",
                        ScheduleType.ATTRACTION, Set.of(PreferenceTag.HISTORY, PreferenceTag.ARCHITECTURE)),
                new Poi("Trastevere Walk", 41.8897, 12.4708, "Trastevere, Rome, Italy",
                        ScheduleType.ATTRACTION, Set.of(PreferenceTag.FOOD, PreferenceTag.NIGHTLIFE, PreferenceTag.HISTORY))
        );
    }

    private List<Poi> buildParisPois() {
        return List.of(
                new Poi("Eiffel Tower", 48.8584, 2.2945, "Champ de Mars, 5 Avenue Anatole France, Paris, France",
                        ScheduleType.ATTRACTION, Set.of(PreferenceTag.ARCHITECTURE, PreferenceTag.HISTORY)),
                new Poi("Louvre Museum", 48.8606, 2.3376, "Rue de Rivoli, Paris, France",
                        ScheduleType.ATTRACTION, Set.of(PreferenceTag.MUSEUMS, PreferenceTag.HISTORY, PreferenceTag.ARCHITECTURE)),
                new Poi("Notre-Dame Cathedral", 48.8530, 2.3499, "6 Parvis Notre-Dame, Paris, France",
                        ScheduleType.ATTRACTION, Set.of(PreferenceTag.HISTORY, PreferenceTag.ARCHITECTURE)),
                new Poi("Montmartre", 48.8867, 2.3431, "Montmartre, Paris, France",
                        ScheduleType.ATTRACTION, Set.of(PreferenceTag.ARCHITECTURE, PreferenceTag.HISTORY, PreferenceTag.MUSIC)),
                new Poi("Arc de Triomphe", 48.8738, 2.2950, "Place Charles de Gaulle, Paris, France",
                        ScheduleType.ATTRACTION, Set.of(PreferenceTag.HISTORY, PreferenceTag.ARCHITECTURE)),
                new Poi("Musée d'Orsay", 48.8600, 2.3266, "1 Rue de la Légion d'Honneur, Paris, France",
                        ScheduleType.ATTRACTION, Set.of(PreferenceTag.MUSEUMS, PreferenceTag.HISTORY)),
                new Poi("Luxembourg Gardens", 48.8462, 2.3372, "Rue de Médicis - Rue de Vaugirard, Paris, France",
                        ScheduleType.ATTRACTION, Set.of(PreferenceTag.NATURE, PreferenceTag.KIDS_FRIENDLY)),
                new Poi("Sainte-Chapelle", 48.8554, 2.3450, "10 Boulevard du Palais, Paris, France",
                        ScheduleType.ATTRACTION, Set.of(PreferenceTag.HISTORY, PreferenceTag.ARCHITECTURE))
        );
    }

    private List<Poi> buildBerlinPois() {
        return List.of(
                new Poi("Alexanderplatz", 52.5219, 13.4132, "Alexanderplatz, 10178 Berlin, Germany",
                        ScheduleType.ATTRACTION, Set.of(PreferenceTag.ARCHITECTURE, PreferenceTag.SHOPPING)),
                new Poi("Berlin Cathedral", 52.5192, 13.4010, "Am Lustgarten, 10178 Berlin, Germany",
                        ScheduleType.ATTRACTION, Set.of(PreferenceTag.ARCHITECTURE, PreferenceTag.HISTORY)),
                new Poi("Museum Island", 52.5169, 13.4010, "Bodestraße 1-3, 10178 Berlin, Germany",
                        ScheduleType.ATTRACTION, Set.of(PreferenceTag.MUSEUMS, PreferenceTag.HISTORY, PreferenceTag.ARCHITECTURE)),
                new Poi("Checkpoint Charlie", 52.5076, 13.3904, "Friedrichstraße 43-45, 10117 Berlin, Germany",
                        ScheduleType.ATTRACTION, Set.of(PreferenceTag.HISTORY)),
                new Poi("Brandenburg Gate", 52.5163, 13.3777, "Pariser Platz, 10117 Berlin, Germany",
                        ScheduleType.ATTRACTION, Set.of(PreferenceTag.HISTORY, PreferenceTag.ARCHITECTURE)),
                new Poi("Reichstag Building", 52.5186, 13.3762, "Platz der Republik 1, 11011 Berlin, Germany",
                        ScheduleType.ATTRACTION, Set.of(PreferenceTag.HISTORY, PreferenceTag.ARCHITECTURE)),
                new Poi("East Side Gallery", 52.5050, 13.4399, "Mühlenstraße, 10243 Berlin, Germany",
                        ScheduleType.ATTRACTION, Set.of(PreferenceTag.HISTORY, PreferenceTag.MUSIC)),
                new Poi("Tiergarten", 52.5145, 13.3501, "Tiergarten, Berlin, Germany",
                        ScheduleType.ATTRACTION, Set.of(PreferenceTag.NATURE, PreferenceTag.KIDS_FRIENDLY)),
                new Poi("Berlin Zoo", 52.5080, 13.3372, "Hardenbergplatz 8, 10787 Berlin, Germany",
                        ScheduleType.ATTRACTION, Set.of(PreferenceTag.KIDS_FRIENDLY, PreferenceTag.NATURE)),
                new Poi("Kurfürstendamm", 52.5038, 13.3305, "Kurfürstendamm, Berlin, Germany",
                        ScheduleType.ATTRACTION, Set.of(PreferenceTag.SHOPPING, PreferenceTag.NIGHTLIFE))
        );
    }

    private List<Poi> buildFallbackPois(Trip trip) {
        Double baseLat = trip.getAccommodationLat();
        Double baseLng = trip.getAccommodationLng();

        if (baseLat != null && baseLng != null) {
            return List.of(
                    new Poi("Main Historic Landmark", baseLat + 0.010, baseLng + 0.008, "Central landmark nearby",
                            ScheduleType.ATTRACTION, Set.of(PreferenceTag.ARCHITECTURE, PreferenceTag.HISTORY)),
                    new Poi("City Museum", baseLat + 0.018, baseLng - 0.006, "Popular city museum",
                            ScheduleType.ATTRACTION, Set.of(PreferenceTag.MUSEUMS, PreferenceTag.HISTORY)),
                    new Poi("Old Town", baseLat - 0.007, baseLng + 0.014, "Historic old town area",
                            ScheduleType.ATTRACTION, Set.of(PreferenceTag.HISTORY, PreferenceTag.ARCHITECTURE)),
                    new Poi("Central Park", baseLat + 0.005, baseLng - 0.016, "Main park area",
                            ScheduleType.ATTRACTION, Set.of(PreferenceTag.NATURE)),
                    new Poi("Scenic Viewpoint", baseLat - 0.015, baseLng - 0.010, "Popular city viewpoint",
                            ScheduleType.ATTRACTION, Set.of(PreferenceTag.NATURE)),
                    new Poi("Cultural Quarter", baseLat + 0.012, baseLng + 0.017, "Cultural district",
                            ScheduleType.ATTRACTION, Set.of(PreferenceTag.MUSIC, PreferenceTag.HISTORY)),
                    new Poi("Local Market", baseLat - 0.004, baseLng + 0.006, "Main local market",
                            ScheduleType.ATTRACTION, Set.of(PreferenceTag.FOOD, PreferenceTag.SHOPPING)),
                    new Poi("Architectural Landmark", baseLat + 0.020, baseLng + 0.003, "Famous building nearby",
                            ScheduleType.ATTRACTION, Set.of(PreferenceTag.ARCHITECTURE))
            );
        }

        return List.of(
                new Poi("City Center", 47.4979, 19.0402, "City center",
                        ScheduleType.ATTRACTION, Set.of(PreferenceTag.HISTORY, PreferenceTag.ARCHITECTURE)),
                new Poi("Main Museum", 47.5005, 19.0470, "Main museum",
                        ScheduleType.ATTRACTION, Set.of(PreferenceTag.MUSEUMS, PreferenceTag.HISTORY)),
                new Poi("Best Viewpoint", 47.4930, 19.0350, "Best viewpoint",
                        ScheduleType.ATTRACTION, Set.of(PreferenceTag.NATURE))
        );
    }

    private record PoiScore(Poi poi, int score, String bucket) {}

    private record FinalCacheEntry(List<Poi> pois, long expiresAtMillis) {
        boolean isExpired() {
            return System.currentTimeMillis() > expiresAtMillis;
        }
    }
}