package com.echoesofthevoid.backend.dto;

import jakarta.validation.constraints.NotBlank;
import lombok.*;

import java.time.LocalDateTime;

@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class PlayerSaveDTO {
    private Long id;

    @NotBlank
    private String playerName;

    @NotBlank
    private String currentZone;

    @NotBlank
    private String checkpointId;

    private LocalDateTime createdAt;
    private LocalDateTime lastSavedAt;
}
