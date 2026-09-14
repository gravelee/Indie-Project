package com.echoesofthevoid.backend.dto;

import com.echoesofthevoid.backend.enums.QuestStatus;
import jakarta.validation.constraints.*;
import lombok.*;

@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class QuestStateDTO {
    private Long id;

    @NotBlank
    private String questId;

    @NotNull
    private QuestStatus status;
}
