package com.echoesofthevoid.backend.model;

import jakarta.persistence.*;
import jakarta.validation.constraints.*;
import lombok.*;
import org.hibernate.annotations.CreationTimestamp;
import org.hibernate.annotations.UpdateTimestamp;

import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;

@Entity
@Table(name = "player_saves")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class PlayerSave {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @NotBlank
    @Column(nullable = false)
    private String playerName;

    @NotBlank
    @Column(nullable = false)
    private String currentZone;

    @NotBlank
    @Column(nullable = false)
    private String checkpointId;  // last activated save point

    @CreationTimestamp
    @Column(updatable = false)
    private LocalDateTime createdAt;

    @UpdateTimestamp
    private LocalDateTime lastSavedAt;

    @OneToOne(mappedBy = "playerSave", cascade = CascadeType.ALL, orphanRemoval = true)
    private CharacterStats stats;

    @OneToOne(mappedBy = "playerSave", cascade = CascadeType.ALL, orphanRemoval = true)
    private CharacterResources resources;

    @OneToOne(mappedBy = "playerSave", cascade = CascadeType.ALL, orphanRemoval = true)
    private AffinityProfile affinity;

    @OneToOne(mappedBy = "playerSave", cascade = CascadeType.ALL, orphanRemoval = true)
    private Equipment equipment;

    @Builder.Default
    @OneToMany(mappedBy = "playerSave", cascade = CascadeType.ALL, orphanRemoval = true)
    private List<QuestState> quests = new ArrayList<>();

    @Builder.Default
    @OneToMany(mappedBy = "playerSave", cascade = CascadeType.ALL, orphanRemoval = true)
    private List<BranchEntry> branches = new ArrayList<>();

    @Builder.Default
    @OneToMany(mappedBy = "playerSave", cascade = CascadeType.ALL, orphanRemoval = true)
    private List<InventoryItem> inventory = new ArrayList<>();
}
