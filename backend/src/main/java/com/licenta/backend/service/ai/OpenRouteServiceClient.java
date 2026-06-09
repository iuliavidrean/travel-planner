package com.licenta.backend.service.ai;

import com.fasterxml.jackson.databind.ObjectMapper;
import org.springframework.stereotype.Service;

import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.time.Duration;
import java.util.List;
import java.util.Locale;

@Service
public class OpenRouteServiceClient {

    private final OpenRouteServiceProperties properties;
    private final ObjectMapper objectMapper = new ObjectMapper();
    private final HttpClient httpClient = HttpClient.newHttpClient();

    public OpenRouteServiceClient(OpenRouteServiceProperties properties) {
        this.properties = properties;
    }

    public boolean isEnabled() {
        return properties.isEnabled()
                && properties.getApiKey() != null
                && !properties.getApiKey().isBlank();
    }

    public RouteInfo getRoute(
            double fromLat,
            double fromLng,
            double toLat,
            double toLng,
            TravelMode mode
    ) {
        if (!isEnabled()) {
            throw new IllegalStateException("OpenRouteService client is disabled.");
        }

        try {
            String profile = switch (mode) {
                case WALKING -> "foot-walking";
                case DRIVING -> "driving-car";
            };

            String url = properties.getBaseUrl()
                    + "/v2/directions/"
                    + profile
                    + "?start=" + formatCoord(fromLng) + "," + formatCoord(fromLat)
                    + "&end=" + formatCoord(toLng) + "," + formatCoord(toLat);

            System.out.println("=== OPENROUTESERVICE CLIENT ===");
            System.out.println("ORS route URL: " + url);

            HttpRequest request = HttpRequest.newBuilder()
                    .uri(URI.create(url))
                    .timeout(Duration.ofMillis(properties.getRequestTimeoutMs()))
                    .header("Authorization", properties.getApiKey())
                    .header("Accept", "application/geo+json")
                    .header("User-Agent", "TravelPlannerLicenta/1.0")
                    .GET()
                    .build();

            HttpResponse<String> response = httpClient.send(
                    request,
                    HttpResponse.BodyHandlers.ofString()
            );

            System.out.println("ORS status: " + response.statusCode());

            if (response.statusCode() != 200) {
                System.out.println("ORS body: " + response.body());
                throw new RuntimeException("OpenRouteService request failed with status " + response.statusCode());
            }

            OpenRouteServiceDirectionsResponse parsed =
                    objectMapper.readValue(response.body(), OpenRouteServiceDirectionsResponse.class);

            if (parsed == null
                    || parsed.features() == null
                    || parsed.features().isEmpty()
                    || parsed.features().get(0) == null
                    || parsed.features().get(0).properties() == null
                    || parsed.features().get(0).properties().summary() == null) {
                throw new RuntimeException("OpenRouteService returned no routes.");
            }

            OpenRouteServiceDirectionsResponse.Feature feature = parsed.features().get(0);

            double distanceKm = feature.properties().summary().distance() / 1000.0;
            int durationMinutes = (int) Math.max(1, Math.round(feature.properties().summary().duration() / 60.0));

            List<List<Double>> geometry = feature.geometry() != null
                    ? feature.geometry().coordinates()
                    : List.of();

            System.out.println("ORS success: mode=" + mode
                    + " distanceKm=" + distanceKm
                    + " durationMin=" + durationMinutes
                    + " geometryPoints=" + geometry.size());

            return new RouteInfo(
                    distanceKm,
                    durationMinutes,
                    mode.name(),
                    false,
                    geometry
            );

        } catch (Exception e) {
            throw new RuntimeException("Failed to fetch route from OpenRouteService.", e);
        }
    }

    private String formatCoord(double value) {
        return String.format(Locale.US, "%.6f", value);
    }
}