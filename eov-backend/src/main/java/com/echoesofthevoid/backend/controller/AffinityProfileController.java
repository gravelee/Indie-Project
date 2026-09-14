package com.echoesofthevoid.backend.controller;

import com.echoesofthevoid.backend.dto.AffinityProfileDTO;
import com.echoesofthevoid.backend.service.AffinityProfileService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/saves/{saveId}/affinity")
@RequiredArgsConstructor
public class AffinityProfileController {

    private final AffinityProfileService affinityService;

    @GetMapping
    public AffinityProfileDTO get(@PathVariable Long saveId) {
        return affinityService.getAffinity(saveId);
    }

    @PatchMapping
    public AffinityProfileDTO update(@PathVariable Long saveId,
                                     @Valid @RequestBody AffinityProfileDTO dto) {
        return affinityService.updateAffinity(saveId, dto);
    }
}
