package com.echoesofthevoid.backend.model;

import com.echoesofthevoid.backend.enums.ItemRarity;
import com.echoesofthevoid.backend.enums.ItemType;
import jakarta.persistence.*;
import jakarta.validation.constraints.*;
import lombok.*;

@Entity
@Table(name = "items")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class Item {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @NotBlank
    @Column(nullable = false)
    private String name;

    @NotNull
    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private ItemType type;

    @NotNull
    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private ItemRarity rarity;

    @Builder.Default @Min(0) @Max(100)
    @Column(nullable = false)
    private int durability = 100;
}
