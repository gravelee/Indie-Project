package com.echoesofthevoid.backend.model;

import jakarta.persistence.*;
import jakarta.validation.constraints.*;
import lombok.*;

@Entity
@Table(name = "character_resources")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class CharacterResources {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @OneToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "save_id", nullable = false)
    private PlayerSave playerSave;

    @Builder.Default @Min(0) @Column(nullable = false) private int currentHp = 100;
    @Builder.Default @Min(0) @Column(nullable = false) private int maxHp = 100;

    @Builder.Default @Min(0) @Max(100) @Column(nullable = false) private int energy = 100;
    @Builder.Default @Min(0) @Max(100) @Column(nullable = false) private int flow = 100;
    @Builder.Default @Min(0) @Max(100) @Column(nullable = false) private int focus = 0;
}
