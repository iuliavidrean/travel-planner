package com.licenta.backend.service.ai;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.licenta.backend.entity.PreferenceTag;
import com.licenta.backend.entity.ScheduleType;
import org.springframework.stereotype.Service;

import java.net.URI;
import java.net.URLEncoder;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.nio.charset.StandardCharsets;
import java.time.Duration;
import java.util.ArrayList;
import java.util.List;
import java.util.Locale;
import java.util.Set;
import java.util.concurrent.ConcurrentHashMap;
import java.text.Normalizer;

@Service
public class GeoapifyAttractionsClient {

    private static final long CACHE_TTL_MILLIS = 30 * 60 * 1000; // 30 minute

    private final GeoapifyProperties properties;
    private final ObjectMapper objectMapper = new ObjectMapper();
    private final HttpClient httpClient = HttpClient.newBuilder()
            .connectTimeout(Duration.ofSeconds(12))
            .build();

    private final ConcurrentHashMap<String, CacheEntry> cityPoisCache = new ConcurrentHashMap<>();

    public GeoapifyAttractionsClient(GeoapifyProperties properties) {
        this.properties = properties;
    }

    public boolean isEnabled() {
        return properties.isEnabled()
                && properties.getApiKey() != null
                && !properties.getApiKey().isBlank();
    }

    public List<Poi> fetchCityPois(String city) {
        if (!isEnabled()) {
            return List.of();
        }

        if (city == null || city.isBlank()) {
            return List.of();
        }

        String normalizedCityKey = normalizeTitle(city);
        CacheEntry cached = cityPoisCache.get(normalizedCityKey);

        if (cached != null && !cached.isExpired()) {
            System.out.println("=== GEOAPIFY CLIENT ===");
            System.out.println("Cache HIT for city: " + city);
            System.out.println("Cached POIs: " + cached.pois().size());
            return cached.pois();
        }

        long totalStart = System.currentTimeMillis();

        try {
            System.out.println("=== GEOAPIFY CLIENT ===");
            System.out.println("Cache MISS for city: " + city);
            System.out.println("Enabled: " + isEnabled());
            System.out.println("City: " + city);
            System.out.println("Limit: " + properties.getLimit());

            long geocodeStart = System.currentTimeMillis();
            GeoapifyGeocodeResponse.Result cityResult = resolveCity(city);
            long geocodeEnd = System.currentTimeMillis();

            System.out.println("Geoapify geocode duration ms: " + (geocodeEnd - geocodeStart));

            if (cityResult == null || cityResult.bbox() == null) {
                System.out.println("Could not resolve city bbox.");
                return List.of();
            }

            GeoapifyGeocodeResponse.Bbox bbox = cityResult.bbox();
            List<Poi> all = new ArrayList<>();


            long strongCoreStart = System.currentTimeMillis();
            List<Poi> strongCorePois = fetchByCategories(bbox, List.of(
                    "tourism.sights",
                    "tourism.attraction",
                    "heritage"
            ));
            long strongCoreEnd = System.currentTimeMillis();
            System.out.println("Geoapify strong core ms: " + (strongCoreEnd - strongCoreStart));
            all.addAll(strongCorePois);



            if (all.size() < 80) {
                long museumsHistoricStart = System.currentTimeMillis();
                List<Poi> museumsHistoricPois = fetchByCategories(bbox, List.of(
                        "building.historic",
                        "entertainment.museum"
                ));
                long museumsHistoricEnd = System.currentTimeMillis();
                System.out.println("Geoapify museums/historic ms: " + (museumsHistoricEnd - museumsHistoricStart));
                all.addAll(museumsHistoricPois);
            }




            if (all.size() < 12) {
                long parksStart = System.currentTimeMillis();
                List<Poi> parkPois = fetchByCategories(bbox, List.of(
                        "leisure.park"
                ));
                long parksEnd = System.currentTimeMillis();
                System.out.println("Geoapify parks ms: " + (parksEnd - parksStart));
                all.addAll(parkPois);
            }



            if (all.size() < 12) {
                long broadStart = System.currentTimeMillis();
                List<Poi> broadPois = fetchByCategories(bbox, List.of(
                        "tourism",
                        "entertainment",
                        "leisure"
                ));
                long broadEnd = System.currentTimeMillis();
                System.out.println("Geoapify broad categories ms: " + (broadEnd - broadStart));
                all.addAll(broadPois);
            }



            boolean strongCoreFailed = strongCorePois.isEmpty();
            boolean museumsHistoricFailed = all.stream().noneMatch(p ->
                    p.tags() != null && (
                            p.tags().contains(PreferenceTag.MUSEUMS)
                                    || p.tags().contains(PreferenceTag.HISTORY)
                                    || p.tags().contains(PreferenceTag.ARCHITECTURE)
                    )
            );

            boolean mostlyNature = !all.isEmpty() && all.stream().allMatch(p ->
                    p.tags() != null
                            && p.tags().contains(PreferenceTag.NATURE)
                            && !p.tags().contains(PreferenceTag.MUSEUMS)
                            && !p.tags().contains(PreferenceTag.HISTORY)
                            && !p.tags().contains(PreferenceTag.ARCHITECTURE)
            );

            if (strongCoreFailed && museumsHistoricFailed && mostlyNature) {
                System.out.println("Geoapify result too narrow: mostly parks/nature only. Returning empty list so fallback/local scoring can take over.");
                return List.of();
            }

            List<Poi> deduped = deduplicatePois(all);
            long totalEnd = System.currentTimeMillis();

            System.out.println("Final deduplicated Geoapify POIs: " + deduped.size());
            System.out.println("Geoapify total fetchCityPois ms: " + (totalEnd - totalStart));

            if (deduped.size() >= 8) {
                cityPoisCache.put(normalizedCityKey, new CacheEntry(
                        List.copyOf(deduped),
                        System.currentTimeMillis() + CACHE_TTL_MILLIS
                ));
            } else {
                System.out.println("Skipping cache because deduplicated POIs list is too small.");
            }

            return deduped;

        } catch (Exception e) {
            e.printStackTrace();
            return List.of();
        }
    }

