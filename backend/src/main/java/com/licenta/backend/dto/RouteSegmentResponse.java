package com.licenta.backend.dto;

import com.licenta.backend.service.ai.RouteInfo;

public record RouteSegmentResponse(
        String fromTitle,
        Double fromLat,
        Double fromLng,
        String toTitle,
        Double toLat,
        Double toLng,
        RouteInfo walking,
        RouteInfo driving
) {}