package com.echoesofthevoid.backend.dto;

import jakarta.validation.constraints.*;
import lombok.*;

@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class CharacterResourcesDTO {

    @Min(0) private int currentHp;
    @Min(0) private int maxHp;

    @Min(0) @Max(100) private int energy;
    @Min(0) @Max(100) private int flow;
    @Min(0) @Max(100) private int focus;
}
