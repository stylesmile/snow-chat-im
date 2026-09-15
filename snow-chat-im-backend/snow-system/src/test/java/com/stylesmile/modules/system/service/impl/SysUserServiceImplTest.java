package com.stylesmile.modules.system.service.impl;

import com.baomidou.mybatisplus.extension.plugins.pagination.Page;
import com.stylesmile.common.util.Result;
import com.stylesmile.modules.system.entity.SysUser;
import com.stylesmile.modules.system.mapper.SysUserMapper;
import com.stylesmile.modules.system.vo.LoginVo;
import com.stylesmile.modules.system.vo.query.SysUserQuery;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.Mock;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.mock.web.MockHttpServletRequest;
import org.springframework.test.util.ReflectionTestUtils;

import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpSession;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class SysUserServiceImplTest {

    private SysUserServiceImpl sysUserServiceImplUnderTest;
    @Mock
    SysUserMapper baseMapper;

    @BeforeEach
    void setUp() {
        sysUserServiceImplUnderTest = new SysUserServiceImpl();
        ReflectionTestUtils.setField(sysUserServiceImplUnderTest, "baseMapper", baseMapper);
    }

    @Test
    void testGetSessionUser() {
        // Setup
        final HttpServletRequest httpServletRequest = new MockHttpServletRequest();

        // Run the test
        final SysUser result = sysUserServiceImplUnderTest.getSessionUser(httpServletRequest);

        // Verify the results
    }

    @Test
    void testGetSysUserByNameAndPassword() {
        // Setup
        final LoginVo loginVo = new LoginVo();
        loginVo.setUsername("username");
        loginVo.setPassword("password");

        final HttpSession session = new MockHttpServletRequest().getSession();

        when(baseMapper.getSysUserByName("username")).thenReturn(null);

        // Run the test
        final Result<String> result = sysUserServiceImplUnderTest.getSysUserByNameAndPassword(loginVo, session);

        // Verify the results
    }

    @Test
    void testGetUserList() {
        // Setup
        final SysUserQuery sysUserQuery = new SysUserQuery();
        sysUserQuery.setUsername("username");
        sysUserQuery.setNickname("nickname");
        sysUserQuery.setPhone("phone");
        sysUserQuery.setEmail("email");
        sysUserQuery.setDepartId("departId");

        // Run the test
        when(baseMapper.getUserList(any(SysUserQuery.class))).thenReturn(new Page<>(1, 10));

        final Page<SysUser> result = sysUserServiceImplUnderTest.getUserList(sysUserQuery);

        // Verify the results
    }

    @Test
    void testUpdateUser() {
        // Setup
        final SysUser user = new SysUser("username", "password");

        when(baseMapper.updateUser(any(SysUser.class))).thenReturn(false);

        // Run the test
        final Boolean result = sysUserServiceImplUnderTest.updateUser(user);

        // Verify the results
        assertThat(result).isFalse();
    }

    @Test
    void testDeleteUser() {
        // Setup
        when(baseMapper.deleteUser(0)).thenReturn(false);

        // Run the test
        final Boolean result = sysUserServiceImplUnderTest.deleteUser(0);

        // Verify the results
        assertThat(result).isFalse();
    }

    @Test
    void testQueryPermission() {
        // Setup
        when(baseMapper.queryPermission("url", 0)).thenReturn(0);

        // Run the test
        final Integer result = sysUserServiceImplUnderTest.queryPermission("url", 0);

        // Verify the results
        assertThat(result).isEqualTo(0);
    }

    @Test
    void testClearUserListCache() {
        // Setup
        // Run the test
        sysUserServiceImplUnderTest.clearUserListCache();

        // Verify the results
    }

    @Test
    void testGetUserByIdCache() {
        assertThat(sysUserServiceImplUnderTest.getUserByIdCache(0)).isNull();
    }

    @Test
    void testClearUserCache() {
        // Setup
        // Run the test
        sysUserServiceImplUnderTest.clearUserCache(0);

        // Verify the results
    }

    @Test
    void testMain() {
        // Setup
        // Run the test
        SysUserServiceImpl.main(new String[]{"args"});

        // Verify the results
    }
}
