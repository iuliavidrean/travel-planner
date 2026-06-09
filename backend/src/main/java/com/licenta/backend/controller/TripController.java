package com.licenta.backend.controller;

import com.licenta.backend.dto.TripCreateRequest;
import com.licenta.backend.dto.TripResponse;
import com.licenta.backend.dto.TripUpdateRequest;
import com.licenta.backend.dto.ScheduleItemCreateRequest;
import com.licenta.backend.dto.ScheduleItemUpdateRequest;
import com.licenta.backend.dto.ScheduleItemResponse;
import com.licenta.backend.dto.ScheduleReorderRequest;
import com.licenta.backend.dto.ScheduleDayResponse;
import com.licenta.backend.dto.TripPlanRequest;
import com.licenta.backend.dto.ScheduleDayRouteResponse;
import java.time.LocalDate;
import com.licenta.backend.service.TripService;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.*;
import com.licenta.backend.service.PdfExportService;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import jakarta.validation.Valid;

import java.util.List;

@RestController
@RequestMapping("/trips")
public class TripController {

    private final TripService tripService;
    private final PdfExportService pdfExportService;

    public TripController(TripService tripService, PdfExportService pdfExportService) {
        this.tripService = tripService;
        this.pdfExportService = pdfExportService;
    }

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public TripResponse create(@Valid @RequestBody TripCreateRequest req) {
        return tripService.createTrip(req);
    }

    @GetMapping("/{id}")
    public TripResponse getById(@PathVariable Long id) {
        return tripService.getTrip(id);
    }


    @DeleteMapping("/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void delete(@PathVariable Long id) {
        tripService.deleteTrip(id);
    }

    @GetMapping
    public List<TripResponse> list() {
        return tripService.listTrips();
    }



    // PATCH /trips/{id}
    @PatchMapping("/{id}")
    public TripResponse update(@PathVariable Long id, @RequestBody TripUpdateRequest req) {
        return tripService.updateTrip(id, req);
    }


    // GET /trips/{id}/schedule
    @GetMapping("/{id}/schedule")
    public List<ScheduleItemResponse> getSchedule(@PathVariable Long id) {
        return tripService.getSchedule(id);
    }


    // POST /trips/{id}/schedule
    @PostMapping("/{id}/schedule")
    @ResponseStatus(HttpStatus.CREATED)
    public ScheduleItemResponse addScheduleItem(@PathVariable Long id, @Valid @RequestBody ScheduleItemCreateRequest req) {
        return tripService.addScheduleItem(id, req);
    }


    // PATCH /trips/{id}/schedule/{itemId}
    @PatchMapping("/{tripId}/schedule/{itemId}")
    public ScheduleItemResponse updateScheduleItem(@PathVariable Long tripId,
                                                   @PathVariable Long itemId,
                                                   @RequestBody ScheduleItemUpdateRequest req) {
        return tripService.updateScheduleItem(tripId, itemId, req);
    }


    // DELETE /trips/{tripId}/schedule/{itemId}
    @DeleteMapping("/{tripId}/schedule/{itemId}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void deleteScheduleItem(@PathVariable Long tripId, @PathVariable Long itemId) {
        tripService.deleteScheduleItem(tripId, itemId);
    }



    // PUT /trips/{tripId}/schedule/reorder
    @PutMapping("/{tripId}/schedule/reorder")
    public List<ScheduleItemResponse> reorderSchedule(@PathVariable Long tripId,
                                                      @Valid @RequestBody ScheduleReorderRequest req) {
        return tripService.reorderSchedule(tripId, req);
    }



    // GET /trips/{id}/schedule/by-day
    @GetMapping("/{id}/schedule/by-day")
    public List<ScheduleDayResponse> getScheduleByDay(@PathVariable Long id) {
        return tripService.getScheduleByDay(id);
    }



    // POST /trips/{id}/schedule/generate
    @PostMapping("/{tripId}/schedule/generate")
    public List<com.licenta.backend.dto.ScheduleDayResponse> generate(
            @PathVariable Long tripId,
            @Valid @RequestBody com.licenta.backend.dto.ScheduleGenerateRequest req
    ) {
        return tripService.generateSchedule(tripId, req.getClearExisting());
    }



    // DELETE /trips/{id}/schedule
    @DeleteMapping("/{tripId}/schedule")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void clearSchedule(@PathVariable Long tripId) {
        tripService.clearSchedule(tripId);
    }


    // POST /trips/{tripId}/plan
    @PostMapping("/{tripId}/plan")
    public List<ScheduleDayResponse> planTrip(
            @PathVariable Long tripId,
            @Valid @RequestBody TripPlanRequest req
    ) {
        return tripService.planTrip(tripId, req);
    }


    @GetMapping("/{tripId}/export/pdf")
    public ResponseEntity<byte[]> exportPdf(@PathVariable Long tripId) {
        TripResponse trip = tripService.getTrip(tripId);
        byte[] pdfBytes = pdfExportService.exportTripPdf(tripId);

        String city = trip.city != null
                ? trip.city.trim().replaceAll("\\s+", "_")
                : "trip";

        String fileName = city + "_itinerary.pdf";

        return ResponseEntity.ok()
                .header(HttpHeaders.CONTENT_DISPOSITION, "attachment; filename=\"" + fileName + "\"")
                .contentType(MediaType.APPLICATION_PDF)
                .body(pdfBytes);
    }



    @GetMapping("/{id}/route-plan/day")
    public ScheduleDayRouteResponse getRoutePlanForDay(
            @PathVariable Long id,
            @RequestParam LocalDate day,
            @RequestParam String mode
    ) {
        return tripService.getRoutePlanForDay(id, day, mode);
    }


}