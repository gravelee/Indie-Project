package com.echoesofthevoid.backend.model;

import jakarta.persistence.*;
import jakarta.validation.constraints.*;
import lombok.*;

@Entity
@Table(name = "branch_entries")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class BranchEntry {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "save_id", nullable = false)
    private PlayerSave playerSave;

    // e.g. "B-01" through "B-09" — locked narrative forks
    @NotBlank
    @Pattern(regexp = "B-0[1-9]")
    @Column(nullable = false)
    private String branchId;

    // The decision the player made at this fork
    @NotBlank
    @Column(nullable = false)
    private String decision;
}
