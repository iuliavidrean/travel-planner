package com.licenta.backend.dto;

import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.NotNull;

import java.time.LocalDate;
import java.util.List;



public class ScheduleReorderRequest {

    @NotNull
    private LocalDate day;

    @NotEmpty
    private List<Long> itemIds;

    public LocalDate getDay() { return day; }
    public void setDay(LocalDate day) { this.day = day; }

    public List<Long> getItemIds() { return itemIds; }
    public void setItemIds(List<Long> itemIds) { this.itemIds = itemIds; }
}