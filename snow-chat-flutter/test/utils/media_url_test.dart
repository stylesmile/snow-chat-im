import 'package:flutter_test/flutter_test.dart';
import 'package:snow_chat/utils/media_url.dart';

/// MediaUrl.proxyMediaUrl 的单元测试。
///
/// 验证 OSS 直链能正确改写为后端代理地址，且非 OSS / 内嵌 / 本地 URL 不被改动。
void main() {
  const apiBase = 'https://api.winchat.club';

  test('OSS 图片直链应改写为后端 /file/raw 代理地址', () {
    const oss =
        'https://win-chat-chat.oss-rg-china-mainland.aliyuncs.com/images/2026/09/15/uuid.png';
    final result = MediaUrl.proxyMediaUrl(oss, apiBase: apiBase);
    expect(result, 'https://api.winchat.club/file/raw/images/2026/09/15/uuid.png');
  });

  test('OSS 直链带 query（如签名参数）应丢弃 query 只保留 key 路径', () {
    const oss =
        'https://win-chat-chat.oss-rg-china-mainland.aliyuncs.com/videos/a.mp4?Expires=1&x=2';
    final result = MediaUrl.proxyMediaUrl(oss, apiBase: apiBase);
    expect(result, 'https://api.winchat.club/file/raw/videos/a.mp4');
  });

  test('avatar 直链（无日期目录）也应改写', () {
    const oss = 'https://win-chat-chat.oss-rg-china-mainland.aliyuncs.com/avatars/550e8400.jpg';
    final result = MediaUrl.proxyMediaUrl(oss, apiBase: apiBase);
    expect(result, 'https://api.winchat.club/file/raw/avatars/550e8400.jpg');
  });

  test('baseUrl 末尾带斜杠时拼接不应出现双斜杠', () {
    const oss = 'https://win-chat-chat.oss-rg-china-mainland.aliyuncs.com/images/a.png';
    final result = MediaUrl.proxyMediaUrl(oss, apiBase: 'https://api.winchat.club/');
    expect(result, 'https://api.winchat.club/file/raw/images/a.png');
  });

  test('base64 data-URI 原样返回', () {
    const data = 'data:image/png;base64,SGVsbG8=';
    expect(MediaUrl.proxyMediaUrl(data, apiBase: apiBase), data);
  });

  test('已是后端代理前缀的 URL 原样返回，不重复打包', () {
    const proxied = 'https://api.winchat.club/file/raw/images/a.png';
    expect(MediaUrl.proxyMediaUrl(proxied, apiBase: apiBase), proxied);
  });

  test('本地/相对路径原样返回', () {
    const local = 'file:///tmp/a.png';
    const rel = '/images/a.png';
    expect(MediaUrl.proxyMediaUrl(local, apiBase: apiBase), local);
    expect(MediaUrl.proxyMediaUrl(rel, apiBase: apiBase), rel);
  });

  test('非 OSS 域名（其它图床）原样返回，不做代理', () {
    const other = 'https://cdn.other.com/images/a.png';
    expect(MediaUrl.proxyMediaUrl(other, apiBase: apiBase), other);
  });

  test('OSS 但 key 不在白名单（任意路径段）原样返回，防路径穿越', () {
    const bad = 'https://win-chat-chat.oss-rg-china-mainland.aliyuncs.com/images/../../etc/passwd';
    expect(MediaUrl.proxyMediaUrl(bad, apiBase: apiBase), bad);
  });
}