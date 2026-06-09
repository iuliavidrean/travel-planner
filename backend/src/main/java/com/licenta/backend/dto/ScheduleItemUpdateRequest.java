package com.licenta.backend.dto;

import com.licenta.backend.entity.ScheduleType;
import java.time.LocalDate;
import java.time.LocalTime;

public class ScheduleItemUpdateRequest {

    private LocalDate day;
    private LocalTime startTime;
    private LocalTime endTime;
    private ScheduleType type;
    private String title;
    private Double lat;
    private Double lng;
    private String locationAddress;
    private Boolean clearLocation;
    private Integer sortOrder;

    public LocalDate getDay() { return day; }
    public void setDay(LocalDate day) { this.day = day; }

    public LocalTime getStartTime() { return startTime; }
    public void setStartTime(LocalTime startTime) { this.startTime = startTime; }

    public LocalTime getEndTime() { return endTime; }
    public void setEndTime(LocalTime endTime) { this.endTime = endTime; }

    public ScheduleType getType() { return type; }
    public void setType(ScheduleType type) { this.type = type; }

    public String getTitle() { return title; }
    public void setTitle(String title) { this.title = title; }

    public Double getLat() { return lat; }
    public void setLat(Double lat) { this.lat = lat; }

    public Double getLng() { return lng; }
    public void setLng(Double lng) { this.lng = lng; }

    public String getLocationAddress() { return locationAddress; }
    public void setLocationAddress(String locationAddress) { this.locationAddress = locationAddress; }

    public Boolean getClearLocation() { return clearLocation; }
    public void setClearLocation(Boolean clearLocation) { this.clearLocation = clearLocation; }

    public Integer getSortOrder() { return sortOrder; }
    public void setSortOrder(Integer sortOrder) { this.sortOrder = sortOrder; }
}