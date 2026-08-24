package com.stylesmile.chat.mapper;

import com.baomidou.mybatisplus.core.mapper.BaseMapper;
import com.stylesmile.chat.entity.ChatVerifyCode;
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Param;

/**
 * 验证码 mapper
 *
 * @author chenye
 * @date 2026/08/19
 */
@Mapper
public interface ChatVerifyCodeMapper extends BaseMapper<ChatVerifyCode> {

    /**
     * 查询最新一条未使用的指定类型验证码（用于校验）
     *
     * @param email  邮箱
     * @param type   验证码类型（register / reset_password）
     * @return 验证码记录，不存在则返回 null
     */
    ChatVerifyCode selectLatestUnused(@Param("email") String email, @Param("type") String type);

    /**
     * 将指定记录标记为已使用
     *
     * @param id 验证码ID
     */
    void markUsed(@Param("id") Long id);
}
