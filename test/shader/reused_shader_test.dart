import 'package:adaptive_liquid_glass/src/shader/reused_shader.dart';
import 'package:flutter_test/flutter_test.dart';

class _Program {}

class _Shader {
  _Shader(this.program);
  final _Program program;
}

void main() {
  late List<_Shader> created;
  late List<_Shader> released;
  late ReusedShader<_Program, _Shader> holder;

  setUp(() {
    created = [];
    released = [];
    holder = ReusedShader<_Program, _Shader>(
      create: (p) {
        final s = _Shader(p);
        created.add(s);
        return s;
      },
      release: released.add,
    );
  });

  test('every paint of one program gets the same shader', () {
    final p = _Program();
    final first = holder.of(p);
    for (var i = 0; i < 100; i++) {
      expect(holder.of(p), same(first));
    }
    expect(created, hasLength(1));
    expect(released, isEmpty);
  });

  test('a new program releases the old shader', () {
    final a = holder.of(_Program());
    final b = holder.of(_Program());
    expect(b, isNot(same(a)));
    expect(released, [a]);
  });

  test('clear releases once and is idempotent', () {
    final a = holder.of(_Program());
    holder
      ..clear()
      ..clear();
    expect(released, [a]);
  });
}
