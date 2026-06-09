package com.licenta.backend.service.ai;

import com.licenta.backend.dto.PlanningMode;
import com.licenta.backend.entity.Trip;
import com.licenta.backend.repository.ScheduleItemRepository;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.web.server.ResponseStatusException;

@Service
public class PlanningOrchestrator {

    private final AttractionsAgent attractionsAgent;
    private final RankingAgent rankingAgent;
    private final PlanningAgent planningAgent;
    private final ScheduleItemRepository scheduleItemRepository;

    public PlanningOrchestrator(
            AttractionsAgent attractionsAgent,
            RankingAgent rankingAgent,
            PlanningAgent planningAgent,
            ScheduleItemRepository scheduleItemRepository
    ) {
        this.attractionsAgent = attractionsAgent;
        this.rankingAgent = rankingAgent;
        this.planningAgent = planningAgent;
        this.scheduleItemRepository = scheduleItemRepository;
    }

    public void validateAccommodationIfNeeded(Trip trip, PlanningMode mode) {
        if (mode != PlanningMode.SUGGESTED) return;

        boolean hasLat = trip.getAccommodationLat() != null;
        boolean hasLng = trip.getAccommodationLng() != null;
        boolean hasAddr = trip.getAccommodationAddress() != null
                && !trip.getAccommodationAddress().isBlank();

        if (!(hasLat && hasLng && hasAddr)) {
            throw new ResponseStatusException(
                    HttpStatus.BAD_REQUEST,
                    "Accommodation is required for SUGGESTED planning. Please set accommodationAddress + lat/lng."
            );
        }
    }

    public void generateSuggestedPlan(Trip trip, boolean clearExisting) {

        if (clearExisting) {
            scheduleItemRepository.deleteByTripId(trip.getId());
        } else {
            boolean hasAny = scheduleItemRepository.existsByTripId(trip.getId());
            if (hasAny) {
                throw new ResponseStatusException(
                        HttpStatus.BAD_REQUEST,
                        "Schedule already exists. Use clearExisting=true to regenerate."
                );
            }
        }

        long totalStart = System.currentTimeMillis();

        long t0 = System.currentTimeMillis();
        var candidatePois = attractionsAgent.getPoisForTrip(trip);
        long t1 = System.currentTimeMillis();
        System.out.println("AttractionsAgent ms = " + (t1 - t0));
        System.out.println("Candidate POIs count = " + candidatePois.size());

        var rankedPois = rankingAgent.rankPois(trip, candidatePois);
        long t2 = System.currentTimeMillis();
        System.out.println("RankingAgent ms = " + (t2 - t1));
        System.out.println("Ranked POIs count = " + rankedPois.size());

        var scheduleItems = planningAgent.buildSuggestedSchedule(trip, rankedPois);
        long t3 = System.currentTimeMillis();
        System.out.println("PlanningAgent ms = " + (t3 - t2));
        System.out.println("Schedule items count = " + scheduleItems.size());

        scheduleItemRepository.saveAll(scheduleItems);
        long t4 = System.currentTimeMillis();
        System.out.println("Save schedule ms = " + (t4 - t3));

        System.out.println("TOTAL generateSuggestedPlan ms = " + (t4 - totalStart));
    }
}