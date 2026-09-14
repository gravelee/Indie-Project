package com.echoesofthevoid.backend.controller;

import com.echoesofthevoid.backend.dto.EquipItemDTO;
import com.echoesofthevoid.backend.model.Equipment;
import com.echoesofthevoid.backend.service.EquipmentService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/saves/{saveId}/equipment")
@RequiredArgsConstructor
public class EquipmentController {

    private final EquipmentService equipmentService;

    @GetMapping
    public Equipment get(@PathVariable Long saveId) {
        return equipmentService.getEquipment(saveId);
    }

    @PutMapping("/slot")
    public Equipment equip(@PathVariable Long saveId,
                           @Valid @RequestBody EquipItemDTO dto) {
        return equipmentService.equipItem(saveId, dto);
    }
}
