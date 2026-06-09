package com.licenta.backend.controller;

import com.licenta.backend.service.ai.DistanceAgent;
import com.licenta.backend.service.ai.RouteInfo;
import com.licenta.backend.service.ai.RouteTestRequest;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/debug")
public class AiDebugController {

    private final DistanceAgent distanceAgent;

    public AiDebugController(DistanceAgent distanceAgent) {
        this.distanceAgent = distanceAgent;
    }

    @PostMapping("/route")
    public RouteInfo testRoute(@RequestBody RouteTestRequest request) {
        return distanceAgent.getRouteInfo(
                request.fromLat(),
                request.fromLng(),
                request.toLat(),
                request.toLng(),
                request.mode()
        );
    }
}