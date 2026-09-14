package com.echoesofthevoid.backend.service;

import com.echoesofthevoid.backend.dto.PlayerSaveDTO;
import com.echoesofthevoid.backend.model.PlayerSave;
import com.echoesofthevoid.backend.repository.PlayerSaveRepository;
import jakarta.persistence.EntityNotFoundException;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class PlayerSaveServiceTest {

    @Mock
    private PlayerSaveRepository saveRepository;

    @InjectMocks
    private PlayerSaveService saveService;

    @Test
    void createSave_returnsDTOWithCorrectFields() {
        PlayerSaveDTO dto = PlayerSaveDTO.builder()
                .playerName("Ares")
                .currentZone("ZONE_1_DEEP_FOREST")
                .checkpointId("VINEMORE_ENTRANCE")
                .build();

        PlayerSave saved = PlayerSave.builder()
                .playerName("Ares")
                .currentZone("ZONE_1_DEEP_FOREST")
                .checkpointId("VINEMORE_ENTRANCE")
                .build();

        when(saveRepository.save(any(PlayerSave.class))).thenReturn(saved);

        PlayerSaveDTO result = saveService.createSave(dto);

        assertThat(result.getPlayerName()).isEqualTo("Ares");
        assertThat(result.getCurrentZone()).isEqualTo("ZONE_1_DEEP_FOREST");
        assertThat(result.getCheckpointId()).isEqualTo("VINEMORE_ENTRANCE");
    }

    @Test
    void getSave_throwsEntityNotFoundException_whenSaveDoesNotExist() {
        when(saveRepository.findById(99L)).thenReturn(Optional.empty());

        assertThatThrownBy(() -> saveService.getSave(99L))
                .isInstanceOf(EntityNotFoundException.class)
                .hasMessageContaining("99");
    }

    @Test
    void updateCheckpoint_updatesZoneAndCheckpoint() {
        PlayerSave existing = PlayerSave.builder()
                .playerName("Ares")
                .currentZone("ZONE_1_DEEP_FOREST")
                .checkpointId("VINEMORE_ENTRANCE")
                .build();

        PlayerSaveDTO update = PlayerSaveDTO.builder()
                .playerName("Ares")
                .currentZone("ZONE_1_DEEP_FOREST")
                .checkpointId("OLD_MINE_ENTRANCE")
                .build();

        when(saveRepository.findById(1L)).thenReturn(Optional.of(existing));
        when(saveRepository.save(any(PlayerSave.class))).thenAnswer(i -> i.getArgument(0));

        PlayerSaveDTO result = saveService.updateCheckpoint(1L, update);

        assertThat(result.getCheckpointId()).isEqualTo("OLD_MINE_ENTRANCE");
    }
}
