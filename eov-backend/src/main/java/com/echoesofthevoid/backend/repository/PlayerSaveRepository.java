package com.echoesofthevoid.backend.repository;

import com.echoesofthevoid.backend.model.PlayerSave;
import org.springframework.data.jpa.repository.JpaRepository;

public interface PlayerSaveRepository extends JpaRepository<PlayerSave, Long> {
}