    private List<Poi> fetchByCategories(GeoapifyGeocodeResponse.Bbox bbox, List<String> categoriesList) {
        try {
            String categories = String.join(",", categoriesList);

            String filter = "rect:"
                    + bbox.lon1() + "," + bbox.lat1() + ","
                    + bbox.lon2() + "," + bbox.lat2();

            String url = properties.getBaseUrl()
                    + "/places?"
                    + "categories=" + encode(categories)
                    + "&filter=" + encode(filter)
                    + "&limit=" + properties.getLimit()
                    + "&lang=en"
                    + "&apiKey=" + encode(properties.getApiKey());

            System.out.println("Geoapify places URL: " + url);

            HttpRequest request = HttpRequest.newBuilder()
                    .uri(URI.create(url))
                    .timeout(Duration.ofSeconds(10))
                    .header("Accept", "application/json")
                    .header("User-Agent", "TravelPlannerLicenta/1.0")
                    .GET()
                    .build();

            HttpResponse<String> response = httpClient.send(
                    request,
                    HttpResponse.BodyHandlers.ofString()
            );

            System.out.println("Geoapify places status: " + response.statusCode());

            if (response.statusCode() != 200) {
                System.out.println("Geoapify places error body: " + response.body());
                return List.of();
            }

            GeoapifyPlaceResponse parsed =
                    objectMapper.readValue(response.body(), GeoapifyPlaceResponse.class);

            if (parsed == null || parsed.features() == null || parsed.features().isEmpty()) {
                System.out.println("Geoapify returned no city POIs.");
                return List.of();
            }

            List<Poi> result = new ArrayList<>();

            for (GeoapifyPlaceResponse.Feature feature : parsed.features()) {
                if (feature == null
                        || feature.properties() == null
                        || feature.geometry() == null
                        || feature.geometry().coordinates() == null
                        || feature.geometry().coordinates().size() < 2) {
                    continue;
                }

                if (!isRelevantTouristPlace(feature)) {
                    continue;
                }

                String name = safe(feature.properties().name());
                String address = safe(feature.properties().formatted());

                if (name.isBlank()) {
                    continue;
                }

                double poiLng = feature.geometry().coordinates().get(0);
                double poiLat = feature.geometry().coordinates().get(1);

                Set<PreferenceTag> tags = mapCategoriesToTags(feature.properties().categories());

                result.add(new Poi(
                        name,
                        poiLat,
                        poiLng,
                        address.isBlank() ? null : address,
                        ScheduleType.ATTRACTION,
                        tags
                ));
            }

            System.out.println("Mapped Geoapify POIs: " + result.size());
            return result;

        } catch (Exception e) {
            System.out.println("Geoapify places request failed for categories: " + categoriesList);
            System.out.println("Geoapify places request failed: "
                    + e.getClass().getSimpleName() + " - " + e.getMessage());
            return List.of();
        }
    }

