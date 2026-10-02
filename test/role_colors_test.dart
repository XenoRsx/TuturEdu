import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tuturedu/utils/role_colors.dart';

void main() {
  test('each role gets its dashboard color', () {
    expect(roleColor('Teacher'), Colors.green);
    expect(roleColor('Student'), Colors.blue);
    expect(roleColor('Parent'), Colors.orange);
    expect(roleColor('Admin'), Colors.purple);
  });

  test('unknown or missing role falls back to the Student color', () {
    expect(roleColor(null), Colors.blue);
    expect(roleColor('Something'), Colors.blue);
  });
}
