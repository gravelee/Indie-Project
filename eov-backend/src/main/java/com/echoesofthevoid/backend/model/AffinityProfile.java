package com.echoesofthevoid.backend.model;

import jakarta.persistence.*;
import jakarta.validation.constraints.*;
import lombok.*;

@Entity
@Table(name = "affinity_profiles")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class AffinityProfile {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @OneToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "save_id", nullable = false)
    private PlayerSave playerSave;

    // 0-100 axes. Void axis: 0 = distrust consuming race, 100 = trust.
    @Builder.Default @Min(0) @Max(100) @Column(nullable = false) private int voidAxis = 50;
    @Builder.Default @Min(0) @Max(100) @Column(nullable = false) private int honesty = 50;
    @Builder.Default @Min(0) @Max(100) @Column(nullable = false) private int boldness = 50;
    @Builder.Default @Min(0) @Max(100) @Column(nullable = false) private int curiosity = 50;
    @Builder.Default @Min(0) @Max(100) @Column(nullable = false) private int empathy = 50;
    @Builder.Default @Min(0) @Max(100) @Column(nullable = false) private int resilience = 50;
}
