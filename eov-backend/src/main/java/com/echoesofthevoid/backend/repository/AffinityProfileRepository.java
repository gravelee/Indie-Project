package com.echoesofthevoid.backend.repository;

import com.echoesofthevoid.backend.model.AffinityProfile;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.Optional;

public interface AffinityProfileRepository extends JpaRepository<AffinityProfile, Long> {
    Optional<AffinityProfile> findByPlayerSaveId(Long saveId);
}
