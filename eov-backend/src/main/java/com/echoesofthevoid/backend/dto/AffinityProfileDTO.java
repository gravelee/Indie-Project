package com.echoesofthevoid.backend.dto;

import jakarta.validation.constraints.*;
import lombok.*;

@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class AffinityProfileDTO {

    @Min(0) @Max(100) private int voidAxis;
    @Min(0) @Max(100) private int honesty;
    @Min(0) @Max(100) private int boldness;
    @Min(0) @Max(100) private int curiosity;
    @Min(0) @Max(100) private int empathy;
    @Min(0) @Max(100) private int resilience;
}
