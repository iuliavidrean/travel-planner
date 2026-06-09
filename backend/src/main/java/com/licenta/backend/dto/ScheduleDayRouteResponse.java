package com.licenta.backend.dto;

import java.time.LocalDate;
import java.util.List;

public record ScheduleDayRouteResponse(
        LocalDate day,
        List<RouteSegmentResponse> segments
) {}