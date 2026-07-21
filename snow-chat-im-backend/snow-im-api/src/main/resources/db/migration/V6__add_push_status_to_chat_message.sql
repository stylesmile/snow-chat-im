-- 消息表增加推送状态字段，记录接收方是否收到消息
ALTER TABLE chat_message ADD COLUMN push_status VARCHAR(20) DEFAULT 'pending' COMMENT '推送状态：pending=待推送, server_received=服务器已收到, client_ack=客户端已确认, delivered=已送达';
