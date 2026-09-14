package com.echoesofthevoid.backend.controller;

import com.echoesofthevoid.backend.dto.CharacterResourcesDTO;
import com.echoesofthevoid.backend.service.CharacterResourcesService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/saves/{saveId}/resources")
@RequiredArgsConstructor
public class CharacterResourcesController {

    private final CharacterResourcesService resourcesService;

    @GetMapping
    public CharacterResourcesDTO get(@PathVariable Long saveId) {
        return resourcesService.getResources(saveId);
    }

    @PutMapping
    public CharacterResourcesDTO update(@PathVariable Long saveId,
                                        @Valid @RequestBody CharacterResourcesDTO dto) {
        return resourcesService.updateResources(saveId, dto);
    }
}
