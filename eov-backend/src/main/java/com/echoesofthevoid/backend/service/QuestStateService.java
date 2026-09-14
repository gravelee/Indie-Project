package com.echoesofthevoid.backend.service;

import com.echoesofthevoid.backend.dto.QuestStateDTO;
import com.echoesofthevoid.backend.enums.QuestStatus;
import com.echoesofthevoid.backend.model.PlayerSave;
import com.echoesofthevoid.backend.model.QuestState;
import com.echoesofthevoid.backend.repository.QuestStateRepository;
import jakarta.persistence.EntityNotFoundException;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;

@Service
@RequiredArgsConstructor
public class QuestStateService {

    private final QuestStateRepository questRepository;
    private final PlayerSaveService saveService;

    @Transactional(readOnly = true)
    public List<QuestStateDTO> getAllQuests(Long saveId) {
        saveService.findOrThrow(saveId);
        return questRepository.findByPlayerSaveId(saveId).stream()
                .map(this::toDTO)
                .toList();
    }

    @Transactional(readOnly = true)
    public List<QuestStateDTO> getQuestsByStatus(Long saveId, QuestStatus status) {
        saveService.findOrThrow(saveId);
        return questRepository.findByPlayerSaveIdAndStatus(saveId, status).stream()
                .map(this::toDTO)
                .toList();
    }

    @Transactional
    public QuestStateDTO upsertQuest(Long saveId, QuestStateDTO dto) {
        PlayerSave save = saveService.findOrThrow(saveId);

        QuestState quest = questRepository.findByPlayerSaveIdAndQuestId(saveId, dto.getQuestId())
                .orElseGet(() -> QuestState.builder()
                        .playerSave(save)
                        .questId(dto.getQuestId())
                        .status(QuestStatus.NOT_STARTED)
                        .build());

        quest.setStatus(dto.getStatus());
        return toDTO(questRepository.save(quest));
    }

    private QuestStateDTO toDTO(QuestState q) {
        return QuestStateDTO.builder()
                .id(q.getId())
                .questId(q.getQuestId())
                .status(q.getStatus())
                .build();
    }
}
