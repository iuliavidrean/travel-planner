package com.licenta.backend.service.ai;

import com.licenta.backend.entity.ScheduleItem;
import com.licenta.backend.entity.ScheduleItemStatus;
import com.licenta.backend.entity.ScheduleType;
import com.licenta.backend.entity.Trip;
import org.springframework.stereotype.Service;

import java.time.LocalDate;
import java.time.LocalTime;
import java.util.ArrayList;
import java.util.List;

@Service
public class PlanningAgent {


    private static final boolean DEBUG_PLANNING = true;

    private final DistanceAgent distanceAgent;

    public PlanningAgent(DistanceAgent distanceAgent) {
        this.distanceAgent = distanceAgent;
    }

    public List<ScheduleItem> buildSuggestedSchedule(Trip trip, List<Poi> orderedPois) {

        debug("=== BUILD SUGGESTED SCHEDULE ===");
        debug("Trip city: " + trip.getCity());
        debug("Trip pace: " + trip.getTravelPace());
        debug("Trip interval: " + trip.getStartDate() + " -> " + trip.getEndDate());
        debug("Ordered POIs received: " + (orderedPois == null ? 0 : orderedPois.size()));

        int attractionsPerDay = switch (trip.getTravelPace()) {
            case RELAXED -> 1;
            case BALANCED -> 2;
            case PACKED -> 3;
            default -> 2;
        };


        double maxDistanceKmSameDay = switch (trip.getTravelPace()) {
            case RELAXED -> Double.MAX_VALUE;
            case BALANCED -> 2.5;
            case PACKED -> 3.0;
            default -> 2.0;
        };

        record Slot(LocalTime start, LocalTime end, ScheduleType type, String title, boolean isAttraction) {}

        List<Slot> slots = switch (trip.getTravelPace()) {
            case RELAXED -> List.of(
                    new Slot(LocalTime.of(10, 0), LocalTime.of(12, 0), ScheduleType.ATTRACTION, "Attraction", true),
                    new Slot(LocalTime.of(13, 0), LocalTime.of(14, 30), ScheduleType.MEAL, "Lunch", false)
            );
            case BALANCED -> List.of(
                    new Slot(LocalTime.of(10, 0), LocalTime.of(12, 0), ScheduleType.ATTRACTION, "Attraction #1", true),
                    new Slot(LocalTime.of(13, 0), LocalTime.of(14, 30), ScheduleType.MEAL, "Lunch", false),
                    new Slot(LocalTime.of(15, 0), LocalTime.of(17, 0), ScheduleType.ATTRACTION, "Attraction #2", true)
            );
            case PACKED -> List.of(
                    new Slot(LocalTime.of(9, 0), LocalTime.of(11, 0), ScheduleType.ATTRACTION, "Attraction #1", true),
                    new Slot(LocalTime.of(11, 30), LocalTime.of(12, 0), ScheduleType.BREAK, "Coffee break", false),
                    new Slot(LocalTime.of(12, 30), LocalTime.of(14, 0), ScheduleType.MEAL, "Lunch", false),
                    new Slot(LocalTime.of(14, 30), LocalTime.of(16, 30), ScheduleType.ATTRACTION, "Attraction #2", true),
                    new Slot(LocalTime.of(17, 0), LocalTime.of(19, 0), ScheduleType.ATTRACTION, "Attraction #3", true)
            );
            default -> throw new IllegalStateException("travelPace missing");
        };

        List<List<Poi>> groupedPoisByDay = groupPoisByDay(
                trip,
                orderedPois,
                attractionsPerDay,
                maxDistanceKmSameDay
        );

        debug("Grouped days count: " + groupedPoisByDay.size());

        List<ScheduleItem> result = new ArrayList<>();
        LocalDate day = trip.getStartDate();

        for (List<Poi> poisForDay : groupedPoisByDay) {
            int sortOrder = 1;
            int poiIndexForDay = 0;

            debug("---- Day " + day + " ----");
            debug("POIs for day: " + poisForDay.size());
            for (Poi poi : poisForDay) {
                debug("  -> " + poi.title());
            }

            for (Slot s : slots) {
                ScheduleItem item = new ScheduleItem();
                item.setTrip(trip);
                item.setDay(day);
                item.setStartTime(s.start());
                item.setEndTime(s.end());
                item.setType(s.type());
                item.setSortOrder(sortOrder++);
                item.setStatus(ScheduleItemStatus.SUGGESTED);

                if (s.isAttraction()) {
                    if (poiIndexForDay >= poisForDay.size()) {
                        continue;
                    }

                    Poi poi = poisForDay.get(poiIndexForDay++);
                    item.setTitle(poi.title());
                    item.setLocationAddress(poi.locationAddress());
                    item.setLat(poi.lat());
                    item.setLng(poi.lng());
                } else {
                    item.setTitle(s.title());
                    item.setLocationAddress(null);
                }

                result.add(item);
            }

            day = day.plusDays(1);
            if (day.isAfter(trip.getEndDate())) {
                break;
            }
        }

        debug("Final schedule items count: " + result.size());
        return result;
    }

