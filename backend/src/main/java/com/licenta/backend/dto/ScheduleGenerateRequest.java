package com.licenta.backend.dto;

import jakarta.validation.constraints.NotNull;


public class ScheduleGenerateRequest {

    @NotNull
    private Boolean clearExisting;

    public Boolean getClearExisting() { return clearExisting; }
    public void setClearExisting(Boolean clearExisting) { this.clearExisting = clearExisting; }
}