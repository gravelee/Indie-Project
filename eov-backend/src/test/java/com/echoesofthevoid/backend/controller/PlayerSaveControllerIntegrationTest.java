package com.echoesofthevoid.backend.controller;

import tools.jackson.databind.ObjectMapper;
import com.echoesofthevoid.backend.dto.PlayerSaveDTO;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.transaction.annotation.Transactional;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

@SpringBootTest
@AutoConfigureMockMvc
@Transactional
class PlayerSaveControllerIntegrationTest {

    @Autowired private MockMvc mockMvc;
    @Autowired private ObjectMapper objectMapper;

    @Test
    void postSave_returns201_andPersistsRecord() throws Exception {
        PlayerSaveDTO dto = PlayerSaveDTO.builder()
                .playerName("Ares")
                .currentZone("ZONE_1_DEEP_FOREST")
                .checkpointId("VINEMORE_ENTRANCE")
                .build();

        mockMvc.perform(post("/api/saves")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(dto)))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.playerName").value("Ares"))
                .andExpect(jsonPath("$.currentZone").value("ZONE_1_DEEP_FOREST"))
                .andExpect(jsonPath("$.checkpointId").value("VINEMORE_ENTRANCE"))
                .andExpect(jsonPath("$.id").isNumber());
    }

    @Test
    void postSave_returns400_whenPlayerNameIsBlank() throws Exception {
        PlayerSaveDTO dto = PlayerSaveDTO.builder()
                .playerName("")
                .currentZone("ZONE_1_DEEP_FOREST")
                .checkpointId("VINEMORE_ENTRANCE")
                .build();

        mockMvc.perform(post("/api/saves")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(dto)))
                .andExpect(status().isBadRequest());
    }

    @Test
    void getSave_returns404_whenSaveDoesNotExist() throws Exception {
        mockMvc.perform(get("/api/saves/99999"))
                .andExpect(status().isNotFound());
    }

    @Test
    void postThenGet_returnsPersistedSave() throws Exception {
        PlayerSaveDTO dto = PlayerSaveDTO.builder()
                .playerName("Ares")
                .currentZone("ZONE_1_DEEP_FOREST")
                .checkpointId("VINEMORE_ENTRANCE")
                .build();

        String response = mockMvc.perform(post("/api/saves")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(dto)))
                .andExpect(status().isCreated())
                .andReturn().getResponse().getContentAsString();

        Long id = objectMapper.readTree(response).get("id").asLong();

        mockMvc.perform(get("/api/saves/" + id))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.playerName").value("Ares"))
                .andExpect(jsonPath("$.id").value(id));
    }
}
