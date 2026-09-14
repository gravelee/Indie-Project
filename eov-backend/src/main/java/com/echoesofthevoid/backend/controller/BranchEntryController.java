package com.echoesofthevoid.backend.controller;

import com.echoesofthevoid.backend.dto.BranchEntryDTO;
import com.echoesofthevoid.backend.service.BranchEntryService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/saves/{saveId}/branches")
@RequiredArgsConstructor
public class BranchEntryController {

    private final BranchEntryService branchService;

    @GetMapping
    public List<BranchEntryDTO> getAll(@PathVariable Long saveId) {
        return branchService.getBranches(saveId);
    }

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public BranchEntryDTO record(@PathVariable Long saveId,
                                 @Valid @RequestBody BranchEntryDTO dto) {
        return branchService.recordBranch(saveId, dto);
    }
}
