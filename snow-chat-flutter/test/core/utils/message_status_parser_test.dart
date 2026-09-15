import 'package:flutter_test/flutter_test.dart';
import 'package:snow_chat/core/utils/message_status_parser.dart';

void main() {
  group('parseMessageStatus', () {
    test('returns same string when given a string', () {
      expect(parseMessageStatus('sent'), 'sent');
      expect(parseMessageStatus('failed'), 'failed');
      expect(parseMessageStatus('sending'), 'sending');
    });

    test('maps int to sent', () {
      expect(parseMessageStatus(0), 'sent');
      expect(parseMessageStatus(1), 'sent');
    });

    test('returns sent for null or empty', () {
      expect(parseMessageStatus(null), 'sent');
      expect(parseMessageStatus(''), 'sent');
    });
  });
}
