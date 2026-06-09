package com.licenta.backend.service.ai;

import com.fasterxml.jackson.annotation.JsonIgnoreProperties;

import java.util.List;

@JsonIgnoreProperties(ignoreUnknown = true)
public record GeoapifyGeocodeResponse(
        List<Result> results
) {
    @JsonIgnoreProperties(ignoreUnknown = true)
    public record Result(
            String place_id,
            String city,
            String country,
            String formatted,
            Bbox bbox
    ) {}

    @JsonIgnoreProperties(ignoreUnknown = true)
    public record Bbox(
            double lon1,
            double lat1,
            double lon2,
            double lat2
    ) {}
}