package com.licenta.backend.service.ai;

public record RouteTestRequest(
        double fromLat,
        double fromLng,
        double toLat,
        double toLng,
        TravelMode mode
) {}