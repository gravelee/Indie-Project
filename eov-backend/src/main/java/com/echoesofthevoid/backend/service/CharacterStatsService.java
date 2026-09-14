package com.echoesofthevoid.backend.service;

import com.echoesofthevoid.backend.dto.CharacterStatsDTO;
import com.echoesofthevoid.backend.model.CharacterStats;
import com.echoesofthevoid.backend.repository.CharacterStatsRepository;
import jakarta.persistence.EntityNotFoundException;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@RequiredArgsConstructor
public class CharacterStatsService {

    private final CharacterStatsRepository statsRepository;
    private final PlayerSaveService saveService;

    @Transactional(readOnly = true)
    public CharacterStatsDTO getStats(Long saveId) {
        return toDTO(findOrThrow(saveId));
    }

    @Transactional
    public CharacterStatsDTO updateStats(Long saveId, CharacterStatsDTO dto) {
        CharacterStats stats = findOrThrow(saveId);

        stats.setLevel(dto.getLevel());
        stats.setExp(dto.getExp());
        stats.setGold(dto.getGold());
        stats.setStr(dto.getStr());
        stats.setAgi(dto.getAgi());
        stats.setSta(dto.getSta());
        stats.setIntel(dto.getIntel());
        stats.setSpr(dto.getSpr());
        stats.setRes(dto.getRes());
        stats.setDef(dto.getDef());
        stats.setUnspentTalentPoints(dto.getUnspentTalentPoints());

        return toDTO(statsRepository.save(stats));
    }

    private CharacterStats findOrThrow(Long saveId) {
        saveService.findOrThrow(saveId);  // assert save exists
        return statsRepository.findByPlayerSaveId(saveId)
                .orElseThrow(() -> new EntityNotFoundException("Stats not found for save: " + saveId));
    }

    private CharacterStatsDTO toDTO(CharacterStats s) {
        return CharacterStatsDTO.builder()
                .level(s.getLevel())
                .exp(s.getExp())
                .gold(s.getGold())
                .str(s.getStr())
                .agi(s.getAgi())
                .sta(s.getSta())
                .intel(s.getIntel())
                .spr(s.getSpr())
                .res(s.getRes())
                .def(s.getDef())
                .unspentTalentPoints(s.getUnspentTalentPoints())
                .build();
    }
}
