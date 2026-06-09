package com.licenta.backend.service.ai;

import com.licenta.backend.entity.PreferenceTag;
import org.springframework.stereotype.Component;

import java.util.HashSet;
import java.util.Locale;
import java.util.Set;


@Component
public class PreferenceTagMapper {

    public Set<PreferenceTag> mapFromExternalCategories(Set<String> categories) {
        if (categories == null || categories.isEmpty()) {
            return Set.of();
        }

        Set<PreferenceTag> result = new HashSet<>();

        for (String raw : categories) {
            if (raw == null || raw.isBlank()) {
                continue;
            }

            String value = raw.trim().toLowerCase(Locale.ROOT);

            if (value.contains("museum") || value.contains("gallery")) {
                result.add(PreferenceTag.MUSEUMS);
            }

            if (value.contains("historic") || value.contains("history") || value.contains("monument")) {
                result.add(PreferenceTag.HISTORY);
            }

            if (value.contains("architecture") || value.contains("church") || value.contains("cathedral")) {
                result.add(PreferenceTag.ARCHITECTURE);
            }

            if (value.contains("food") || value.contains("restaurant") || value.contains("market")) {
                result.add(PreferenceTag.FOOD);
            }

            if (value.contains("park") || value.contains("garden") || value.contains("nature")) {
                result.add(PreferenceTag.NATURE);
            }

            if (value.contains("hiking") || value.contains("trail")) {
                result.add(PreferenceTag.HIKING);
            }

            if (value.contains("beach")) {
                result.add(PreferenceTag.BEACH);
            }

            if (value.contains("nightlife") || value.contains("bar") || value.contains("club")) {
                result.add(PreferenceTag.NIGHTLIFE);
            }

            if (value.contains("music") || value.contains("concert")) {
                result.add(PreferenceTag.MUSIC);
            }

            if (value.contains("shopping") || value.contains("mall")) {
                result.add(PreferenceTag.SHOPPING);
            }

            if (value.contains("kids") || value.contains("family") || value.contains("zoo")) {
                result.add(PreferenceTag.KIDS_FRIENDLY);
            }

            if (value.contains("sport") || value.contains("stadium")) {
                result.add(PreferenceTag.SPORTS);
            }
        }

        return result;
    }
}