package com.licenta.backend.dto;

import com.licenta.backend.entity.PreferenceTag;
import com.licenta.backend.entity.TravelPace;

import java.time.LocalDate;
import java.util.Set;

public class TripResponse {
    public Long id;

    public String country;
    public String city;
    public LocalDate startDate;
    public LocalDate endDate;

    public String accommodationAddress;
    public Double accommodationLat;
    public Double accommodationLng;

    public TravelPace travelPace;
    public Set<PreferenceTag> preferences;
}
