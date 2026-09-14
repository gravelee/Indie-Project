package com.echoesofthevoid.backend.repository;

import com.echoesofthevoid.backend.model.QuestState;
import com.echoesofthevoid.backend.enums.QuestStatus;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.Optional;

public interface QuestStateRepository extends JpaRepository<QuestState, Long> {
    List<QuestState> findByPlayerSaveId(Long saveId);
    List<QuestState> findByPlayerSaveIdAndStatus(Long saveId, QuestStatus status);
    Optional<QuestState> findByPlayerSaveIdAndQuestId(Long saveId, String questId);
}
