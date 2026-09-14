package com.echoesofthevoid.backend.model;

import jakarta.persistence.*;
import jakarta.validation.constraints.*;
import lombok.*;

@Entity
@Table(name = "character_stats")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class CharacterStats {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @OneToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "save_id", nullable = false)
    private PlayerSave playerSave;

    @Builder.Default @Min(1) @Max(30)
    @Column(nullable = false)
    private int level = 1;

    @Builder.Default @Min(0)
    @Column(nullable = false)
    private int exp = 0;

    @Builder.Default @Min(0)
    @Column(nullable = false)
    private int gold = 0;

    // Core investable stats
    @Builder.Default @Min(1) @Column(nullable = false) private int str = 1;
    @Builder.Default @Min(1) @Column(nullable = false) private int agi = 1;
    @Builder.Default @Min(1) @Column(nullable = false) private int sta = 1;
    @Builder.Default @Min(1) @Column(nullable = false) private int intel = 1;  // int is reserved keyword
    @Builder.Default @Min(1) @Column(nullable = false) private int spr = 1;
    @Builder.Default @Min(1) @Column(nullable = false) private int res = 1;
    @Builder.Default @Min(1) @Column(nullable = false) private int def = 1;

    @Builder.Default @Min(0)
    @Column(nullable = false)
    private int unspentTalentPoints = 0;
}
