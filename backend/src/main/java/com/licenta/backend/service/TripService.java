package com.licenta.backend.service;

import com.licenta.backend.repository.UserRepository;
import com.licenta.backend.entity.User;
import com.licenta.backend.dto.TripCreateRequest;
import com.licenta.backend.dto.TripResponse;
import com.licenta.backend.dto.TripUpdateRequest;
import com.licenta.backend.dto.ScheduleItemCreateRequest;
import com.licenta.backend.dto.ScheduleItemUpdateRequest;
import com.licenta.backend.dto.ScheduleItemResponse;
import com.licenta.backend.dto.ScheduleReorderRequest;
import com.licenta.backend.dto.ScheduleDayResponse;
import com.licenta.backend.dto.TripPlanRequest;
import com.licenta.backend.dto.PlanningMode;
import com.licenta.backend.dto.ScheduleDayRouteResponse;
import com.licenta.backend.service.ai.DistanceAgent;
import com.licenta.backend.service.ai.TravelMode;
import com.licenta.backend.dto.RouteSegmentResponse;
import com.licenta.backend.service.ai.PlanningOrchestrator;
import com.licenta.backend.entity.Trip;
import com.licenta.backend.entity.ScheduleItem;
import com.licenta.backend.repository.TripRepository;
import com.licenta.backend.repository.ScheduleItemRepository;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.web.server.ResponseStatusException;
import org.springframework.transaction.annotation.Transactional;
import com.licenta.backend.service.geo.AccommodationGeocodingService;
import com.licenta.backend.service.geo.GeocodingResult;
import java.time.LocalDate;
import java.time.LocalTime;
import java.util.List;
import java.util.stream.Collectors;
import java.util.concurrent.ConcurrentHashMap;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.Map;

@Service
public class TripService {

    private final TripRepository tripRepository;
    private final ScheduleItemRepository scheduleItemRepository;
    private final UserRepository userRepository;
    private final PlanningOrchestrator planningOrchestrator;
    private final AccommodationGeocodingService accommodationGeocodingService;
    private final DistanceAgent distanceAgent;
    private static final long ROUTE_CACHE_TTL_MILLIS = 30 * 60 * 1000; // 30 min
    private final ConcurrentHashMap<String, RouteCacheEntry> routePlanCache = new ConcurrentHashMap<>();


    public TripService(TripRepository tripRepository,
                       ScheduleItemRepository scheduleItemRepository,
                       UserRepository userRepository,
                       PlanningOrchestrator planningOrchestrator,
                       AccommodationGeocodingService accommodationGeocodingService,
                       DistanceAgent distanceAgent) {
        this.tripRepository = tripRepository;
        this.scheduleItemRepository = scheduleItemRepository;
        this.userRepository = userRepository;
        this.planningOrchestrator = planningOrchestrator;
        this.accommodationGeocodingService = accommodationGeocodingService;
        this.distanceAgent = distanceAgent;
    }


