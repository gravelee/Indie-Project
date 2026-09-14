package com.echoesofthevoid.backend.service;

import com.echoesofthevoid.backend.dto.AffinityProfileDTO;
import com.echoesofthevoid.backend.model.AffinityProfile;
import com.echoesofthevoid.backend.repository.AffinityProfileRepository;
import jakarta.persistence.EntityNotFoundException;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@RequiredArgsConstructor
public class AffinityProfileService {

    private final AffinityProfileRepository affinityRepository;
    private final PlayerSaveService saveService;

    @Transactional(readOnly = true)
    public AffinityProfileDTO getAffinity(Long saveId) {
        return toDTO(findOrThrow(saveId));
    }

    @Transactional
    public AffinityProfileDTO updateAffinity(Long saveId, AffinityProfileDTO dto) {
        AffinityProfile affinity = findOrThrow(saveId);

        affinity.setVoidAxis(dto.getVoidAxis());
        affinity.setHonesty(dto.getHonesty());
        affinity.setBoldness(dto.getBoldness());
        affinity.setCuriosity(dto.getCuriosity());
        affinity.setEmpathy(dto.getEmpathy());
        affinity.setResilience(dto.getResilience());

        return toDTO(affinityRepository.save(affinity));
    }

    private AffinityProfile findOrThrow(Long saveId) {
        saveService.findOrThrow(saveId);
        return affinityRepository.findByPlayerSaveId(saveId)
                .orElseThrow(() -> new EntityNotFoundException("AffinityProfile not found for save: " + saveId));
    }

    private AffinityProfileDTO toDTO(AffinityProfile a) {
        return AffinityProfileDTO.builder()
                .voidAxis(a.getVoidAxis())
                .honesty(a.getHonesty())
                .boldness(a.getBoldness())
                .curiosity(a.getCuriosity())
                .empathy(a.getEmpathy())
                .resilience(a.getResilience())
                .build();
    }
}
