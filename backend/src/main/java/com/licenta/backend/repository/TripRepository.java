package com.licenta.backend.repository;

import com.licenta.backend.entity.Trip;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.Optional;

public interface TripRepository extends JpaRepository<Trip, Long> {

    List<Trip> findAllByOwnerEmailOrderByStartDateAsc(String email);

    Optional<Trip> findByIdAndOwnerEmail(Long id, String email);
}
