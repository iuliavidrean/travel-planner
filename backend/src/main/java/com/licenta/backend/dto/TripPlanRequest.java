package com.licenta.backend.dto;

import jakarta.validation.constraints.NotNull;

public class TripPlanRequest {

    @NotNull
    private PlanningMode mode = PlanningMode.SUGGESTED;

    private Boolean clearExisting = true;



    public PlanningMode getMode() {
        return mode;
    }

    public void setMode(PlanningMode mode) {
        this.mode = mode;
    }

    public Boolean getClearExisting() {
        return clearExisting;
    }

    public void setClearExisting(Boolean clearExisting) {
        this.clearExisting = clearExisting;
    }
}