    private List<List<Poi>> groupPoisByDay(
            Trip trip,
            List<Poi> pois,
            int attractionsPerDay,
            double maxDistanceKmSameDay
    ) {
        List<List<Poi>> result = new ArrayList<>();

        if (pois == null || pois.isEmpty()) {
            return result;
        }

        List<Poi> remaining = new ArrayList<>(pois);

        LocalDate currentDay = trip.getStartDate();
        while (!currentDay.isAfter(trip.getEndDate()) && !remaining.isEmpty()) {

            debug("=== GROUPING DAY " + currentDay + " ===");
            debug("Remaining POIs before grouping: " + remaining.size());

            List<Poi> dayGroup = new ArrayList<>();

            // alegem un seed bun pentru ziua curentă
            Poi first = chooseBestSeedPoi(remaining, maxDistanceKmSameDay);
            if (first == null) {
                break;
            }

            debug("Chosen seed POI: " + first.title());

            remaining.remove(first);
            dayGroup.add(first);


            while (dayGroup.size() < attractionsPerDay && !remaining.isEmpty()) {
                Poi anchor = dayGroup.get(dayGroup.size() - 1);
                Poi nearest = findNearestPoiWithinLimit(anchor, remaining, maxDistanceKmSameDay);

                if (nearest == null) {
                    debug("No nearby POI found within limit from anchor: " + anchor.title());
                    break;
                }

                double km = distanceAgent.haversineKm(
                        anchor.lat(),
                        anchor.lng(),
                        nearest.lat(),
                        nearest.lng()
                );

                debug("Added by proximity: " + nearest.title() + " | anchor=" + anchor.title() + " | km=" + km);

                dayGroup.add(nearest);
                remaining.remove(nearest);
            }


            while (dayGroup.size() < attractionsPerDay && !remaining.isEmpty()) {
                Poi fallbackPoi = findBestFallbackPoi(dayGroup, remaining);

                if (fallbackPoi == null) {
                    fallbackPoi = remaining.get(0);
                    debug("Fallback was null, using first remaining: " + fallbackPoi.title());
                } else {
                    debug("Added by fallback: " + fallbackPoi.title());
                }

                dayGroup.add(fallbackPoi);
                remaining.remove(fallbackPoi);
            }


            dayGroup = orderDayGroup(dayGroup, trip);

            double dayRouteKm = calculateDayRouteKm(dayGroup);
            debug("Total intra-day route for " + currentDay + ": " + dayRouteKm + " km");

            debug("Ordered day group for " + currentDay + ":");
            for (Poi poi : dayGroup) {
                debug("  => " + poi.title());
            }

            result.add(dayGroup);
            currentDay = currentDay.plusDays(1);
        }

        return result;
    }

    private Poi chooseBestSeedPoi(List<Poi> remaining, double maxDistanceKmSameDay) {
        if (remaining == null || remaining.isEmpty()) {
            return null;
        }

        if (remaining.size() == 1) {
            return remaining.get(0);
        }


        int seedWindow = Math.min(5, remaining.size());

        Poi bestSeed = remaining.get(0);
        int bestNearbyCount = -1;
        double bestAverageDistance = Double.MAX_VALUE;

        for (int i = 0; i < seedWindow; i++) {
            Poi candidate = remaining.get(i);

            int nearbyCount = 0;
            double distanceSum = 0.0;

            for (int j = 0; j < remaining.size(); j++) {
                if (i == j) {
                    continue;
                }

                Poi other = remaining.get(j);

                double km = distanceAgent.haversineKm(
                        candidate.lat(),
                        candidate.lng(),
                        other.lat(),
                        other.lng()
                );

                if (km <= maxDistanceKmSameDay) {
                    nearbyCount++;
                    distanceSum += km;
                }
            }

            double averageDistance = nearbyCount > 0
                    ? distanceSum / nearbyCount
                    : Double.MAX_VALUE;

            debug("Seed candidate: " + candidate.title()
                    + " | nearbyCount=" + nearbyCount
                    + " | avgDistance=" + averageDistance);

            boolean betterCluster =
                    nearbyCount > bestNearbyCount
                            || (nearbyCount == bestNearbyCount && averageDistance < bestAverageDistance);

            if (betterCluster) {
                bestSeed = candidate;
                bestNearbyCount = nearbyCount;
                bestAverageDistance = averageDistance;
            }
        }

        debug("Best seed selected: " + bestSeed.title()
                + " | nearbyCount=" + bestNearbyCount
                + " | avgDistance=" + bestAverageDistance);

        return bestSeed;
    }

