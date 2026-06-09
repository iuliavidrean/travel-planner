package com.licenta.backend.dto;

import com.licenta.backend.entity.ScheduleType;
import com.licenta.backend.entity.ScheduleItemStatus;

import java.time.LocalDate;
import java.time.LocalTime;


public class ScheduleItemResponse {
    public Long id;
    public LocalDate day;
    public LocalTime startTime;
    public LocalTime endTime;
    public ScheduleType type;
    public String title;
    public Double lat;
    public Double lng;
    public String locationAddress;
    public Integer sortOrder;

    public ScheduleItemStatus status;
}