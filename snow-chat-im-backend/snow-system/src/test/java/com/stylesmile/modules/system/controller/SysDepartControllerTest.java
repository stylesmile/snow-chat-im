package com.stylesmile.modules.system.controller;

import com.stylesmile.modules.system.entity.SysDepart;
import com.stylesmile.modules.system.service.SysDepartService;
import com.stylesmile.modules.system.service.SysUserService;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.WebMvcTest;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.mock.web.MockHttpServletResponse;
import org.springframework.test.context.junit.jupiter.SpringExtension;
import org.springframework.test.web.servlet.MockMvc;

import java.util.Arrays;
import java.util.Collections;
import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;

@ExtendWith(SpringExtension.class)
@WebMvcTest(value = SysDepartController.class, excludeFilters = @org.springframework.context.annotation.ComponentScan.Filter(type = org.springframework.context.annotation.FilterType.ASSIGNABLE_TYPE, classes = com.stylesmile.config.WebMvcConfig.class))
class SysDepartControllerTest extends SystemWebMvcTestSupport {

    @Autowired
    private MockMvc mockMvc;

    @MockBean
    private SysDepartService mockSysDepartService;

    @MockBean
    private SysUserService mockSysUserService;

    @Test
    void testIndex() throws Exception {
        // Setup
        // Run the test
        final MockHttpServletResponse response = mockMvc.perform(get("/depart/index.html")
                        .accept(MediaType.TEXT_HTML))
                .andReturn().getResponse();

        // Verify the results
        assertThat(response.getStatus()).isEqualTo(HttpStatus.OK.value());
        assertThat(response.getContentAsString()).isNotNull();
    }

    @Test
    void testList() throws Exception {
        // Setup
        // Configure SysDepartService.getList(...).
        final List<SysDepart> sysDeparts = Arrays.asList(new SysDepart(0, 0, "name", "code", "sort"));
        when(mockSysDepartService.getList("source")).thenReturn(sysDeparts);

        // Run the test
        final MockHttpServletResponse response = mockMvc.perform(get("/depart/list.json")
                        .param("source", "source")
                        .accept(MediaType.APPLICATION_JSON))
                .andReturn().getResponse();

        // Verify the results
        assertThat(response.getStatus()).isEqualTo(HttpStatus.OK.value());
        assertThat(response.getContentAsString()).isNotNull();
    }

    @Test
    void testList_SysDepartServiceReturnsNoItems() throws Exception {
        // Setup
        when(mockSysDepartService.getList("source")).thenReturn(Collections.emptyList());

        // Run the test
        final MockHttpServletResponse response = mockMvc.perform(get("/depart/list.json")
                        .param("source", "source")
                        .accept(MediaType.APPLICATION_JSON))
                .andReturn().getResponse();

        // Verify the results
        assertThat(response.getStatus()).isEqualTo(HttpStatus.OK.value());
        assertThat(response.getContentAsString()).contains("\"data\":[]");
    }

    @Test
    void testAdd1() throws Exception {
        // Setup
        // Run the test
        final MockHttpServletResponse response = mockMvc.perform(get("/depart/add.html")
                        .param("parentId", "parentId")
                        .accept(MediaType.TEXT_HTML))
                .andReturn().getResponse();

        // Verify the results
        assertThat(response.getStatus()).isEqualTo(HttpStatus.OK.value());
        assertThat(response.getContentAsString()).isNotNull();
    }

    @Test
    void testAdd2() throws Exception {
        // Setup
        when(mockSysDepartService.save(any(SysDepart.class))).thenReturn(false);

        // Run the test
        final MockHttpServletResponse response = mockMvc.perform(post("/depart/add.json")
                        .content("content").contentType(MediaType.APPLICATION_JSON)
                        .accept(MediaType.APPLICATION_JSON))
                .andReturn().getResponse();

        // Verify the results
        assertThat(response.getStatus()).isEqualTo(HttpStatus.OK.value());
        assertThat(response.getContentAsString()).isNotNull();
    }

    @Test
    void testEdit1() throws Exception {
        // Setup
        // Configure SysDepartService.getById(...).
        final SysDepart sysDepart = new SysDepart(0, 0, "name", "code", "sort");
        when(mockSysDepartService.getById(0L)).thenReturn(sysDepart);

        // Run the test
        final MockHttpServletResponse response = mockMvc.perform(get("/depart/edit.html")
                        .param("id", "0")
                        .accept(MediaType.TEXT_HTML))
                .andReturn().getResponse();

        // Verify the results
        assertThat(response.getStatus()).isEqualTo(HttpStatus.OK.value());
        assertThat(response.getContentAsString()).isNotNull();
    }

    @Test
    void testEdit2() throws Exception {
        // Setup
        when(mockSysDepartService.updateById(any(SysDepart.class))).thenReturn(false);

        // Run the test
        final MockHttpServletResponse response = mockMvc.perform(post("/depart/edit.json")
                        .content("content").contentType(MediaType.APPLICATION_JSON)
                        .accept(MediaType.APPLICATION_JSON))
                .andReturn().getResponse();

        // Verify the results
        assertThat(response.getStatus()).isEqualTo(HttpStatus.OK.value());
        assertThat(response.getContentAsString()).isNotNull();
    }

    @Test
    void testDelete() throws Exception {
        // Setup
        when(mockSysDepartService.deleteDepart(0)).thenReturn(false);

        // Run the test
        final MockHttpServletResponse response = mockMvc.perform(post("/depart/delete.json")
                        .param("id", "0")
                        .accept(MediaType.APPLICATION_JSON))
                .andReturn().getResponse();

        // Verify the results
        assertThat(response.getStatus()).isEqualTo(HttpStatus.OK.value());
        assertThat(response.getContentAsString()).isNotNull();
    }
}
