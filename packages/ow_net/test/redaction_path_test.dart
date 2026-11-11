import 'package:ow_net/ow_net.dart';
import 'package:test/test.dart';

void main() {
  final redactor = Redactor();

  test('formatPath_路径中的长不透明段_只保留前4位', () {
    expect(redactor.formatPath('/v2/abcdEFGH12345678ijklMNOP'), '/v2/abcd***');
    expect(
      redactor.formatPath(
        '/api/address/bc1qcr8te4kr609gcawutmrza0j4xv80jy8z306fyu',
      ),
      '/api/address/bc1q***',
    );
  });

  test('formatPath_普通路径段_保持原样', () {
    expect(redactor.formatPath('/api/v3/simple/price'), '/api/v3/simple/price');
    expect(redactor.formatPath('/'), '/');
    expect(redactor.formatPath(''), '');
  });
}
