package com.licenta.backend.service.ai;

import java.util.List;

public record RouteInfo(
        double distanceKm,
        int durationMinutes,
        String mode,
        boolean fallbackUsed,
        List<List<Double>> geometry
) {}