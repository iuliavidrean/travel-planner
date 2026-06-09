package com.licenta.backend.entity;
import com.fasterxml.jackson.annotation.JsonIgnore;
import jakarta.persistence.*;
import java.time.LocalDate;
import java.util.HashSet;
import java.util.Set;
import java.util.ArrayList;
import java.util.List;

@Entity
@Table(name = "trips")
public class Trip {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;


    private String country;
    private String city;
    private LocalDate startDate;
    private LocalDate endDate;


    private String accommodationAddress;
    private Double accommodationLat;
    private Double accommodationLng;


    @Enumerated(EnumType.STRING)
    private TravelPace travelPace;

    @ElementCollection(fetch = FetchType.EAGER)
    @CollectionTable(name = "trip_preferences", joinColumns = @JoinColumn(name = "trip_id"))
    @Enumerated(EnumType.STRING)
    @Column(name = "preference")
    private Set<PreferenceTag> preferences = new HashSet<>();

    public Trip() {}

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "owner_id") // momentan fără nullable=false ca să nu te lovești de DB
    @JsonIgnore
    private User owner;


    @OneToMany(
            mappedBy = "trip",
            fetch = FetchType.LAZY,
            cascade = CascadeType.ALL,
            orphanRemoval = true
    )
    private List<ScheduleItem> scheduleItems = new ArrayList<>();

    public List<ScheduleItem> getScheduleItems() { return scheduleItems; }
    public void setScheduleItems(List<ScheduleItem> scheduleItems) { this.scheduleItems = scheduleItems; }




    public Long getId() { return id; }
    public void setId(Long id) { this.id = id; }



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


    public User getOwner() { return owner; }
    public void setOwner(User owner) { this.owner = owner; }
}
