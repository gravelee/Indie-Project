package com.echoesofthevoid.backend.repository;

import com.echoesofthevoid.backend.model.Item;
import org.springframework.data.jpa.repository.JpaRepository;

public interface ItemRepository extends JpaRepository<Item, Long> {
}
