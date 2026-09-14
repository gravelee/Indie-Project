package com.echoesofthevoid.backend.repository;

import com.echoesofthevoid.backend.model.Equipment;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.Optional;

public interface EquipmentRepository extends JpaRepository<Equipment, Long> {
    Optional<Equipment> findByPlayerSaveId(Long saveId);
}
