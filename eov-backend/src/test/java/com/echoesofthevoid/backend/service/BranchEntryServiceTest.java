package com.echoesofthevoid.backend.service;

import com.echoesofthevoid.backend.dto.BranchEntryDTO;
import com.echoesofthevoid.backend.model.BranchEntry;
import com.echoesofthevoid.backend.model.PlayerSave;
import com.echoesofthevoid.backend.repository.BranchEntryRepository;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.util.List;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class BranchEntryServiceTest {

    @Mock private BranchEntryRepository branchRepository;
    @Mock private PlayerSaveService saveService;

    @InjectMocks
    private BranchEntryService branchService;

    // Branch forks are irreversible by design (game_overview.md Pillar 3).
    // Recording the same branch twice must be rejected.
    @Test
    void recordBranch_throwsIllegalStateException_whenBranchAlreadyRecorded() {
        PlayerSave save = PlayerSave.builder()
                .playerName("Ares")
                .currentZone("ZONE_1_DEEP_FOREST")
                .checkpointId("VINEMORE_ENTRANCE")
                .build();

        BranchEntryDTO dto = BranchEntryDTO.builder()
                .branchId("B-01")
                .decision("ACCEPTED_RING")
                .build();

        when(saveService.findOrThrow(1L)).thenReturn(save);
        when(branchRepository.existsByPlayerSaveIdAndBranchId(1L, "B-01")).thenReturn(true);

        assertThatThrownBy(() -> branchService.recordBranch(1L, dto))
                .isInstanceOf(IllegalStateException.class)
                .hasMessageContaining("B-01")
                .hasMessageContaining("irreversible");
    }

    @Test
    void recordBranch_savesAndReturnsBranchEntry_whenNew() {
        PlayerSave save = PlayerSave.builder()
                .playerName("Ares")
                .currentZone("ZONE_1_DEEP_FOREST")
                .checkpointId("VINEMORE_ENTRANCE")
                .build();

        BranchEntryDTO dto = BranchEntryDTO.builder()
                .branchId("B-02")
                .decision("HELPED_BRIDGE")
                .build();

        BranchEntry saved = BranchEntry.builder()
                .playerSave(save)
                .branchId("B-02")
                .decision("HELPED_BRIDGE")
                .build();

        when(saveService.findOrThrow(1L)).thenReturn(save);
        when(branchRepository.existsByPlayerSaveIdAndBranchId(1L, "B-02")).thenReturn(false);
        when(branchRepository.save(any(BranchEntry.class))).thenReturn(saved);

        BranchEntryDTO result = branchService.recordBranch(1L, dto);

        assertThat(result.getBranchId()).isEqualTo("B-02");
        assertThat(result.getDecision()).isEqualTo("HELPED_BRIDGE");
    }

    @Test
    void getBranches_returnsAllBranchesForSave() {
        PlayerSave save = PlayerSave.builder()
                .playerName("Ares")
                .currentZone("ZONE_1_DEEP_FOREST")
                .checkpointId("VINEMORE_ENTRANCE")
                .build();

        List<BranchEntry> entries = List.of(
                BranchEntry.builder().playerSave(save).branchId("B-01").decision("ACCEPTED_RING").build(),
                BranchEntry.builder().playerSave(save).branchId("B-02").decision("HELPED_BRIDGE").build()
        );

        when(saveService.findOrThrow(1L)).thenReturn(save);
        when(branchRepository.findByPlayerSaveId(1L)).thenReturn(entries);

        List<BranchEntryDTO> result = branchService.getBranches(1L);

        assertThat(result).hasSize(2);
        assertThat(result.get(0).getBranchId()).isEqualTo("B-01");
        assertThat(result.get(1).getBranchId()).isEqualTo("B-02");
    }
}
