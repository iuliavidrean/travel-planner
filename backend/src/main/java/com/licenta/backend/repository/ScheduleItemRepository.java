package com.licenta.backend.repository;

import com.licenta.backend.entity.ScheduleItem;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;

import java.time.LocalDate;
import java.time.LocalTime;
import java.util.List;
import java.util.Optional;

public interface ScheduleItemRepository extends JpaRepository<ScheduleItem, Long> {

    @Modifying
    void deleteByTripId(Long tripId);

    boolean existsByTripId(Long tripId);

    List<ScheduleItem> findByTripIdOrderByDayAscSortOrderAsc(Long tripId);


    List<ScheduleItem> findByTripIdAndDay(Long tripId, LocalDate day);


    List<ScheduleItem> findByTripIdAndDayOrderByStartTimeAsc(Long tripId, LocalDate day);

    List<ScheduleItem> findByTripIdAndDayOrderBySortOrderAsc(Long tripId, LocalDate day);

    Optional<ScheduleItem> findTopByTripIdAndDayOrderBySortOrderDesc(Long tripId, LocalDate day);

    Optional<ScheduleItem> findByIdAndTripId(Long id, Long tripId);
}