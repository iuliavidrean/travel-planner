package com.licenta.backend.service.ai;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.springframework.stereotype.Service;

import java.net.URI;
import java.net.URLEncoder;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.nio.charset.StandardCharsets;
import java.util.Locale;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

@Service
public class WikimediaEnrichmentClient {

    private final HttpClient httpClient = HttpClient.newHttpClient();
    private final ObjectMapper objectMapper = new ObjectMapper();


    private final Map<String, Integer> cache = new ConcurrentHashMap<>();

    public int getPopularityBoost(String title, String city) {
        if (title == null || title.isBlank()) {
            return 0;
        }

        String normalizedTitle = normalize(title);
        String normalizedCity = normalize(city);

        String cacheKey = normalizedTitle + "|" + normalizedCity;
        Integer cached = cache.get(cacheKey);
        if (cached != null) {
            return cached;
        }

        try {
            String query = "\"" + title + "\"";
            if (city != null && !city.isBlank()) {
                query += " " + city;
            }

            String url = "https://en.wikipedia.org/w/api.php"
                    + "?action=query"
                    + "&list=search"
                    + "&format=json"
                    + "&srlimit=3"
                    + "&srsearch=" + URLEncoder.encode(query, StandardCharsets.UTF_8);

            HttpRequest request = HttpRequest.newBuilder()
                    .uri(URI.create(url))
                    .timeout(java.time.Duration.ofSeconds(4))
                    .header("Accept", "application/json")
                    .header("User-Agent", "TravelPlannerLicenta/1.0")
                    .GET()
                    .build();

            HttpResponse<String> response = httpClient.send(
                    request,
                    HttpResponse.BodyHandlers.ofString()
            );

            if (response.statusCode() != 200) {
                cache.put(cacheKey, 0);
                return 0;
            }

            JsonNode root = objectMapper.readTree(response.body());
            JsonNode search = root.path("query").path("search");

            if (!search.isArray() || search.isEmpty()) {
                cache.put(cacheKey, 0);
                return 0;
            }

            int bestBoost = 0;

            for (JsonNode node : search) {
                String pageTitle = normalize(node.path("title").asText(""));
                String snippet = normalize(node.path("snippet").asText(""));

                int score = 0;

                if (pageTitle.equals(normalizedTitle)) {
                    score += 14;
                } else if (pageTitle.contains(normalizedTitle) || normalizedTitle.contains(pageTitle)) {
                    score += 10;
                }

                if (!normalizedCity.isBlank()
                        && (pageTitle.contains(normalizedCity) || snippet.contains(normalizedCity))) {
                    score += 4;
                }

                if (containsAny(pageTitle + " " + snippet,
                        "museum", "opera", "palace", "cathedral", "bridge", "tower",
                        "landmark", "art gallery", "national", "historic", "architecture")) {
                    score += 3;
                }

                if (score > bestBoost) {
                    bestBoost = score;
                }
            }

            int finalBoost = Math.min(bestBoost, 18);
            cache.put(cacheKey, finalBoost);
            return finalBoost;

        } catch (Exception e) {
            cache.put(cacheKey, 0);
            return 0;
        }
    }

    private boolean containsAny(String text, String... terms) {
        if (text == null || text.isBlank()) {
            return false;
        }

        for (String term : terms) {
            if (text.contains(term)) {
                return true;
            }
        }

        return false;
    }

    private String normalize(String value) {
        if (value == null) {
            return "";
        }

        return value.toLowerCase(Locale.ROOT)
                .replaceAll("<[^>]*>", " ")
                .replace("á", "a")
                .replace("à", "a")
                .replace("ä", "a")
                .replace("â", "a")
                .replace("ã", "a")
                .replace("å", "a")
                .replace("é", "e")
                .replace("è", "e")
                .replace("ë", "e")
                .replace("ê", "e")
                .replace("í", "i")
                .replace("ì", "i")
                .replace("ï", "i")
                .replace("î", "i")
                .replace("ó", "o")
                .replace("ò", "o")
                .replace("ö", "o")
                .replace("ô", "o")
                .replace("õ", "o")
                .replace("ú", "u")
                .replace("ù", "u")
                .replace("ü", "u")
                .replace("û", "u")
                .replace("ß", "ss")
                .replace("þ", "th")
                .replace("ð", "d")
                .replaceAll("[^\\p{L}\\p{N} ]", " ")
                .replaceAll("\\s+", " ")
                .trim();
    }
}