import 'package:auto_interop_generator/src/cache/dependency_graph.dart';
import 'package:test/test.dart';

void main() {
  group('DependencyGraph', () {
    late DependencyGraph graph;

    setUp(() {
      graph = DependencyGraph();
    });

    test('empty graph returns only changed packages', () {
      final result = graph.invalidationSet({'A'});
      expect(result, {'A'});
    });

    test('independent packages do not affect each other', () {
      // No dependencies added
      final result = graph.invalidationSet({'A'});
      expect(result, {'A'});
      expect(result.contains('B'), isFalse);
    });

    test('direct dependency triggers invalidation', () {
      graph.addDependency('B', 'A'); // B depends on A
      final result = graph.invalidationSet({'A'});
      expect(result, containsAll(['A', 'B']));
    });

    test('transitive invalidation', () {
      graph.addDependency('B', 'A'); // B depends on A
      graph.addDependency('C', 'B'); // C depends on B
      final result = graph.invalidationSet({'A'});
      expect(result, containsAll(['A', 'B', 'C']));
    });

    test('diamond dependency', () {
      graph.addDependency('B', 'A');
      graph.addDependency('C', 'A');
      graph.addDependency('D', 'B');
      graph.addDependency('D', 'C');
      final result = graph.invalidationSet({'A'});
      expect(result, containsAll(['A', 'B', 'C', 'D']));
    });

    test('change in leaf does not propagate upward', () {
      graph.addDependency('B', 'A'); // B depends on A
      final result = graph.invalidationSet({'B'});
      expect(result, {'B'});
      expect(result.contains('A'), isFalse);
    });

    test('multiple changed packages', () {
      graph.addDependency('B', 'A');
      graph.addDependency('C', 'B');
      graph.addDependency('D', 'X');
      final result = graph.invalidationSet({'A', 'X'});
      expect(result, containsAll(['A', 'B', 'C', 'X', 'D']));
    });

    test('directDependencies returns correct set', () {
      graph.addDependency('B', 'A');
      graph.addDependency('B', 'C');
      expect(graph.directDependencies('B'), {'A', 'C'});
      expect(graph.directDependencies('A'), isEmpty);
    });

    test('allPackages includes all nodes', () {
      graph.addDependency('B', 'A');
      expect(graph.allPackages, containsAll(['A', 'B']));
    });
  });
}
