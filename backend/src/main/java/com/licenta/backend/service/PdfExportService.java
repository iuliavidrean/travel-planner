package com.licenta.backend.service;

import com.licenta.backend.dto.ScheduleDayResponse;
import com.licenta.backend.dto.ScheduleItemResponse;
import com.licenta.backend.dto.TripResponse;
import com.lowagie.text.Chunk;
import com.lowagie.text.Document;
import com.lowagie.text.DocumentException;
import com.lowagie.text.Font;
import com.lowagie.text.FontFactory;
import com.lowagie.text.Paragraph;
import com.lowagie.text.Rectangle;
import com.lowagie.text.pdf.PdfPCell;
import com.lowagie.text.pdf.PdfPTable;
import com.lowagie.text.pdf.PdfWriter;
import org.springframework.stereotype.Service;

import java.io.ByteArrayOutputStream;
import java.time.LocalDate;
import java.time.LocalTime;
import java.time.format.DateTimeFormatter;
import java.time.temporal.ChronoUnit;
import java.util.List;

@Service
public class PdfExportService {

    private final TripService tripService;

    public PdfExportService(TripService tripService) {
        this.tripService = tripService;
    }

    public byte[] exportTripPdf(Long tripId) {
        TripResponse trip = tripService.getTrip(tripId);
        List<ScheduleDayResponse> days = tripService.getScheduleByDay(tripId);

        try (ByteArrayOutputStream out = new ByteArrayOutputStream()) {
            Document document = new Document();
            PdfWriter.getInstance(document, out);

            document.open();


            Font titleFont = FontFactory.getFont(FontFactory.HELVETICA_BOLD, 22);
            Font subtitleFont = FontFactory.getFont(FontFactory.HELVETICA, 12);
            Font sectionFont = FontFactory.getFont(FontFactory.HELVETICA_BOLD, 15);
            Font itemTimeFont = FontFactory.getFont(FontFactory.HELVETICA_BOLD, 11);
            Font itemTitleFont = FontFactory.getFont(FontFactory.HELVETICA_BOLD, 12);
            Font normalFont = FontFactory.getFont(FontFactory.HELVETICA, 11);
            Font smallFont = FontFactory.getFont(FontFactory.HELVETICA, 10);
            Font footerFont = FontFactory.getFont(FontFactory.HELVETICA_OBLIQUE, 9);


            java.awt.Color darkText = new java.awt.Color(47, 47, 47);
            java.awt.Color secondaryText = new java.awt.Color(111, 111, 111);
            java.awt.Color mintSoft = new java.awt.Color(223, 245, 239);
            java.awt.Color lightBorder = new java.awt.Color(232, 236, 231);
            java.awt.Color softBox = new java.awt.Color(249, 250, 248);

            titleFont.setColor(darkText);
            subtitleFont.setColor(secondaryText);
            sectionFont.setColor(darkText);
            itemTimeFont.setColor(darkText);
            itemTitleFont.setColor(darkText);
            normalFont.setColor(darkText);
            smallFont.setColor(secondaryText);
            footerFont.setColor(secondaryText);


            Paragraph title = new Paragraph(safe(trip.city), titleFont);
            title.setSpacingAfter(2f);
            document.add(title);

            Paragraph subtitle = new Paragraph("Personal travel itinerary", subtitleFont);
            subtitle.setSpacingAfter(14f);
            document.add(subtitle);


            PdfPTable summaryTable = new PdfPTable(1);
            summaryTable.setWidthPercentage(100);

            PdfPCell summaryCell = new PdfPCell();
            summaryCell.setPadding(14f);
            summaryCell.setBorderColor(lightBorder);
            summaryCell.setBackgroundColor(softBox);

            summaryCell.addElement(new Paragraph(
                    safe(trip.country) + " · " + formatDateRange(trip.startDate, trip.endDate),
                    normalFont
            ));

            summaryCell.addElement(new Paragraph(
                    "Travel pace: " + formatEnum(trip.travelPace != null ? trip.travelPace.name() : null),
                    normalFont
            ));

            long totalDays = 0;
            if (trip.startDate != null && trip.endDate != null) {
                totalDays = ChronoUnit.DAYS.between(trip.startDate, trip.endDate) + 1;
            }

            int totalActivities = days.stream()
                    .mapToInt(d -> d.items != null ? d.items.size() : 0)
                    .sum();

            summaryCell.addElement(new Paragraph(
                    "Trip length: " + totalDays + " days",
                    normalFont
            ));

            summaryCell.addElement(new Paragraph(
                    "Planned activities: " + totalActivities,
                    normalFont
            ));

            if (trip.accommodationAddress != null && !trip.accommodationAddress.isBlank()) {
                Paragraph accommodation = new Paragraph(
                        "Accommodation: " + trip.accommodationAddress,
                        normalFont
                );
                accommodation.setSpacingBefore(2f);
                summaryCell.addElement(accommodation);
            }

            summaryTable.addCell(summaryCell);
            summaryTable.setSpacingAfter(18f);
            document.add(summaryTable);

            if (days.isEmpty()) {
                Paragraph empty = new Paragraph("No itinerary available yet.", normalFont);
                empty.setSpacingAfter(10f);
                document.add(empty);
            } else {
                int dayNumber = 1;

                for (ScheduleDayResponse day : days) {
                    // header zi
                    PdfPTable dayHeaderTable = new PdfPTable(1);
                    dayHeaderTable.setWidthPercentage(100);

                    PdfPCell dayHeaderCell = new PdfPCell();
                    dayHeaderCell.setPadding(10f);
                    dayHeaderCell.setBorderColor(lightBorder);
                    dayHeaderCell.setBackgroundColor(mintSoft);

                    Paragraph dayHeader = new Paragraph(
                            "Day " + dayNumber + " · " + formatPrettyDate(day.day),
                            sectionFont
                    );
                    dayHeaderCell.addElement(dayHeader);

                    dayHeaderTable.addCell(dayHeaderCell);
                    dayHeaderTable.setSpacingBefore(4f);
                    dayHeaderTable.setSpacingAfter(10f);
                    document.add(dayHeaderTable);

                    if (day.items == null || day.items.isEmpty()) {
                        Paragraph noItems = new Paragraph("No activities planned for this day.", smallFont);
                        noItems.setSpacingAfter(10f);
                        document.add(noItems);
                    } else {
                        for (ScheduleItemResponse item : day.items) {
                            PdfPTable itemTable = new PdfPTable(1);
                            itemTable.setWidthPercentage(100);

                            PdfPCell itemCell = new PdfPCell();
                            itemCell.setPadding(10f);
                            itemCell.setBorderColor(lightBorder);
                            itemCell.setBackgroundColor(Rectangle.NO_BORDER == 0 ? java.awt.Color.WHITE : java.awt.Color.WHITE);

                            Paragraph timeLine = new Paragraph(
                                    formatTime(item.startTime) + " - " + formatTime(item.endTime),
                                    itemTimeFont
                            );
                            timeLine.setSpacingAfter(4f);
                            itemCell.addElement(timeLine);

                            Paragraph itemTitle = new Paragraph(safe(item.title), itemTitleFont);
                            itemTitle.setSpacingAfter(4f);
                            itemCell.addElement(itemTitle);

                            String metaLine =
                                    formatEnum(item.type != null ? item.type.name() : null)
                                            + " · "
                                            + formatEnum(item.status != null ? item.status.name() : null);

                            Paragraph meta = new Paragraph(metaLine, smallFont);
                            meta.setSpacingAfter(3f);
                            itemCell.addElement(meta);

                            if (item.locationAddress != null && !item.locationAddress.isBlank()) {
                                Paragraph location = new Paragraph(
                                        "Location: " + item.locationAddress,
                                        smallFont
                                );
                                itemCell.addElement(location);
                            }

                            itemTable.addCell(itemCell);
                            itemTable.setSpacingAfter(8f);
                            document.add(itemTable);
                        }
                    }

                    dayNumber++;
                }
            }

            Paragraph footerSpacing = new Paragraph(" ");
            footerSpacing.setSpacingBefore(6f);
            document.add(footerSpacing);

            Paragraph footer = new Paragraph("Generated by TerraWise", footerFont);
            footer.setSpacingAfter(2f);
            document.add(footer);

            Paragraph footer2 = new Paragraph("This itinerary can be edited anytime in the app.", footerFont);
            document.add(footer2);

            document.close();
            return out.toByteArray();

        } catch (DocumentException e) {
            throw new RuntimeException("Failed to generate PDF", e);
        } catch (Exception e) {
            throw new RuntimeException("Unexpected error while generating PDF", e);
        }
    }

