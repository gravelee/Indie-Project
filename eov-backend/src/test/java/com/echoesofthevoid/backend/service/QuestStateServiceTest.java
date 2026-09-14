package com.echoesofthevoid.backend.service;

import com.echoesofthevoid.backend.dto.QuestStateDTO;
import com.echoesofthevoid.backend.enums.QuestStatus;
import com.echoesofthevoid.backend.model.PlayerSave;
import com.echoesofthevoid.backend.model.QuestState;
import com.echoesofthevoid.backend.repository.QuestStateRepository;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.util.List;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class QuestStateServiceTest {

    @Mock private QuestStateRepository questRepository;
    @Mock private PlayerSaveService saveService;

    @InjectMocks
    private QuestStateService questService;

    @Test
    void upsertQuest_createsNewEntry_whenQuestDoesNotExist() {
        PlayerSave save = PlayerSave.builder()
                .playerName("Ares")
                .currentZone("ZONE_1_DEEP_FOREST")
                .checkpointId("VINEMORE_ENTRANCE")
                .build();

        QuestStateDTO dto = QuestStateDTO.builder()
                .questId("ZONE1_MAIN_01")
                .status(QuestStatus.IN_PROGRESS)
                .build();

        QuestState created = QuestState.builder()
                .playerSave(save)
                .questId("ZONE1_MAIN_01")
                .status(QuestStatus.IN_PROGRESS)
                .build();

        when(saveService.findOrThrow(1L)).thenReturn(save);
        when(questRepository.findByPlayerSaveIdAndQuestId(1L, "ZONE1_MAIN_01"))
                .thenReturn(Optional.empty());
        when(questRepository.save(any(QuestState.class))).thenReturn(created);

        QuestStateDTO result = questService.upsertQuest(1L, dto);

        assertThat(result.getQuestId()).isEqualTo("ZONE1_MAIN_01");
        assertThat(result.getStatus()).isEqualTo(QuestStatus.IN_PROGRESS);
    }

    @Test
    void upsertQuest_updatesStatus_whenQuestAlreadyExists() {
        PlayerSave save = PlayerSave.builder()
                .playerName("Ares")
                .currentZone("ZONE_1_DEEP_FOREST")
                .checkpointId("VINEMORE_ENTRANCE")
                .build();

        QuestState existing = QuestState.builder()
                .playerSave(save)
                .questId("ZONE1_MAIN_01")
                .status(QuestStatus.IN_PROGRESS)
                .build();

        QuestStateDTO dto = QuestStateDTO.builder()
                .questId("ZONE1_MAIN_01")
                .status(QuestStatus.COMPLETED)
                .build();

        when(saveService.findOrThrow(1L)).thenReturn(save);
        when(questRepository.findByPlayerSaveIdAndQuestId(1L, "ZONE1_MAIN_01"))
                .thenReturn(Optional.of(existing));
        when(questRepository.save(any(QuestState.class))).thenAnswer(i -> i.getArgument(0));

        QuestStateDTO result = questService.upsertQuest(1L, dto);

        assertThat(result.getStatus()).isEqualTo(QuestStatus.COMPLETED);
    }

    @Test
    void getQuestsByStatus_returnsOnlyMatchingQuests() {
        PlayerSave save = PlayerSave.builder()
                .playerName("Ares")
                .currentZone("ZONE_1_DEEP_FOREST")
                .checkpointId("VINEMORE_ENTRANCE")
                .build();

        List<QuestState> completed = List.of(
                QuestState.builder().playerSave(save)
                        .questId("ZONE1_MAIN_01").status(QuestStatus.COMPLETED).build()
        );

        when(saveService.findOrThrow(1L)).thenReturn(save);
        when(questRepository.findByPlayerSaveIdAndStatus(1L, QuestStatus.COMPLETED))
                .thenReturn(completed);

        List<QuestStateDTO> result = questService.getQuestsByStatus(1L, QuestStatus.COMPLETED);

        assertThat(result).hasSize(1);
        assertThat(result.get(0).getStatus()).isEqualTo(QuestStatus.COMPLETED);
    }
}
