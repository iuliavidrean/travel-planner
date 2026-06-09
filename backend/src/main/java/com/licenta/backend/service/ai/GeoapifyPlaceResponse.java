package com.licenta.backend.service.ai;

import com.fasterxml.jackson.annotation.JsonIgnoreProperties;

import java.util.List;

@JsonIgnoreProperties(ignoreUnknown = true)
public record GeoapifyPlaceResponse(
        List<Feature> features
) {

    @JsonIgnoreProperties(ignoreUnknown = true)
    public record Feature(
            Properties properties,
            Geometry geometry
    ) {}

    @JsonIgnoreProperties(ignoreUnknown = true)
    public record Properties(
            String name,
            String formatted,
            List<String> categories
    ) {}

    @JsonIgnoreProperties(ignoreUnknown = true)
    public record Geometry(
            List<Double> coordinates
    ) {}
}