    private GeoapifyGeocodeResponse.Result resolveCity(String city) {
        try {
            String url = "https://api.geoapify.com/v1/geocode/search"
                    + "?text=" + encode(city)
                    + "&type=city"
                    + "&format=json"
                    + "&lang=en"
                    + "&apiKey=" + encode(properties.getApiKey());

            System.out.println("Geoapify geocode URL: " + url);

            HttpRequest request = HttpRequest.newBuilder()
                    .uri(URI.create(url))
                    .timeout(Duration.ofSeconds(12))
                    .header("Accept", "application/json")
                    .header("User-Agent", "TravelPlannerLicenta/1.0")
                    .GET()
                    .build();

            HttpResponse<String> response = httpClient.send(
                    request,
                    HttpResponse.BodyHandlers.ofString()
            );

            System.out.println("Geoapify geocode status: " + response.statusCode());

            if (response.statusCode() != 200) {
                System.out.println("Geoapify geocode error body: " + response.body());
                return null;
            }

            GeoapifyGeocodeResponse parsed =
                    objectMapper.readValue(response.body(), GeoapifyGeocodeResponse.class);

            if (parsed == null || parsed.results() == null || parsed.results().isEmpty()) {
                return null;
            }

            GeoapifyGeocodeResponse.Result first = parsed.results().get(0);
            System.out.println("Resolved city result: " + first.formatted());
            return first;

        } catch (Exception e) {
            e.printStackTrace();
            return null;
        }
    }

