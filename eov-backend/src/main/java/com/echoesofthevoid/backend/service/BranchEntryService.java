package com.echoesofthevoid.backend.service;

import com.echoesofthevoid.backend.dto.BranchEntryDTO;
import com.echoesofthevoid.backend.model.BranchEntry;
import com.echoesofthevoid.backend.model.PlayerSave;
import com.echoesofthevoid.backend.repository.BranchEntryRepository;
import jakarta.persistence.EntityNotFoundException;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;

@Service
@RequiredArgsConstructor
public class BranchEntryService {

    private final BranchEntryRepository branchRepository;
    private final PlayerSaveService saveService;

    @Transactional(readOnly = true)
    public List<BranchEntryDTO> getBranches(Long saveId) {
        saveService.findOrThrow(saveId);
        return branchRepository.findByPlayerSaveId(saveId).stream()
                .map(this::toDTO)
                .toList();
    }

    @Transactional
    public BranchEntryDTO recordBranch(Long saveId, BranchEntryDTO dto) {
        PlayerSave save = saveService.findOrThrow(saveId);

        if (branchRepository.existsByPlayerSaveIdAndBranchId(saveId, dto.getBranchId())) {
            throw new IllegalStateException(
                    "Branch " + dto.getBranchId() + " already recorded — forks are irreversible");
        }

        BranchEntry entry = BranchEntry.builder()
                .playerSave(save)
                .branchId(dto.getBranchId())
                .decision(dto.getDecision())
                .build();

        return toDTO(branchRepository.save(entry));
    }

    private BranchEntryDTO toDTO(BranchEntry b) {
        return BranchEntryDTO.builder()
                .id(b.getId())
                .branchId(b.getBranchId())
                .decision(b.getDecision())
                .build();
    }
}
