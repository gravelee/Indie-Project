package com.echoesofthevoid.backend.model;

import com.echoesofthevoid.backend.enums.QuestStatus;
import jakarta.persistence.*;
import jakarta.validation.constraints.*;
import lombok.*;

@Entity
@Table(name = "quest_states")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class QuestState {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "save_id", nullable = false)
    private PlayerSave playerSave;

    @NotBlank
    @Column(nullable = false)
    private String questId;  // e.g. "ZONE1_MAIN_01", "ZONE1_SIDE_HERBALIST"

    @Builder.Default @NotNull
    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private QuestStatus status = QuestStatus.NOT_STARTED;
}