    public TripResponse createTrip(TripCreateRequest req) {
        Trip t = new Trip();
        t.setCountry(req.getCountry());
        t.setCity(req.getCity());
        t.setStartDate(req.getStartDate());
        t.setEndDate(req.getEndDate());

        t.setAccommodationAddress(req.getAccommodationAddress());
        t.setAccommodationLat(req.getAccommodationLat());
        t.setAccommodationLng(req.getAccommodationLng());


        if (t.getAccommodationAddress() != null && !t.getAccommodationAddress().isBlank()
                && t.getAccommodationLat() == null && t.getAccommodationLng() == null) {

            GeocodingResult geo = accommodationGeocodingService.geocodeAddress(t.getAccommodationAddress());

            if (geo != null) {
                t.setAccommodationLat(geo.lat());
                t.setAccommodationLng(geo.lng());
            }
        }

        t.setTravelPace(req.getTravelPace());

        boolean hasLat = req.getAccommodationLat() != null;
        boolean hasLng = req.getAccommodationLng() != null;
        if (hasLat != hasLng) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "accommodationLat and accommodationLng must be provided together");
        }

        if (req.getEndDate().isBefore(req.getStartDate())) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "endDate must be >= startDate");
        }

        if (req.getPreferences() != null) {
            t.setPreferences(req.getPreferences());
        }

        String email = currentUserEmail();
        User owner = userRepository.findByEmail(email)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.UNAUTHORIZED, "User not found"));
        t.setOwner(owner);

        Trip saved = tripRepository.save(t);
        return toResponse(saved);
    }


    public TripResponse getTrip(Long id) {
        Trip t = requireOwnedTrip(id);
        return toResponse(t);
    }


    private TripResponse toResponse(Trip t) {
        TripResponse r = new TripResponse();
        r.id = t.getId();
        r.country = t.getCountry();
        r.city = t.getCity();
        r.startDate = t.getStartDate();
        r.endDate = t.getEndDate();
        r.accommodationAddress = t.getAccommodationAddress();
        r.accommodationLat = t.getAccommodationLat();
        r.accommodationLng = t.getAccommodationLng();
        r.travelPace = t.getTravelPace();
        r.preferences = t.getPreferences();
        return r;
    }



    private com.licenta.backend.dto.ScheduleItemResponse toScheduleResponse(com.licenta.backend.entity.ScheduleItem item) {
        com.licenta.backend.dto.ScheduleItemResponse r = new com.licenta.backend.dto.ScheduleItemResponse();
        r.id = item.getId();
        r.day = item.getDay();
        r.startTime = item.getStartTime();
        r.endTime = item.getEndTime();
        r.type = item.getType();
        r.title = item.getTitle();
        r.lat = item.getLat();
        r.lng = item.getLng();
        r.locationAddress = item.getLocationAddress();
        r.sortOrder = item.getSortOrder();
        r.status = item.getStatus();
        return r;
    }



    public void deleteTrip(Long id) {
        Trip trip = requireOwnedTrip(id);
        invalidateRouteCacheForTrip(id);
        tripRepository.delete(trip);
    }



    public List<TripResponse> listTrips() {
        String email = currentUserEmail();
        return tripRepository.findAllByOwnerEmailOrderByStartDateAsc(email)
                .stream()
                .map(this::toResponse)
                .collect(Collectors.toList());
    }



    // Update (PATCH)
    public TripResponse updateTrip(Long id, TripUpdateRequest req) {


        Trip t = requireOwnedTrip(id);


        if (req.getCountry() != null) t.setCountry(req.getCountry());
        if (req.getCity() != null) t.setCity(req.getCity());
        if (req.getStartDate() != null) t.setStartDate(req.getStartDate());
        if (req.getEndDate() != null) t.setEndDate(req.getEndDate());

        if (req.getAccommodationAddress() != null) t.setAccommodationAddress(req.getAccommodationAddress());
        if (req.getAccommodationLat() != null) t.setAccommodationLat(req.getAccommodationLat());
        if (req.getAccommodationLng() != null) t.setAccommodationLng(req.getAccommodationLng());


        if (t.getAccommodationAddress() != null && !t.getAccommodationAddress().isBlank()
                && t.getAccommodationLat() == null && t.getAccommodationLng() == null) {

            GeocodingResult geo = accommodationGeocodingService.geocodeAddress(t.getAccommodationAddress());

            if (geo != null) {
                t.setAccommodationLat(geo.lat());
                t.setAccommodationLng(geo.lng());
            }
        }

        if (req.getTravelPace() != null) t.setTravelPace(req.getTravelPace());


        if (req.getPreferences() != null) t.setPreferences(req.getPreferences());


        boolean hasLat = t.getAccommodationLat() != null;
        boolean hasLng = t.getAccommodationLng() != null;
        if (hasLat != hasLng) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST,
                    "accommodationLat and accommodationLng must be provided together");
        }

        if (t.getStartDate() != null && t.getEndDate() != null && t.getEndDate().isBefore(t.getStartDate())) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "endDate must be >= startDate");
        }

        invalidateRouteCacheForTrip(id);


        Trip saved = tripRepository.save(t);
        return toResponse(saved);
    }




    public List<com.licenta.backend.dto.ScheduleItemResponse> getSchedule(Long tripId) {

        requireOwnedTrip(tripId);

        return scheduleItemRepository.findByTripIdOrderByDayAscSortOrderAsc(tripId)
                .stream()
                .map(this::toScheduleResponse)
                .collect(Collectors.toList());
    }






    public ScheduleItemResponse addScheduleItem(Long tripId, ScheduleItemCreateRequest req) {


        Trip trip = requireOwnedTrip(tripId);


        if (req.getStartTime() != null && req.getEndTime() != null) {
            if (!req.getEndTime().isAfter(req.getStartTime())) {
                throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "endTime must be after startTime");
            }
        }


        boolean hasLat = req.getLat() != null;
        boolean hasLng = req.getLng() != null;
        if (hasLat != hasLng) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "lat and lng must be provided together");
        }


        validateDayInsideTrip(trip, req.getDay());


        validateNoTimeOverlap(tripId, req.getDay(), req.getStartTime(), req.getEndTime(), null);


        ScheduleItem item = new ScheduleItem();
        item.setTrip(trip);
        item.setDay(req.getDay());
        item.setStartTime(req.getStartTime());
        item.setEndTime(req.getEndTime());
        item.setType(req.getType());
        item.setTitle(req.getTitle());
        item.setLat(req.getLat());
        item.setLng(req.getLng());
        item.setLocationAddress(req.getLocationAddress());
        item.setStatus(com.licenta.backend.entity.ScheduleItemStatus.CONFIRMED);

        Integer sortOrder = req.getSortOrder();

        if (sortOrder == null) {
            int last = scheduleItemRepository
                    .findTopByTripIdAndDayOrderBySortOrderDesc(tripId, req.getDay())
                    .map(ScheduleItem::getSortOrder)
                    .orElse(0);
            sortOrder = last + 1;
        }

        item.setSortOrder(sortOrder);


        ScheduleItem saved = scheduleItemRepository.save(item);

        invalidateRouteCacheForTrip(tripId);
        return toScheduleResponse(saved);
    }





    public ScheduleItemResponse updateScheduleItem(Long tripId, Long itemId, ScheduleItemUpdateRequest req) {

        Trip trip = requireOwnedTrip(tripId);

        ScheduleItem item = scheduleItemRepository.findByIdAndTripId(itemId, tripId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Schedule item not found: " + itemId));


        boolean manuallyEdited =
                req.getDay() != null ||
                        req.getStartTime() != null ||
                        req.getEndTime() != null ||
                        req.getType() != null ||
                        req.getTitle() != null ||
                        req.getLat() != null ||
                        req.getLng() != null ||
                        req.getLocationAddress() != null ||
                        Boolean.TRUE.equals(req.getClearLocation()) ||
                        req.getSortOrder() != null;


        if (req.getDay() != null) item.setDay(req.getDay());
        if (req.getStartTime() != null) item.setStartTime(req.getStartTime());
        if (req.getEndTime() != null) item.setEndTime(req.getEndTime());
        if (req.getType() != null) item.setType(req.getType());
        if (req.getTitle() != null) item.setTitle(req.getTitle());

        if (Boolean.TRUE.equals(req.getClearLocation())) {
            item.setLat(null);
            item.setLng(null);
            item.setLocationAddress(null);
        } else {
            if (req.getLat() != null) item.setLat(req.getLat());
            if (req.getLng() != null) item.setLng(req.getLng());
            if (req.getLocationAddress() != null) item.setLocationAddress(req.getLocationAddress());
        }

        if (req.getSortOrder() != null) item.setSortOrder(req.getSortOrder());


        if (manuallyEdited) {
            item.setStatus(com.licenta.backend.entity.ScheduleItemStatus.CONFIRMED);
        }


        if (item.getStartTime() != null && item.getEndTime() != null) {
            if (!item.getEndTime().isAfter(item.getStartTime())) {
                throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "endTime must be after startTime");
            }
        }


        boolean hasLat = item.getLat() != null;
        boolean hasLng = item.getLng() != null;
        if (hasLat != hasLng) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "lat and lng must be provided together");
        }


        validateDayInsideTrip(trip, item.getDay());


        validateNoTimeOverlap(tripId, item.getDay(), item.getStartTime(), item.getEndTime(), item.getId());


        ScheduleItem saved = scheduleItemRepository.save(item);

        invalidateRouteCacheForTrip(tripId);
        return toScheduleResponse(saved);
    }





    public void deleteScheduleItem(Long tripId, Long itemId) {

        requireOwnedTrip(tripId);

        ScheduleItem item = scheduleItemRepository.findByIdAndTripId(itemId, tripId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Schedule item not found: " + itemId));

        scheduleItemRepository.delete(item);

        invalidateRouteCacheForTrip(tripId);
    }



    private void validateDayInsideTrip(Trip trip, java.time.LocalDate day) {
        if (day == null) return;

        if (trip.getStartDate() != null && day.isBefore(trip.getStartDate())) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST,
                    "day must be within trip interval (>= startDate)");
        }
        if (trip.getEndDate() != null && day.isAfter(trip.getEndDate())) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST,
                    "day must be within trip interval (<= endDate)");
        }
    }




    private boolean overlaps(LocalTime aStart, LocalTime aEnd, LocalTime bStart, LocalTime bEnd) {
        return aStart.isBefore(bEnd) && bStart.isBefore(aEnd);
    }




    private void validateNoTimeOverlap(Long tripId, java.time.LocalDate day,
                                       java.time.LocalTime startTime, java.time.LocalTime endTime,
                                       Long excludeItemId) {

        if (day == null || startTime == null || endTime == null) return;


        List<ScheduleItem> sameDayItems = scheduleItemRepository.findByTripIdAndDay(tripId, day);

        for (ScheduleItem existing : sameDayItems) {

            if (existing.getId().equals(excludeItemId)) {
                continue;
            }

            if (existing.getStartTime() == null || existing.getEndTime() == null) continue;

            if (overlaps(startTime, endTime, existing.getStartTime(), existing.getEndTime())) {
                throw new ResponseStatusException(HttpStatus.BAD_REQUEST,
                        "Schedule item overlaps with existing item id=" + existing.getId());
            }
        }
    }




    public List<ScheduleItemResponse> reorderSchedule(Long tripId, ScheduleReorderRequest req) {


        Trip trip = requireOwnedTrip(tripId);


        validateDayInsideTrip(trip, req.getDay());


        List<ScheduleItem> items = scheduleItemRepository
                .findByTripIdAndDayOrderBySortOrderAsc(tripId, req.getDay());

        if (items.isEmpty()) {
            return List.of();
        }

        var existingIds = items.stream().map(ScheduleItem::getId).collect(java.util.stream.Collectors.toSet());
        var requestedIds = new java.util.HashSet<>(req.getItemIds());

        if (!existingIds.equals(requestedIds)) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST,
                    "itemIds must contain exactly the schedule items of that day");
        }

        var mapById = items.stream()
                .collect(java.util.stream.Collectors.toMap(ScheduleItem::getId, x -> x));

        int order = 1;
        for (Long id : req.getItemIds()) {
            ScheduleItem item = mapById.get(id);
            item.setSortOrder(order++);
            item.setStatus(com.licenta.backend.entity.ScheduleItemStatus.CONFIRMED);
        }

        scheduleItemRepository.saveAll(items);

        invalidateRouteCacheForTrip(tripId);

        return scheduleItemRepository.findByTripIdAndDayOrderBySortOrderAsc(tripId, req.getDay())
                .stream()
                .map(this::toScheduleResponse)
                .collect(Collectors.toList());
    }




    public List<ScheduleDayResponse> getScheduleByDay(Long tripId) {


        requireOwnedTrip(tripId);


        List<ScheduleItem> items = scheduleItemRepository
                .findByTripIdOrderByDayAscSortOrderAsc(tripId);


        Map<LocalDate, List<ScheduleItemResponse>> grouped = new LinkedHashMap<>();

        for (ScheduleItem it : items) {
            LocalDate day = it.getDay();


            grouped.computeIfAbsent(day, d -> new ArrayList<>());


            grouped.get(day).add(toScheduleResponse(it));
        }


        List<ScheduleDayResponse> response = new ArrayList<>();
        for (var entry : grouped.entrySet()) {
            response.add(new ScheduleDayResponse(entry.getKey(), entry.getValue()));
        }

        return response;
    }




    @Transactional
    public List<com.licenta.backend.dto.ScheduleDayResponse> generateSchedule(Long tripId, boolean clearExisting) {

        Trip trip = requireOwnedTrip(tripId);


        if (!clearExisting) {
            boolean hasAny = scheduleItemRepository.existsByTripId(tripId);
            if (hasAny) {
                throw new ResponseStatusException(HttpStatus.BAD_REQUEST,
                        "Schedule already exists. Use clearExisting=true to regenerate.");
            }
        }

        if (trip.getStartDate() == null || trip.getEndDate() == null) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Trip must have startDate and endDate to generate schedule");
        }

        if (clearExisting) {

            scheduleItemRepository.deleteByTripId(tripId);
        }


        record Slot(java.time.LocalTime start, java.time.LocalTime end, com.licenta.backend.entity.ScheduleType type, String title) {}

        List<Slot> slots;
        switch (trip.getTravelPace()) {
            case RELAXED -> slots = List.of(
                    new Slot(java.time.LocalTime.of(10, 0), java.time.LocalTime.of(12, 0), com.licenta.backend.entity.ScheduleType.ATTRACTION, "Attraction (morning)"),
                    new Slot(java.time.LocalTime.of(13, 0), java.time.LocalTime.of(14, 30), com.licenta.backend.entity.ScheduleType.MEAL, "Lunch")
            );
            case BALANCED -> slots = List.of(
                    new Slot(java.time.LocalTime.of(10, 0), java.time.LocalTime.of(12, 0), com.licenta.backend.entity.ScheduleType.ATTRACTION, "Attraction #1 (morning)"),
                    new Slot(java.time.LocalTime.of(13, 0), java.time.LocalTime.of(14, 30), com.licenta.backend.entity.ScheduleType.MEAL, "Lunch"),
                    new Slot(java.time.LocalTime.of(15, 0), java.time.LocalTime.of(17, 0), com.licenta.backend.entity.ScheduleType.ATTRACTION, "Attraction #2 (afternoon)")
            );
            case PACKED -> slots = List.of(
                    new Slot(java.time.LocalTime.of(9, 0), java.time.LocalTime.of(11, 0), com.licenta.backend.entity.ScheduleType.ATTRACTION, "Attraction #1 (morning)"),
                    new Slot(java.time.LocalTime.of(11, 30), java.time.LocalTime.of(12, 0), com.licenta.backend.entity.ScheduleType.BREAK, "Coffee break"),
                    new Slot(java.time.LocalTime.of(12, 30), java.time.LocalTime.of(14, 0), com.licenta.backend.entity.ScheduleType.MEAL, "Lunch"),
                    new Slot(java.time.LocalTime.of(14, 30), java.time.LocalTime.of(16, 30), com.licenta.backend.entity.ScheduleType.ATTRACTION, "Attraction #2 (afternoon)"),
                    new Slot(java.time.LocalTime.of(17, 0), java.time.LocalTime.of(19, 0), com.licenta.backend.entity.ScheduleType.ATTRACTION, "Attraction #3 (evening)")
            );
            default -> throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "travelPace is required");
        }


        java.time.LocalDate day = trip.getStartDate();
        while (!day.isAfter(trip.getEndDate())) {

            int sort = 1;
            for (Slot s : slots) {


                validateNoTimeOverlap(tripId, day, s.start(), s.end(), null);

                ScheduleItem item = new ScheduleItem();
                item.setTrip(trip);
                item.setDay(day);
                item.setStartTime(s.start());
                item.setEndTime(s.end());
                item.setType(s.type());
                item.setTitle(s.title());
                item.setSortOrder(sort++);
                item.setStatus(com.licenta.backend.entity.ScheduleItemStatus.SLOT);

                scheduleItemRepository.save(item);
            }

            day = day.plusDays(1);
        }

        invalidateRouteCacheForTrip(tripId);


        return getScheduleByDay(tripId);
    }




    @Transactional
    public void clearSchedule(Long tripId) {

        requireOwnedTrip(tripId);

        scheduleItemRepository.deleteByTripId(tripId);

        invalidateRouteCacheForTrip(tripId);
    }



    private String currentUserEmail() {
        var auth = org.springframework.security.core.context.SecurityContextHolder
                .getContext()
                .getAuthentication();

        if (auth == null || auth.getPrincipal() == null) {
            throw new ResponseStatusException(HttpStatus.UNAUTHORIZED, "Not authenticated");
        }

        return auth.getPrincipal().toString(); // la tine principal = email
    }


    private Trip requireOwnedTrip(Long tripId) {
        String email = currentUserEmail();
        return tripRepository.findByIdAndOwnerEmail(tripId, email)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Trip not found: " + tripId));
    }



    @Transactional
    public List<ScheduleDayResponse> planTrip(Long tripId, TripPlanRequest req) {

        Trip trip = requireOwnedTrip(tripId);

        if (trip.getStartDate() == null || trip.getEndDate() == null) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Trip must have startDate and endDate");
        }

        PlanningMode mode = req.getMode() == null ? PlanningMode.SUGGESTED : req.getMode();
        boolean clearExisting = req.getClearExisting() == null || req.getClearExisting();


        planningOrchestrator.validateAccommodationIfNeeded(trip, mode);


        if (mode == PlanningMode.SUGGESTED) {
            planningOrchestrator.generateSuggestedPlan(trip, clearExisting);
        } else {

            throw new ResponseStatusException(HttpStatus.BAD_REQUEST,
                    "Use /trips/{id}/schedule/generate for SLOT mode.");
        }

        invalidateRouteCacheForTrip(tripId);

        return getScheduleByDay(tripId);
    }



    public ScheduleDayRouteResponse getRoutePlanForDay(Long tripId, LocalDate day, String modeRaw) {
        Trip trip = requireOwnedTrip(tripId);

        TravelMode mode;
        try {
            mode = TravelMode.valueOf(modeRaw.toUpperCase());
        } catch (Exception e) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Invalid mode. Use WALKING or DRIVING.");
        }

        ScheduleDayRouteResponse cached = getCachedRoutePlan(tripId, day, mode);
        if (cached != null) {
            return cached;
        }

        List<ScheduleItem> items = scheduleItemRepository.findByTripIdAndDayOrderBySortOrderAsc(tripId, day);

        List<ScheduleItem> attractions = items.stream()
                .filter(i -> i.getType() == com.licenta.backend.entity.ScheduleType.ATTRACTION)
                .filter(i -> i.getLat() != null && i.getLng() != null)
                .toList();

        List<RouteSegmentResponse> segments = new ArrayList<>();

        if (trip.getAccommodationLat() != null
                && trip.getAccommodationLng() != null
                && !attractions.isEmpty()) {

            segments.add(buildSingleModeSegment(
                    "Accommodation",
                    trip.getAccommodationLat(),
                    trip.getAccommodationLng(),
                    attractions.get(0).getTitle(),
                    attractions.get(0).getLat(),
                    attractions.get(0).getLng(),
                    mode
            ));

            for (int i = 0; i < attractions.size() - 1; i++) {
                ScheduleItem from = attractions.get(i);
                ScheduleItem to = attractions.get(i + 1);

                segments.add(buildSingleModeSegment(
                        from.getTitle(),
                        from.getLat(),
                        from.getLng(),
                        to.getTitle(),
                        to.getLat(),
                        to.getLng(),
                        mode
                ));
            }

            ScheduleItem last = attractions.get(attractions.size() - 1);
            segments.add(buildSingleModeSegment(
                    last.getTitle(),
                    last.getLat(),
                    last.getLng(),
                    "Accommodation",
                    trip.getAccommodationLat(),
                    trip.getAccommodationLng(),
                    mode
            ));
        }

        ScheduleDayRouteResponse response = new ScheduleDayRouteResponse(day, segments);
        putRouteCache(tripId, day, mode, response);

        return response;
    }

    private RouteSegmentResponse buildSingleModeSegment(
            String fromTitle,
            Double fromLat,
            Double fromLng,
            String toTitle,
            Double toLat,
            Double toLng,
            TravelMode mode
    ) {
        var route = distanceAgent.getRouteInfo(fromLat, fromLng, toLat, toLng, mode);

        return new RouteSegmentResponse(
                fromTitle,
                fromLat,
                fromLng,
                toTitle,
                toLat,
                toLng,
                mode == TravelMode.WALKING ? route : null,
                mode == TravelMode.DRIVING ? route : null
        );
    }

    private record RouteCacheEntry(
            ScheduleDayRouteResponse response,
            long expiresAtMillis
    ) {
        boolean isExpired() {
            return System.currentTimeMillis() > expiresAtMillis;
        }
    }



    private String buildRouteCacheKey(Long tripId, LocalDate day, TravelMode mode) {
        return tripId + "|" + day + "|" + mode.name();
    }


    private ScheduleDayRouteResponse getCachedRoutePlan(Long tripId, LocalDate day, TravelMode mode) {
        String key = buildRouteCacheKey(tripId, day, mode);
        RouteCacheEntry cached = routePlanCache.get(key);

        if (cached == null) {
            return null;
        }

        if (cached.isExpired()) {
            routePlanCache.remove(key);
            return null;
        }

        System.out.println("=== ROUTE CACHE ===");
        System.out.println("Cache HIT for tripId=" + tripId + " day=" + day + " mode=" + mode);

        return cached.response();
    }

    private void putRouteCache(Long tripId, LocalDate day, TravelMode mode, ScheduleDayRouteResponse response) {
        String key = buildRouteCacheKey(tripId, day, mode);

        routePlanCache.put(
                key,
                new RouteCacheEntry(
                        response,
                        System.currentTimeMillis() + ROUTE_CACHE_TTL_MILLIS
                )
        );

        System.out.println("=== ROUTE CACHE ===");
        System.out.println("Cache PUT for tripId=" + tripId + " day=" + day + " mode=" + mode);
    }

    private void invalidateRouteCacheForTrip(Long tripId) {
        String prefix = tripId + "|";
        routePlanCache.keySet().removeIf(key -> key.startsWith(prefix));

        System.out.println("=== ROUTE CACHE ===");
        System.out.println("Invalidated route cache for tripId=" + tripId);
    }
}