    private String safe(String value) {
        return value == null || value.isBlank() ? "-" : value;
    }

    private String formatDateRange(LocalDate startDate, LocalDate endDate) {
        if (startDate == null && endDate == null) return "-";
        if (startDate == null) return formatPrettyDate(endDate);
        if (endDate == null) return formatPrettyDate(startDate);

        return formatPrettyDate(startDate) + " - " + formatPrettyDate(endDate);
    }

    private String formatDate(LocalDate date) {
        if (date == null) return "-";
        return date.format(DateTimeFormatter.ISO_DATE);
    }

    private String formatPrettyDate(LocalDate date) {
        if (date == null) return "-";
        return date.format(DateTimeFormatter.ofPattern("dd MMM yyyy"));
    }

    private String formatTime(LocalTime time) {
        if (time == null) return "--:--";
        return time.format(DateTimeFormatter.ofPattern("HH:mm"));
    }

    private String formatEnum(String value) {
        if (value == null || value.isBlank()) return "-";

        String[] parts = value.toLowerCase().split("_");
        StringBuilder result = new StringBuilder();

        for (String part : parts) {
            if (part.isEmpty()) continue;
            result.append(Character.toUpperCase(part.charAt(0)))
                    .append(part.substring(1))
                    .append(" ");
        }

        return result.toString().trim();
    }
}