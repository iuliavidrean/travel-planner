package com.licenta.backend.service.ai;

import com.licenta.backend.entity.PreferenceTag;
import com.licenta.backend.entity.ScheduleType;

import java.util.Set;


public record Poi(
        String title,
        double lat,
        double lng,
        String locationAddress,
        ScheduleType type,
        Set<PreferenceTag> tags
) {}