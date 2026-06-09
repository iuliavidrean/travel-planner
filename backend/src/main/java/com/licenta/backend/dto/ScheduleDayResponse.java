package com.licenta.backend.dto;

import java.time.LocalDate;
import java.util.List;


public class ScheduleDayResponse {

    public LocalDate day;
    public List<ScheduleItemResponse> items;

    public ScheduleDayResponse(LocalDate day, List<ScheduleItemResponse> items) {
        this.day = day;
        this.items = items;
    }
}