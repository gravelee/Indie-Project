package com.echoesofthevoid.backend.repository;

import com.echoesofthevoid.backend.model.CharacterStats;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.Optional;

public interface CharacterStatsRepository extends JpaRepository<CharacterStats, Long> {
    Optional<CharacterStats> findByPlayerSaveId(Long saveId);
}