    private boolean isRelevantTouristPlace(GeoapifyPlaceResponse.Feature feature) {
        if (feature == null || feature.properties() == null) {
            return false;
        }

        String name = safe(feature.properties().name());
        List<String> categories = feature.properties().categories();

        if (name.isBlank()) {
            return false;
        }

        if (categories == null || categories.isEmpty()) {
            return false;
        }

        String normalizedName = normalizeTitle(name);
        String joined = String.join(" ", categories).toLowerCase(Locale.ROOT);

        boolean strong =
                joined.contains("tourism.sights")
                        || joined.contains("tourism.attraction")
                        || joined.contains("museum")
                        || joined.contains("castle")
                        || joined.contains("fortress")
                        || joined.contains("monument")
                        || joined.contains("heritage")
                        || joined.contains("building.historic");

        boolean weak =
                joined.contains("theatre")
                        || joined.contains("opera")
                        || joined.contains("park")
                        || joined.equals("tourism")
                        || joined.contains("tourism.")
                        || joined.equals("entertainment")
                        || joined.contains("entertainment.")
                        || joined.equals("leisure")
                        || joined.contains("leisure.");

        if (!strong && !weak) {
            return false;
        }

        boolean badByName =
                normalizedName.contains("plaque")
                        || normalizedName.contains("memorial")
                        || normalizedName.contains("stolperstein")
                        || normalizedName.contains("hotel")
                        || normalizedName.contains("hostel")
                        || normalizedName.contains("city hall")
                        || normalizedName.contains("excursions")
                        || normalizedName.contains("travel agency")
                        || normalizedName.contains("airport")
                        || normalizedName.equals("hofer")
                        || normalizedName.contains("spar")
                        || normalizedName.contains("lidl")
                        || normalizedName.contains("aldi")
                        || normalizedName.contains("billa")
                        || normalizedName.contains("penny")
                        || normalizedName.equals("imperial")
                        || normalizedName.contains("restaurant")
                        || normalizedName.contains("restaurante")
                        || normalizedName.contains("ristorante")
                        || normalizedName.contains("cafe")
                        || normalizedName.contains("cafeteria")
                        || normalizedName.contains("bar")
                        || normalizedName.contains("boutique")
                        || normalizedName.contains("shop")
                        || normalizedName.contains("shopping center")
                        || normalizedName.contains("shopping centre")
                        || normalizedName.contains("mall");



        if (badByName) {
            return false;
        }

        if (joined.contains("tourism.sights.memorial")) {
            return false;
        }

        boolean looksTooObscure =
                normalizedName.startsWith("johann ")
                        || normalizedName.startsWith("wilhelm ")
                        || normalizedName.startsWith("helene ")
                        || normalizedName.startsWith("julius ")
                        || normalizedName.startsWith("edmund ")
                        || normalizedName.matches(".*\\b\\d+\\b.*");

        if (looksTooObscure) {
            return false;
        }

        if ((normalizedName.startsWith("parco ")
                || normalizedName.startsWith("parque ")
                || normalizedName.startsWith("parc "))
                && !normalizedName.contains("botanic")
                && !normalizedName.contains("botanical")
                && !normalizedName.contains("jardin botanique")
                && !normalizedName.contains("jardim botanico")
                && !normalizedName.contains("giardino botanico")
                && !normalizedName.contains("central park")
                && !normalizedName.contains("retiro")
                && !normalizedName.contains("prater")
                && !normalizedName.contains("tiergarten")) {
            return false;
        }


        if (normalizedName.contains("gallery")
                && !normalizedName.contains("museum")
                && !normalizedName.contains("art gallery of")
                && !normalizedName.contains("national")
                && !normalizedName.contains("contemporary art")
                && !normalizedName.contains("modern art")
                && !normalizedName.contains("state gallery")
                && !normalizedName.contains("museum of contemporary art")) {
            return false;
        }



        if (!strong) {
            boolean hasGoodSignalInName =
                    normalizedName.contains("cathedral")
                            || normalizedName.contains("basilica")
                            || normalizedName.contains("church")
                            || normalizedName.contains("kirkja")
                            || normalizedName.contains("synagogue")
                            || normalizedName.contains("mosque")
                            || normalizedName.contains("opera")
                            || normalizedName.contains("park")
                            || normalizedName.contains("parc")
                            || normalizedName.contains("garden")
                            || normalizedName.contains("castle")
                            || normalizedName.contains("palace")
                            || normalizedName.contains("museum")
                            || normalizedName.contains("gallery")
                            || normalizedName.contains("casa ")
                            || normalizedName.contains("palau")
                            || normalizedName.contains("guell")
                            || normalizedName.contains("familia")
                            || normalizedName.contains("liceu")
                            || normalizedName.contains("music")
                            || normalizedName.contains("bridge")
                            || normalizedName.contains("tower")
                            || normalizedName.contains("square")
                            || normalizedName.contains("plaza")
                            || normalizedName.contains("hall")
                            || normalizedName.contains("observatory")
                            || normalizedName.contains("statue")
                            || normalizedName.contains("center")
                            || normalizedName.contains("centre")
                            || normalizedName.contains("terminal")
                            || normalizedName.contains("garten")
                            || normalizedName.contains("volkspark")
                            || normalizedName.contains("naturpark")
                            || normalizedName.contains("schlosspark")
                            || normalizedName.contains("arboretum")
                            || normalizedName.contains("botanical")
                            || normalizedName.contains("botanic")
                            || normalizedName.contains("temple")
                            || normalizedName.contains("odeon")
                            || normalizedName.contains("forum")
                            || normalizedName.contains("agora")
                            || normalizedName.contains("acropolis")
                            || normalizedName.contains("propylaea")
                            || normalizedName.contains("ναος")
                            || normalizedName.contains("ωδειο")
                            || normalizedName.contains("αγορα")
                            || normalizedName.contains("ακροπολη")
                            || normalizedName.contains("προπυλαια")
                            || normalizedName.contains("castelo")
                            || normalizedName.contains("observatorio")
                            || normalizedName.contains("reservatorio")
                            || normalizedName.contains("teatro romano")
                            || normalizedName.startsWith("se de ")
                            || normalizedName.equals("se de lisboa")
                            || normalizedName.contains("musee")
                            || normalizedName.contains("museo")
                            || normalizedName.contains("museu")
                            || normalizedName.contains("cathedrale")
                            || normalizedName.contains("catedral")
                            || normalizedName.contains("cattedrale")
                            || normalizedName.contains("eglise")
                            || normalizedName.contains("iglesia")
                            || normalizedName.contains("chiesa")
                            || normalizedName.contains("monastere")
                            || normalizedName.contains("monasterio")
                            || normalizedName.contains("monastero")
                            || normalizedName.contains("parque")
                            || normalizedName.contains("parco")
                            || normalizedName.contains("jardin")
                            || normalizedName.contains("jardim")
                            || normalizedName.contains("giardino")
                            || normalizedName.contains("palazzo")
                            || normalizedName.contains("pont")
                            || normalizedName.contains("puente")
                            || normalizedName.contains("tour")
                            || normalizedName.contains("torre")
                            || normalizedName.contains("anfiteatro")
                            || normalizedName.contains("anfiteatre")
                            || normalizedName.contains("amphitheatre");

            if (!hasGoodSignalInName) {
                return false;
            }

            if ((normalizedName.contains("church") || normalizedName.contains("kirkja"))
                    && !normalizedName.contains("cathedral")
                    && !normalizedName.contains("basilica")
                    && !normalizedName.contains("st mary")
                    && !normalizedName.contains("st patrick")
                    && !normalizedName.contains("st paul")
                    && !normalizedName.contains("st peter")
                    && !normalizedName.contains("st james")
                    && !normalizedName.contains("old cathedral")) {
                return false;
            }
        }

        return true;
    }

