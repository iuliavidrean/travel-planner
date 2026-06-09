package com.licenta.backend.dto;

import com.licenta.backend.entity.PreferenceTag;
import com.licenta.backend.entity.TravelPace;

import jakarta.validation.constraints.*;
import java.time.LocalDate;
import java.util.Set;

public class TripCreateRequest {

    @NotBlank
    private String country;

    @NotBlank
    private String city;

    @NotNull
    private LocalDate startDate;

    @NotNull
    private LocalDate endDate;

    private String accommodationAddress;
    private Double accommodationLat;
    private Double accommodationLng;

    @NotNull
    private TravelPace travelPace;

    private Set<PreferenceTag> preferences;

    public String getCountry() { return country; }
    public void setCountry(String country) { this.country = country; }

    public String getCity() { return city; }
    public void setCity(String city) { this.city = city; }

    public LocalDate getStartDate() { return startDate; }
    public void setStartDate(LocalDate startDate) { this.startDate = startDate; }

    public LocalDate getEndDate() { return endDate; }
    public void setEndDate(LocalDate endDate) { this.endDate = endDate; }

    public String getAccommodationAddress() { return accommodationAddress; }
    public void setAccommodationAddress(String accommodationAddress) { this.accommodationAddress = accommodationAddress; }

    public Double getAccommodationLat() { return accommodationLat; }
    public void setAccommodationLat(Double accommodationLat) { this.accommodationLat = accommodationLat; }

    public Double getAccommodationLng() { return accommodationLng; }
    public void setAccommodationLng(Double accommodationLng) { this.accommodationLng = accommodationLng; }

    public TravelPace getTravelPace() { return travelPace; }
    public void setTravelPace(TravelPace travelPace) { this.travelPace = travelPace; }

    public Set<PreferenceTag> getPreferences() { return preferences; }
    public void setPreferences(Set<PreferenceTag> preferences) { this.preferences = preferences; }
}