package com.echoesofthevoid.backend.dto;

import jakarta.validation.constraints.*;
import lombok.*;

@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class BranchEntryDTO {
    private Long id;

    @NotBlank
    @Pattern(regexp = "B-0[1-9]")
    private String branchId;

    @NotBlank
    private String decision;
}