    private Set<PreferenceTag> mapCategoriesToTags(List<String> categories) {
        if (categories == null || categories.isEmpty()) {
            return Set.of();
        }

        java.util.Set<PreferenceTag> tags = new java.util.HashSet<>();

        for (String category : categories) {
            String c = safe(category).toLowerCase(Locale.ROOT);

            if (c.contains("museum") || c.contains("gallery")) {
                tags.add(PreferenceTag.MUSEUMS);
            }

            if (c.contains("heritage")
                    || c.contains("historic")
                    || c.contains("monument")
                    || c.contains("castle")
                    || c.contains("fortress")) {
                tags.add(PreferenceTag.HISTORY);
            }

            if (c.contains("church")
                    || c.contains("cathedral")
                    || c.contains("tower")
                    || c.contains("architecture")
                    || c.contains("building.historic")
                    || c.contains("palace")
                    || c.contains("basilica")
                    || c.contains("synagogue")
                    || c.contains("mosque")) {
                tags.add(PreferenceTag.ARCHITECTURE);
            }

            if (c.contains("park")
                    || c.contains("garden")
                    || c.contains("natural")
                    || c.contains("beach")
                    || c.contains("viewpoint")
                    || c.contains("arboretum")
                    || c.contains("botanical")
                    || c.contains("botanic")) {
                tags.add(PreferenceTag.NATURE);
            }

            if (c.contains("zoo")) {
                tags.add(PreferenceTag.KIDS_FRIENDLY);
            }

            if (c.contains("mall")
                    || c.contains("commercial")
                    || c.contains("shopping")
                    || c.contains("market")) {
                tags.add(PreferenceTag.SHOPPING);
            }

            if (c.contains("restaurant")
                    || c.contains("cafe")
                    || c.contains("fast_food")) {
                tags.add(PreferenceTag.FOOD);
            }

            if (c.contains("bar")
                    || c.contains("nightclub")
                    || c.contains("pub")) {
                tags.add(PreferenceTag.NIGHTLIFE);
            }

            if (c.contains("music")
                    || c.contains("theatre")
                    || c.contains("opera")
                    || c.contains("entertainment.culture")
                    || c.contains("concert")) {
                tags.add(PreferenceTag.MUSIC);
            }
        }

        return Set.copyOf(tags);
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

    private String encode(String value) {
        return URLEncoder.encode(value, StandardCharsets.UTF_8);
    }

    private String safe(String value) {
        return value == null ? "" : value.trim();
    }

    private record CacheEntry(List<Poi> pois, long expiresAtMillis) {
        boolean isExpired() {
            return System.currentTimeMillis() > expiresAtMillis;
        }
    }
}