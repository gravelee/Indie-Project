package com.echoesofthevoid.backend.service;

import com.echoesofthevoid.backend.dto.PlayerSaveDTO;
import com.echoesofthevoid.backend.model.*;
import com.echoesofthevoid.backend.repository.PlayerSaveRepository;
import jakarta.persistence.EntityNotFoundException;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@RequiredArgsConstructor
public class PlayerSaveService {

    private final PlayerSaveRepository saveRepository;

    @Transactional
    public PlayerSaveDTO createSave(PlayerSaveDTO dto) {
        PlayerSave save = PlayerSave.builder()
                .playerName(dto.getPlayerName())
                .currentZone(dto.getCurrentZone())
                .checkpointId(dto.getCheckpointId())
                .build();

        // Initialise all child records with defaults
        CharacterStats stats = CharacterStats.builder().playerSave(save).build();
        CharacterResources resources = CharacterResources.builder().playerSave(save).build();
        AffinityProfile affinity = AffinityProfile.builder().playerSave(save).build();
        Equipment equipment = Equipment.builder().playerSave(save).build();

        save.setStats(stats);
        save.setResources(resources);
        save.setAffinity(affinity);
        save.setEquipment(equipment);

        PlayerSave saved = saveRepository.save(save);
        return toDTO(saved);
    }

    @Transactional(readOnly = true)
    public PlayerSaveDTO getSave(Long id) {
        return toDTO(findOrThrow(id));
    }

    @Transactional
    public PlayerSaveDTO updateCheckpoint(Long id, PlayerSaveDTO dto) {
        PlayerSave save = findOrThrow(id);
        save.setCurrentZone(dto.getCurrentZone());
        save.setCheckpointId(dto.getCheckpointId());
        return toDTO(saveRepository.save(save));
    }

    @Transactional
    public void deleteSave(Long id) {
        saveRepository.delete(findOrThrow(id));
    }

    PlayerSave findOrThrow(Long id) {
        return saveRepository.findById(id)
                .orElseThrow(() -> new EntityNotFoundException("PlayerSave not found: " + id));
    }

    private PlayerSaveDTO toDTO(PlayerSave save) {
        return PlayerSaveDTO.builder()
                .id(save.getId())
                .playerName(save.getPlayerName())
                .currentZone(save.getCurrentZone())
                .checkpointId(save.getCheckpointId())
                .createdAt(save.getCreatedAt())
                .lastSavedAt(save.getLastSavedAt())
                .build();
    }
}
