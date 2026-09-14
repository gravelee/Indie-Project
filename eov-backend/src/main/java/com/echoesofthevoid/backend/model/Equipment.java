package com.echoesofthevoid.backend.model;

import jakarta.persistence.*;
import lombok.*;

@Entity
@Table(name = "equipment")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class Equipment {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @OneToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "save_id", nullable = false)
    private PlayerSave playerSave;

    // Weapon slots
    @ManyToOne(fetch = FetchType.EAGER)
    @JoinColumn(name = "main_hand_id")
    private Item mainHand;

    @ManyToOne(fetch = FetchType.EAGER)
    @JoinColumn(name = "off_hand_id")
    private Item offHand;

    @ManyToOne(fetch = FetchType.EAGER)
    @JoinColumn(name = "stance_id")
    private Item stance; // shield or staff — mutually exclusive by design

    // Armor slots
    @ManyToOne(fetch = FetchType.EAGER) @JoinColumn(name = "head_id")  private Item head;
    @ManyToOne(fetch = FetchType.EAGER) @JoinColumn(name = "chest_id") private Item chest;
    @ManyToOne(fetch = FetchType.EAGER) @JoinColumn(name = "legs_id")  private Item legs;
    @ManyToOne(fetch = FetchType.EAGER) @JoinColumn(name = "feet_id")  private Item feet;
    @ManyToOne(fetch = FetchType.EAGER) @JoinColumn(name = "hands_id") private Item hands;
    @ManyToOne(fetch = FetchType.EAGER) @JoinColumn(name = "accessory_id") private Item accessory;
}
