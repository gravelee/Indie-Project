package com.echoesofthevoid.backend.service;

import com.echoesofthevoid.backend.dto.CharacterResourcesDTO;
import com.echoesofthevoid.backend.model.CharacterResources;
import com.echoesofthevoid.backend.repository.CharacterResourcesRepository;
import jakarta.persistence.EntityNotFoundException;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@RequiredArgsConstructor
public class CharacterResourcesService {

    private final CharacterResourcesRepository resourcesRepository;
    private final PlayerSaveService saveService;

    @Transactional(readOnly = true)
    public CharacterResourcesDTO getResources(Long saveId) {
        return toDTO(findOrThrow(saveId));
    }

    @Transactional
    public CharacterResourcesDTO updateResources(Long saveId, CharacterResourcesDTO dto) {
        CharacterResources resources = findOrThrow(saveId);

        resources.setCurrentHp(dto.getCurrentHp());
        resources.setMaxHp(dto.getMaxHp());
        resources.setEnergy(dto.getEnergy());
        resources.setFlow(dto.getFlow());
        resources.setFocus(dto.getFocus());

        return toDTO(resourcesRepository.save(resources));
    }

    private CharacterResources findOrThrow(Long saveId) {
        saveService.findOrThrow(saveId);
        return resourcesRepository.findByPlayerSaveId(saveId)
                .orElseThrow(() -> new EntityNotFoundException("Resources not found for save: " + saveId));
    }

    private CharacterResourcesDTO toDTO(CharacterResources r) {
        return CharacterResourcesDTO.builder()
                .currentHp(r.getCurrentHp())
                .maxHp(r.getMaxHp())
                .energy(r.getEnergy())
                .flow(r.getFlow())
                .focus(r.getFocus())
                .build();
    }
}
