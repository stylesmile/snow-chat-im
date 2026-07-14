package com.stylesmile.modules.system.controller;

import com.baomidou.mybatisplus.extension.plugins.pagination.Page;
import com.stylesmile.modules.system.entity.SysRole;
import com.stylesmile.modules.system.service.SysRoleService;
import com.stylesmile.modules.system.service.SysUserService;
import com.stylesmile.modules.system.vo.query.SysRoleQuery;
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

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;

@ExtendWith(SpringExtension.class)
@WebMvcTest(value = SysRoleController.class, excludeFilters = @org.springframework.context.annotation.ComponentScan.Filter(type = org.springframework.context.annotation.FilterType.ASSIGNABLE_TYPE, classes = com.stylesmile.config.WebMvcConfig.class))
class SysRoleControllerTest extends SystemWebMvcTestSupport {

    @Autowired
    private MockMvc mockMvc;

    @MockBean
    private SysRoleService mockSysRoleService;

    @MockBean
    private SysUserService mockSysUserService;

    @Test
    void testIndex() throws Exception {
        // Setup
        // Run the test
        final MockHttpServletResponse response = mockMvc.perform(get("/role/index.html")
                        .accept(MediaType.APPLICATION_JSON))
                .andReturn().getResponse();

        // Verify the results
        assertThat(response.getStatus()).isEqualTo(HttpStatus.OK.value());
        assertThat(response.getContentAsString()).isNotNull();
    }

    @Test
    void testSelectRolePage() throws Exception {
        // Setup
        when(mockSysRoleService.getRoleList(any(SysRoleQuery.class))).thenReturn(new Page<>(0L, 0L, 0L));

        // Run the test
        final MockHttpServletResponse response = mockMvc.perform(get("/role/list.json")
                        .accept(MediaType.APPLICATION_JSON))
                .andReturn().getResponse();

        // Verify the results
        assertThat(response.getStatus()).isEqualTo(HttpStatus.OK.value());
        assertThat(response.getContentAsString()).isNotNull();
    }

    @Test
    void testAdd1() throws Exception {
        // Setup
        // Run the test
        final MockHttpServletResponse response = mockMvc.perform(get("/role/add.html")
                        .accept(MediaType.APPLICATION_JSON))
                .andReturn().getResponse();

        // Verify the results
        assertThat(response.getStatus()).isEqualTo(HttpStatus.OK.value());
        assertThat(response.getContentAsString()).isNotNull();
    }

    @Test
    void testAdd2() throws Exception {
        // Setup
        when(mockSysRoleService.checkDuplicate("code")).thenReturn(0);
        when(mockSysRoleService.save(any(SysRole.class))).thenReturn(false);

        // Run the test
        final MockHttpServletResponse response = mockMvc.perform(post("/role/add.json")
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
        // Configure SysRoleService.getById(...).
        final SysRole sysRole = new SysRole();
        sysRole.setId(0);
        sysRole.setName("name");
        sysRole.setCode("code");
        sysRole.setSort(0);
        sysRole.setDelFlag(0);
        when(mockSysRoleService.getById("id")).thenReturn(sysRole);

        // Run the test
        final MockHttpServletResponse response = mockMvc.perform(get("/role/edit.html")
                        .param("id", "id")
                        .accept(MediaType.TEXT_HTML))
                .andReturn().getResponse();

        // Verify the results
        assertThat(response.getStatus()).isEqualTo(HttpStatus.OK.value());
        assertThat(response.getContentAsString()).isNotNull();
    }

    @Test
    void testEdit2() throws Exception {
        // Setup
        when(mockSysRoleService.updateRole(any(SysRole.class))).thenReturn(false);

        // Run the test
        final MockHttpServletResponse response = mockMvc.perform(post("/role/edit.json")
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
        when(mockSysRoleService.deleteRole("id")).thenReturn(false);

        // Run the test
        final MockHttpServletResponse response = mockMvc.perform(post("/role/delete.json")
                        .param("id", "id")
                        .accept(MediaType.APPLICATION_JSON))
                .andReturn().getResponse();

        // Verify the results
        assertThat(response.getStatus()).isEqualTo(HttpStatus.OK.value());
        assertThat(response.getContentAsString()).isNotNull();
    }
}
