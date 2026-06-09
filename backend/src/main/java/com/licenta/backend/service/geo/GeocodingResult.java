package com.licenta.backend.service.geo;

public record GeocodingResult(
        Double lat,
        Double lng,
        String displayName
) {}