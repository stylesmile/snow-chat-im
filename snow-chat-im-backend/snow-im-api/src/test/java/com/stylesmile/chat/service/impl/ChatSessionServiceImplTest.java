package com.stylesmile.chat.service.impl;

import com.stylesmile.chat.entity.ChatSession;
import com.stylesmile.chat.mapper.ChatSessionMapper;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.Spy;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.test.util.ReflectionTestUtils;

/**
 * ChatSessionServiceImpl 单元测试
 *
 * 注意：ChatSessionServiceImpl 的所有公共方法（getSessionsByUserId / getOrCreateSession /
 * updateLastMessage / clearUnreadCount）内部均使用 MyBatisPlus 的 LambdaQueryWrapper /
 * LambdaUpdateWrapper 配合实体方法引用（如 ChatSession::getUserId），
 * 这需要 MyBatisPlus 框架上下文（lambda cache）才能解析字段名。
 * 在纯 Mockito 单元测试中无法触发 lambda cache 初始化，因此这些方法的行为
 * 应由集成测试（@SpringBootTest 或 @MybatisPlusTest）覆盖，而非此处单元测试。
 *
 * 此测试类保留 setUp 以备后续添加不依赖 lambda cache 的测试用例。
 */
@ExtendWith(MockitoExtension.class)
class ChatSessionServiceImplTest {

    @Mock
    private ChatSessionMapper mapper;

    @Spy
    private ChatSessionServiceImpl service;

    @BeforeEach
    void setUp() {
        // 注入 baseMapper（BaseServiceImpl 依赖），供 selectList/update/selectOne/insert 调用
        ReflectionTestUtils.setField(service, "baseMapper", mapper);
    }

    // getSessionsByUserId / getOrCreateSession / updateLastMessage / clearUnreadCount
    // 均依赖 LambdaQueryWrapper / LambdaUpdateWrapper 的 lambda cache，
    // 无法在纯 Mockito 单元测试中覆盖，需由集成测试验证。
}
