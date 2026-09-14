package com.echoesofthevoid.backend.controller;

import com.echoesofthevoid.backend.dto.QuestStateDTO;
import com.echoesofthevoid.backend.enums.QuestStatus;
import com.echoesofthevoid.backend.service.QuestStateService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/saves/{saveId}/quests")
@RequiredArgsConstructor
public class QuestStateController {

    private final QuestStateService questService;

    @GetMapping
    public List<QuestStateDTO> getAll(@PathVariable Long saveId,
                                      @RequestParam(required = false) QuestStatus status) {
        if (status != null) {
            return questService.getQuestsByStatus(saveId, status);
        }
        return questService.getAllQuests(saveId);
    }

    @PutMapping("/{questId}")
    public QuestStateDTO update(@PathVariable Long saveId,
                                @PathVariable String questId,
                                @Valid @RequestBody QuestStateDTO dto) {
        dto.setQuestId(questId);
        return questService.upsertQuest(saveId, dto);
    }
}
