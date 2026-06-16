package com.licenta.backend.service.geo;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.springframework.stereotype.Service;

import java.net.URI;
import java.net.URLEncoder;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.nio.charset.StandardCharsets;

@Service
public class AccommodationGeocodingService {

    private final HttpClient httpClient = HttpClient.newHttpClient();
    private final ObjectMapper objectMapper = new ObjectMapper();


    public GeocodingResult geocodeAddress(String address) {
        try {
            if (address == null || address.isBlank()) {
                return null;
            }

            String encoded = URLEncoder.encode(address.trim(), StandardCharsets.UTF_8);
            String url = "https://nominatim.openstreetmap.org/search?format=jsonv2&limit=1&q=" + encoded;

            HttpRequest request = HttpRequest.newBuilder()
                    .uri(URI.create(url))
                    .header("Accept", "application/json")
                    .header("User-Agent", "TravelPlannerLicenta/1.0")
                    .GET()
                    .build();

            HttpResponse<String> response = httpClient.send(request, HttpResponse.BodyHandlers.ofString());

            if (response.statusCode() != 200) {
                return null;
            }

            JsonNode root = objectMapper.readTree(response.body());
            if (!root.isArray() || root.isEmpty()) {
                return null;
            }

            JsonNode first = root.get(0);

            Double lat = first.hasNonNull("lat") ? first.get("lat").asDouble() : null;
            Double lng = first.hasNonNull("lon") ? first.get("lon").asDouble() : null;
            String displayName = first.hasNonNull("display_name") ? first.get("display_name").asText() : address;

            if (lat == null || lng == null) {
                return null;
            }

            return new GeocodingResult(lat, lng, displayName);
        } catch (Exception e) {
            return null;
        }
    }
}