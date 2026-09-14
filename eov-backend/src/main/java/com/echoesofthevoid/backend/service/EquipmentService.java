package com.echoesofthevoid.backend.service;

import com.echoesofthevoid.backend.dto.EquipItemDTO;
import com.echoesofthevoid.backend.enums.ItemSlot;
import com.echoesofthevoid.backend.model.Equipment;
import com.echoesofthevoid.backend.model.Item;
import com.echoesofthevoid.backend.repository.EquipmentRepository;
import com.echoesofthevoid.backend.repository.ItemRepository;
import jakarta.persistence.EntityNotFoundException;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@RequiredArgsConstructor
public class EquipmentService {

    private final EquipmentRepository equipmentRepository;
    private final ItemRepository itemRepository;
    private final PlayerSaveService saveService;

    @Transactional(readOnly = true)
    public Equipment getEquipment(Long saveId) {
        saveService.findOrThrow(saveId);
        return equipmentRepository.findByPlayerSaveId(saveId)
                .orElseThrow(() -> new EntityNotFoundException("Equipment not found for save: " + saveId));
    }

    @Transactional
    public Equipment equipItem(Long saveId, EquipItemDTO dto) {
        Equipment equipment = getEquipment(saveId);

        Item item = dto.getItemId() != null
                ? itemRepository.findById(dto.getItemId())
                        .orElseThrow(() -> new EntityNotFoundException("Item not found: " + dto.getItemId()))
                : null;

        applyToSlot(equipment, dto.getSlot(), item);
        return equipmentRepository.save(equipment);
    }

    private void applyToSlot(Equipment equipment, ItemSlot slot, Item item) {
        switch (slot) {
            case MAIN_HAND  -> equipment.setMainHand(item);
            case OFF_HAND   -> equipment.setOffHand(item);
            case STANCE     -> equipment.setStance(item);
            case HEAD       -> equipment.setHead(item);
            case CHEST      -> equipment.setChest(item);
            case LEGS       -> equipment.setLegs(item);
            case FEET       -> equipment.setFeet(item);
            case HANDS      -> equipment.setHands(item);
            case ACCESSORY  -> equipment.setAccessory(item);
        }
    }
}
