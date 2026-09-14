package com.echoesofthevoid.backend.controller;

import com.echoesofthevoid.backend.dto.CharacterStatsDTO;
import com.echoesofthevoid.backend.service.CharacterStatsService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/saves/{saveId}/stats")
@RequiredArgsConstructor
public class CharacterStatsController {

    private final CharacterStatsService statsService;

    @GetMapping
    public CharacterStatsDTO get(@PathVariable Long saveId) {
        return statsService.getStats(saveId);
    }

    @PutMapping
    public CharacterStatsDTO update(@PathVariable Long saveId,
                                    @Valid @RequestBody CharacterStatsDTO dto) {
        return statsService.updateStats(saveId, dto);
    }
}
