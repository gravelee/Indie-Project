package com.echoesofthevoid.backend.dto;

import jakarta.validation.constraints.*;
import lombok.*;

@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class CharacterStatsDTO {

    @Min(1) @Max(30) private int level;
    @Min(0) private int exp;
    @Min(0) private int gold;

    @Min(1) private int str;
    @Min(1) private int agi;
    @Min(1) private int sta;
    @Min(1) private int intel;
    @Min(1) private int spr;
    @Min(1) private int res;
    @Min(1) private int def;

    @Min(0) private int unspentTalentPoints;
}
