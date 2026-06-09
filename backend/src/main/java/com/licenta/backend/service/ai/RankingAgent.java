package com.licenta.backend.service.ai;

import com.licenta.backend.entity.PreferenceTag;
import com.licenta.backend.entity.Trip;
import org.springframework.stereotype.Service;

import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;
import java.util.Set;

@Service
public class RankingAgent {

    private final DistanceAgent distanceAgent;

    public RankingAgent(DistanceAgent distanceAgent) {
        this.distanceAgent = distanceAgent;
    }

    public List<Poi> rankPois(Trip trip, List<Poi> pois) {
        if (pois == null || pois.isEmpty()) {
            return List.of();
        }

        Set<PreferenceTag> preferences =
                trip.getPreferences() == null ? Set.of() : trip.getPreferences();

        Double accLat = trip.getAccommodationLat();
        Double accLng = trip.getAccommodationLng();

        List<RankedPoi> ranked = new ArrayList<>();

        for (int i = 0; i < pois.size(); i++) {
            Poi poi = pois.get(i);


            int originalOrderScore = Math.max(0, 100 - i * 3);


            int preference = preferenceScore(poi, preferences);
            int distance = distancePoints(poi, accLat, accLng);

            int finalScore = originalOrderScore + preference + distance;

            ranked.add(new RankedPoi(poi, finalScore));
        }

        return ranked.stream()
                .sorted(
                        Comparator
                                .comparingInt(RankedPoi::score).reversed()
                                .thenComparing(r -> r.poi().title())
                )
                .map(RankedPoi::poi)
                .toList();
    }

    private int preferenceScore(Poi poi, Set<PreferenceTag> preferences) {
        if (preferences == null || preferences.isEmpty()) {
            return 0;
        }

        if (poi.tags() == null || poi.tags().isEmpty()) {
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

    private int distancePoints(Poi poi, Double accLat, Double accLng) {
        if (accLat == null || accLng == null) {
            return 0;
        }

        double km = distanceAgent.haversineKm(accLat, accLng, poi.lat(), poi.lng());

        if (km <= 1.0) return 10;
        if (km <= 2.5) return 7;
        if (km <= 5.0) return 4;
        if (km <= 8.0) return 2;

        return 0;
    }

    private record RankedPoi(Poi poi, int score) {}
}