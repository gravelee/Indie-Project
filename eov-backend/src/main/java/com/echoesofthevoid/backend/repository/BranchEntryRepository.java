package com.echoesofthevoid.backend.repository;

import com.echoesofthevoid.backend.model.BranchEntry;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.Optional;

public interface BranchEntryRepository extends JpaRepository<BranchEntry, Long> {
    List<BranchEntry> findByPlayerSaveId(Long saveId);
    Optional<BranchEntry> findByPlayerSaveIdAndBranchId(Long saveId, String branchId);
    boolean existsByPlayerSaveIdAndBranchId(Long saveId, String branchId);
}
