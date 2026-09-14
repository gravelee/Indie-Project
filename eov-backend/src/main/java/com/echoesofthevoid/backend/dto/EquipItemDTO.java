package com.echoesofthevoid.backend.dto;

import com.echoesofthevoid.backend.enums.ItemSlot;
import jakarta.validation.constraints.*;
import lombok.*;

@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class EquipItemDTO {

    @NotNull
    private ItemSlot slot;

    // null means unequip the slot
    private Long itemId;
}
