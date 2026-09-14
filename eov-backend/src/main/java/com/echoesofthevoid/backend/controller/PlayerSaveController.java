package com.echoesofthevoid.backend.controller;

import com.echoesofthevoid.backend.dto.PlayerSaveDTO;
import com.echoesofthevoid.backend.service.PlayerSaveService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/saves")
@RequiredArgsConstructor
public class PlayerSaveController {

    private final PlayerSaveService saveService;

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public PlayerSaveDTO create(@Valid @RequestBody PlayerSaveDTO dto) {
        return saveService.createSave(dto);
    }

    @GetMapping("/{id}")
    public PlayerSaveDTO get(@PathVariable Long id) {
        return saveService.getSave(id);
    }

    @PutMapping("/{id}")
    public PlayerSaveDTO update(@PathVariable Long id, @Valid @RequestBody PlayerSaveDTO dto) {
        return saveService.updateCheckpoint(id, dto);
    }

    @DeleteMapping("/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void delete(@PathVariable Long id) {
        saveService.deleteSave(id);
    }
}