    private Poi findNearestPoiWithinLimit(Poi from, List<Poi> candidates, double maxDistanceKmSameDay) {
        if (from == null || candidates == null || candidates.isEmpty()) {
            return null;
        }

        Poi best = null;
        double bestKm = Double.MAX_VALUE;

        for (Poi candidate : candidates) {
            double km = distanceAgent.haversineKm(
                    from.lat(),
                    from.lng(),
                    candidate.lat(),
                    candidate.lng()
            );

            if (km <= maxDistanceKmSameDay && km < bestKm) {
                bestKm = km;
                best = candidate;
            }
        }

        if (best != null) {
            debug("Nearest within limit from " + from.title()
                    + " is " + best.title()
                    + " | km=" + bestKm);
        }

        return best;
    }

    private Poi findBestFallbackPoi(List<Poi> dayGroup, List<Poi> candidates) {
        if (dayGroup == null || dayGroup.isEmpty() || candidates == null || candidates.isEmpty()) {
            return null;
        }

        Poi best = null;
        double bestAverageKm = Double.MAX_VALUE;

        for (Poi candidate : candidates) {
            double sumKm = 0.0;

            for (Poi existing : dayGroup) {
                sumKm += distanceAgent.haversineKm(
                        candidate.lat(),
                        candidate.lng(),
                        existing.lat(),
                        existing.lng()
                );
            }

            double avgKm = sumKm / dayGroup.size();

            if (avgKm < bestAverageKm) {
                bestAverageKm = avgKm;
                best = candidate;
            }
        }

        if (best != null) {
            debug("Best fallback selected: " + best.title()
                    + " | avgKmToDayGroup=" + bestAverageKm);
        }

        return best;
    }

    private List<Poi> orderDayGroup(List<Poi> dayGroup, Trip trip) {
        if (dayGroup == null || dayGroup.size() <= 1) {
            return dayGroup;
        }

        List<Poi> ordered = new ArrayList<>();
        List<Poi> remaining = new ArrayList<>(dayGroup);


        Poi start = chooseStartPoiForDay(remaining, trip);

        if (start != null) {
            debug("Start POI for ordered day group: " + start.title());
        }

        ordered.add(start);
        remaining.remove(start);

        while (!remaining.isEmpty()) {
            Poi last = ordered.get(ordered.size() - 1);
            Poi next = findNearestPoi(last, remaining);

            if (next == null) {
                break;
            }

            double km = distanceAgent.haversineKm(
                    last.lat(),
                    last.lng(),
                    next.lat(),
                    next.lng()
            );

            debug("Route step: " + last.title() + " -> " + next.title() + " | km=" + km);

            ordered.add(next);
            remaining.remove(next);
        }

        return ordered;
    }

    private Poi chooseStartPoiForDay(List<Poi> pois, Trip trip) {
        if (pois == null || pois.isEmpty()) {
            return null;
        }

        if (pois.size() == 1) {
            return pois.get(0);
        }

        Double baseLat = trip.getAccommodationLat();
        Double baseLng = trip.getAccommodationLng();

        if (baseLat == null || baseLng == null) {
            return pois.get(0);
        }

        Poi best = null;
        double bestKm = Double.MAX_VALUE;

        for (Poi poi : pois) {
            double km = distanceAgent.haversineKm(
                    baseLat,
                    baseLng,
                    poi.lat(),
                    poi.lng()
            );

            if (km < bestKm) {
                bestKm = km;
                best = poi;
            }
        }

        return best != null ? best : pois.get(0);
    }

    private Poi findNearestPoi(Poi from, List<Poi> candidates) {
        if (from == null || candidates == null || candidates.isEmpty()) {
            return null;
        }

        Poi best = null;
        double bestKm = Double.MAX_VALUE;

        for (Poi candidate : candidates) {
            double km = distanceAgent.haversineKm(
                    from.lat(),
                    from.lng(),
                    candidate.lat(),
                    candidate.lng()
            );

            if (km < bestKm) {
                bestKm = km;
                best = candidate;
            }
        }

        if (best != null) {
            debug("Nearest POI from " + from.title()
                    + " is " + best.title()
                    + " | km=" + bestKm);
        }

        return best;
    }

    private double calculateDayRouteKm(List<Poi> orderedDayGroup) {
        if (orderedDayGroup == null || orderedDayGroup.size() <= 1) {
            return 0.0;
        }

        double totalKm = 0.0;

        for (int i = 0; i < orderedDayGroup.size() - 1; i++) {
            Poi from = orderedDayGroup.get(i);
            Poi to = orderedDayGroup.get(i + 1);

            totalKm += distanceAgent.haversineKm(
                    from.lat(),
                    from.lng(),
                    to.lat(),
                    to.lng()
            );
        }

        return totalKm;
    }

    private void debug(String message) {
        if (DEBUG_PLANNING) {
            System.out.println("[PLANNING] " + message);
        }
    }
}