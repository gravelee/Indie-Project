package com.echoesofthevoid.backend.model;

import com.echoesofthevoid.backend.enums.ItemType;
import jakarta.persistence.*;
import jakarta.validation.constraints.*;
import lombok.*;

@Entity
@Table(name = "inventory_items")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class InventoryItem {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "save_id", nullable = false)
    private PlayerSave playerSave;

    @ManyToOne(fetch = FetchType.EAGER)
    @JoinColumn(name = "item_id", nullable = false)
    private Item item;

    // Which pouch this lives in: AMMO, FOOD, or MISC (maps to ItemType)
    @NotNull
    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private ItemType pouch;

    @Builder.Default @Min(1)
    @Column(nullable = false)
    private int quantity = 1;
}
