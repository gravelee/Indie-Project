package com.echoesofthevoid.backend.repository;

import com.echoesofthevoid.backend.model.CharacterResources;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.Optional;

public interface CharacterResourcesRepository extends JpaRepository<CharacterResources, Long> {
    Optional<CharacterResources> findByPlayerSaveId(Long saveId);
}
