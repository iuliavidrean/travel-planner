package com.licenta.backend.service.ai;

import com.licenta.backend.dto.RouteSegmentResponse;
import com.licenta.backend.dto.ScheduleDayRouteResponse;
import com.licenta.backend.entity.ScheduleItem;
import com.licenta.backend.entity.ScheduleType;
import com.licenta.backend.entity.Trip;
import com.licenta.backend.repository.ScheduleItemRepository;
import org.springframework.stereotype.Service;

import java.time.LocalDate;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

@Service
public class DailyRoutePlannerService {

    private final ScheduleItemRepository scheduleItemRepository;
    private final DistanceAgent distanceAgent;

    public DailyRoutePlannerService(
            ScheduleItemRepository scheduleItemRepository,
            DistanceAgent distanceAgent
    ) {
        this.scheduleItemRepository = scheduleItemRepository;
        this.distanceAgent = distanceAgent;
    }

    public List<ScheduleDayRouteResponse> buildRoutesForTrip(Trip trip) {
        List<ScheduleItem> items = scheduleItemRepository.findByTripIdOrderByDayAscSortOrderAsc(trip.getId());

        Map<LocalDate, List<ScheduleItem>> grouped = new LinkedHashMap<>();
        for (ScheduleItem item : items) {
            grouped.computeIfAbsent(item.getDay(), d -> new ArrayList<>()).add(item);
        }

        List<ScheduleDayRouteResponse> result = new ArrayList<>();

        for (Map.Entry<LocalDate, List<ScheduleItem>> entry : grouped.entrySet()) {
            LocalDate day = entry.getKey();

            List<ScheduleItem> attractions = entry.getValue().stream()
                    .filter(i -> i.getType() == ScheduleType.ATTRACTION)
                    .filter(i -> i.getLat() != null && i.getLng() != null)
                    .toList();

            List<RouteSegmentResponse> segments = new ArrayList<>();

            if (trip.getAccommodationLat() != null
                    && trip.getAccommodationLng() != null
                    && !attractions.isEmpty()) {


                segments.add(buildSegment(
                        "Accommodation",
                        trip.getAccommodationLat(),
                        trip.getAccommodationLng(),
                        attractions.get(0).getTitle(),
                        attractions.get(0).getLat(),
                        attractions.get(0).getLng()
                ));


                for (int i = 0; i < attractions.size() - 1; i++) {
                    ScheduleItem from = attractions.get(i);
                    ScheduleItem to = attractions.get(i + 1);

                    segments.add(buildSegment(
                            from.getTitle(),
                            from.getLat(),
                            from.getLng(),
                            to.getTitle(),
                            to.getLat(),
                            to.getLng()
                    ));
                }


                ScheduleItem last = attractions.get(attractions.size() - 1);
                segments.add(buildSegment(
                        last.getTitle(),
                        last.getLat(),
                        last.getLng(),
                        "Accommodation",
                        trip.getAccommodationLat(),
                        trip.getAccommodationLng()
                ));
            }

            result.add(new ScheduleDayRouteResponse(day, segments));
        }

        return result;
    }

    private RouteSegmentResponse buildSegment(
            String fromTitle,
            Double fromLat,
            Double fromLng,
            String toTitle,
            Double toLat,
            Double toLng
    ) {
        RouteInfo walking = distanceAgent.getRouteInfo(fromLat, fromLng, toLat, toLng, TravelMode.WALKING);
        RouteInfo driving = distanceAgent.getRouteInfo(fromLat, fromLng, toLat, toLng, TravelMode.DRIVING);

        return new RouteSegmentResponse(
                fromTitle,
                fromLat,
                fromLng,
                toTitle,
                toLat,
                toLng,
                walking,
                driving
        );
    }
}