package com.licenta.backend.service.ai;

import com.fasterxml.jackson.annotation.JsonIgnoreProperties;

import java.util.List;

@JsonIgnoreProperties(ignoreUnknown = true)
public record OpenRouteServiceDirectionsResponse(
        List<Feature> features
) {
    @JsonIgnoreProperties(ignoreUnknown = true)
    public record Feature(
            Geometry geometry,
            Properties properties
    ) {}

    @JsonIgnoreProperties(ignoreUnknown = true)
    public record Geometry(
            String type,
            List<List<Double>> coordinates
    ) {}

    @JsonIgnoreProperties(ignoreUnknown = true)
    public record Properties(
            Summary summary
    ) {}

    @JsonIgnoreProperties(ignoreUnknown = true)
    public record Summary(
            double distance,
            double duration
    ) {}
}