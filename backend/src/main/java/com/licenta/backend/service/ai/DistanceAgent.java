package com.licenta.backend.service.ai;

import org.springframework.stereotype.Service;

import java.util.List;

@Service
public class DistanceAgent {

    private final OpenRouteServiceClient openRouteServiceClient;

    public DistanceAgent(OpenRouteServiceClient openRouteServiceClient) {
        this.openRouteServiceClient = openRouteServiceClient;
    }

    public RouteInfo getRouteInfo(
            double fromLat,
            double fromLng,
            double toLat,
            double toLng,
            TravelMode mode
    ) {
        try {
            return openRouteServiceClient.getRoute(fromLat, fromLng, toLat, toLng, mode);
        } catch (Exception e) {
            double km = haversineKm(fromLat, fromLng, toLat, toLng);

            int durationMinutes = switch (mode) {
                case WALKING -> (int) Math.max(1, Math.round((km / 5.0) * 60.0));
                case DRIVING -> (int) Math.max(1, Math.round((km / 30.0) * 60.0));
            };

            System.out.println("DistanceAgent fallback used: mode=" + mode
                    + " from=(" + fromLat + "," + fromLng + ")"
                    + " to=(" + toLat + "," + toLng + ")"
                    + " estimatedKm=" + km
                    + " estimatedMin=" + durationMinutes);

            return new RouteInfo(
                    km,
                    durationMinutes,
                    mode.name(),
                    true,
                    List.of(
                            List.of(fromLng, fromLat),
                            List.of(toLng, toLat)
                    )
            );
        }
    }

    public double haversineKm(double lat1, double lon1, double lat2, double lon2) {
        final double R = 6371.0;

        double dLat = Math.toRadians(lat2 - lat1);
        double dLon = Math.toRadians(lon2 - lon1);

        double a = Math.sin(dLat / 2) * Math.sin(dLat / 2)
                + Math.cos(Math.toRadians(lat1)) * Math.cos(Math.toRadians(lat2))
                * Math.sin(dLon / 2) * Math.sin(dLon / 2);

        double c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
        return R * c;
    }
}

