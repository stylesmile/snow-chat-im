package com.stylesmile.chat.mapper;

import org.apache.ibatis.annotations.Param;
import org.junit.jupiter.api.Test;

import java.io.IOException;
import java.io.InputStream;
import java.lang.reflect.Method;
import java.lang.reflect.Parameter;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Set;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

import static org.junit.jupiter.api.Assertions.assertTrue;

/**
 * Mapper XML 里的 {@code #{占位符}} 必须与接口方法的 {@code @Param} 名字对得上。
 *
 * <p>这类错误在纯 Mockito 单测里完全测不出来（mock 掉的 mapper 不会解析 XML），
 * 只有真正跑 SQL 时才会在 MyBatis 构建缓存 key 的阶段抛
 * {@code BindingException: Parameter 'xxx' not found}，表现为接口 500。
 *
 * <p>实例：ChatMessageMapper.xml 写的是 {@code LIMIT #{offset}, #{size}}，
 * 而接口参数名是 {@code page}，于是 GET /chat/message/history 一直返回
 * 500「内部失败」，历史消息（分页版）从来没可用过。这里用静态解析把它钉住。
 */
class MapperXmlParamConsistencyTest {

    /** MyBatis 内置变量，不需要在 @Param 里声明 */
    private static final Set<String> BUILTIN = Set.of("_parameter", "databaseId", "_databaseId");

    @Test
    void chatMessageMapperXmlMatchesInterface() throws IOException {
        assertXmlMatchesInterface(ChatMessageMapper.class, "/mapper/chat/ChatMessageMapper.xml");
    }

    @Test
    void chatSessionMapperXmlMatchesInterface() throws IOException {
        assertXmlMatchesInterface(ChatSessionMapper.class, "/mapper/chat/ChatSessionMapper.xml");
    }

    private void assertXmlMatchesInterface(Class<?> mapperType, String xmlPath) throws IOException {
        String xml = read(xmlPath);

        // foreach 的 item / index 是循环体内临时变量，不属于方法参数
        Set<String> loopVars = new LinkedHashSet<>();
        for (Matcher m = Pattern.compile("<foreach[^>]*?\\s(?:item|index)=\"(\\w+)\"").matcher(xml);
             m.find(); ) {
            loopVars.add(m.group(1));
        }

        Pattern stmtPattern = Pattern.compile(
                "<(select|insert|update|delete)\\s[^>]*?id=\"(\\w+)\"[^>]*>(.*?)</\\1>",
                Pattern.DOTALL);
        Matcher stmt = stmtPattern.matcher(xml);
        int checked = 0;
        while (stmt.find()) {
            String statementId = stmt.group(2);
            String body = stmt.group(3);

            Method method = findMethod(mapperType, statementId);
            if (method == null) {
                // 语句在接口里没有对应方法（历史遗留的孤儿 SQL），不参与一致性校验
                continue;
            }
            checked++;

            Set<String> available = availableParamNames(method);
            for (String placeholder : placeholders(body)) {
                if (loopVars.contains(placeholder) || BUILTIN.contains(placeholder)) {
                    continue;
                }
                assertTrue(available.contains(placeholder),
                        xmlPath + " 的语句 " + statementId + " 引用了 #{"
                                + placeholder + "}，但 " + mapperType.getSimpleName() + "#"
                                + statementId + " 只提供了 " + available
                                + "。占位符名必须与 @Param 一致，否则运行期抛 BindingException");
            }
        }
        assertTrue(checked > 0, xmlPath +  " 里没有找到任何能对应到 " + mapperType.getSimpleName()
                + " 方法的语句，校验未生效（语句 id 或接口方法名被改过？）");
    }

    /** 收集方法上所有可用参数名：优先 @Param 值，没有注解时用真实参数名 */
    private Set<String> availableParamNames(Method method) {
        Set<String> names = new LinkedHashSet<>();
        for (Parameter param : method.getParameters()) {
            Param annotation = param.getAnnotation(Param.class);
            names.add(annotation != null ? annotation.value() : param.getName());
        }
        return names;
    }

    /**
     * 提取 #{xxx} / ${xxx} 里的变量名，跳过 jdbcType 之类的附加属性。
     *
     * <p>只取<b>根名</b>：{@code #{m.id}} 的根是 {@code m}（其余部分是对象属性导航），
     * 归属判断要看根名是否出现在 {@code @Param} 里。
     */
    private List<String> placeholders(String body) {
        List<String> result = new ArrayList<>();
        Matcher m = Pattern.compile("[#$]\\{([^}]+)}").matcher(body);
        while (m.find()) {
            String raw = m.group(1).trim();
            int comma = raw.indexOf(',');
            if (comma > 0) {
                raw = raw.substring(0, comma).trim();
            }
            int dot = raw.indexOf('.');
            if (dot > 0) {
                raw = raw.substring(0, dot).trim();
            }
            result.add(raw);
        }
        return result;
    }

    private Method findMethod(Class<?> type, String name) {
        return Arrays.stream(type.getDeclaredMethods())
                .filter(m -> m.getName().equals(name))
                .findFirst()
                .orElse(null);
    }

    private String read(String classpath) throws IOException {
        try (InputStream in = getClass().getResourceAsStream(classpath)) {
            assertTrue(in != null, "classpath 下找不到 " + classpath);
            return new String(in.readAllBytes(), StandardCharsets.UTF_8);
        }
    }
}
