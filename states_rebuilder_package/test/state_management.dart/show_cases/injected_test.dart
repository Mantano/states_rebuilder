// ignore_for_file: use_key_in_widget_constructors, file_names, prefer_const_constructors, deprecated_member_use_from_same_package
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:states_rebuilder/scr/state_management/rm.dart';
import 'package:states_rebuilder/states_rebuilder.dart';

class Counter {
  Counter(this.count);
  int count = 0;
  @override
  String toString() {
    return 'Counter($count)';
  }
}

final counter1 = RM.inject(
  () => 0,
);
final counter1Future = RM.injectFuture(
  () => Future.delayed(Duration(seconds: 1), () => Counter(1)),
  autoDisposeWhenNotUsed: true,
);

//

void main() {
  testWidgets(
    'simple injected is linked to futureInjected',
    (tester) async {
      final counter1Computed = RM.inject<int?>(
        () => counter1.state + counter1Future.state.count,
        dependsOn: DependsOn({counter1Future, counter1}),
      );
      final widget = Directionality(
        textDirection: TextDirection.ltr,
        child: OnBuilder.orElse(
          listenTo: counter1Computed,
          onWaiting: () => Text('Waiting'),
          orElse: (_) => Text('${counter1Computed.state}'),
        ),
      );
      //
      await tester.pumpWidget(widget);
      expect(find.text('Waiting'), findsOneWidget);
      await tester.pump(Duration(seconds: 1));
      expect(find.text('1'), findsOneWidget);
      counter1Computed.refresh();
      await tester.pump();
      expect(find.text('1'), findsOneWidget);
      counter1Future.refresh();
      await tester.pump();
      expect(find.text('Waiting'), findsOneWidget);
      await tester.pump(Duration(seconds: 1));
      expect(find.text('1'), findsOneWidget);
    },
  );

  testWidgets(
    'futureInjected is linked to simple Injected',
    (tester) async {
      assert(injectedModels.isEmpty);
      final counter2Future = RM.injectFuture<int>(
        () => Future.delayed(Duration(seconds: 1), () => counter1.state + 1),
        dependsOn: DependsOn({counter1}),
      );

      final widget = Directionality(
        textDirection: TextDirection.ltr,
        child: OnBuilder.orElse(
          listenTo: counter2Future,
          onWaiting: () => Text('Waiting'),
          orElse: (_) => Text('${counter2Future.state}'),
        ),
      );
      //
      await tester.pumpWidget(widget);
      expect(find.text('Waiting'), findsOneWidget);
      await tester.pump(Duration(seconds: 1));
      expect(find.text('1'), findsOneWidget);
      //
      counter1.state++;
      await tester.pump();
      expect(find.text('Waiting'), findsOneWidget);
      await tester.pump(Duration(seconds: 1));
      expect(find.text('2'), findsOneWidget);
    },
  );

  testWidgets(
    'futureInjected is linked to another future Injected',
    (tester) async {
      final counter1Future = RM.injectFuture(
        () => Future.delayed(Duration(seconds: 2), () => [1]),
      );
      final counter2Future = RM.injectFuture<int>(
        () => Future.delayed(Duration(seconds: 1), () {
          return counter1Future.state.first + 1;
        }),
        dependsOn: DependsOn({counter1Future}),
      );

      final widget = Directionality(
        textDirection: TextDirection.ltr,
        child: OnBuilder.orElse(
          listenTo: counter2Future,
          onWaiting: () => Text('Waiting'),
          orElse: (_) {
            return Text('${counter2Future.state}');
          },
        ),
      );
      //
      await tester.pumpWidget(widget);
      expect(find.text('Waiting'), findsOneWidget);
      await tester.pump(Duration(seconds: 1));
      expect(find.text('Waiting'), findsOneWidget);
      await tester.pump(Duration(seconds: 1));
      expect(find.text('Waiting'), findsOneWidget);
      await tester.pump(Duration(seconds: 1));
      expect(find.text('2'), findsOneWidget);
    },
  );

  testWidgets(
    'Stream Injected is linked to another future Injected',
    (tester) async {
      final counter1Future = RM.injectFuture(
        () => Future.delayed(Duration(seconds: 2), () => [1]),
      );
      final counter2Stream = RM.injectStream<int>(
        () {
          return Stream.periodic(
            Duration(seconds: 1),
            (data) {
              return counter1Future.state.first + data;
            },
          );
        },
        dependsOn: DependsOn({counter1Future}),
      );

      final widget = Directionality(
        textDirection: TextDirection.ltr,
        child: OnBuilder.orElse(
          listenTo: counter2Stream,
          onWaiting: () => Text('Waiting'),
          orElse: (_) {
            return Text('${counter2Stream.state}');
          },
        ),
      );
      //
      await tester.pumpWidget(widget);
      expect(find.text('Waiting'), findsOneWidget);
      await tester.pump(Duration(seconds: 1));
      expect(find.text('Waiting'), findsOneWidget);
      await tester.pump(Duration(seconds: 1));
      expect(find.text('Waiting'), findsOneWidget);
      await tester.pump(Duration(seconds: 1));
      expect(find.text('1'), findsOneWidget);
      await tester.pump(Duration(seconds: 1));
      expect(find.text('2'), findsOneWidget);
      await tester.pump(Duration(seconds: 1));
      expect(find.text('3'), findsOneWidget);
      await tester.pump(Duration(seconds: 1));
    },
  );

  testWidgets(
    'form validation',
    (tester) async {
      final username = RM.inject(() => '');
      final password = RM.inject(() => '');

      void onUsernameChanged(String newUsername) {
        username.setState(
          (s) {
            if (!newUsername.contains('@')) {
              throw Exception('User name is not valid');
            }
            return newUsername;
          },
        );
      }

      void onPasswordChanged(String newPassword) {
        password.setState(
          (s) {
            try {
              int.parse(newPassword);
            } catch (e) {
              throw Exception('Password is not a valid number');
            }
            if (newPassword.length <= 2) {
              throw Exception('Password is not valid');
            }
            return newPassword;
          },
        );
      }

      //
      expect(username.isIdle, true);
      expect(password.isIdle, true);

      //
      onUsernameChanged('m');
      expect(username.hasError, true);
      expect(username.error.message, 'User name is not valid');
      //
      onUsernameChanged('me');
      expect(username.hasError, true);
      expect(username.error.message, 'User name is not valid');
      //
      onUsernameChanged('me@');
      expect(username.hasData, true);
      expect(username.state, 'me@');
      //
      onUsernameChanged('me');
      expect(username.hasError, true);
      expect(username.error.message, 'User name is not valid');
      //
      //
      onPasswordChanged('1');
      expect(password.hasError, true);
      expect(password.error.message, 'Password is not valid');
      //
      onPasswordChanged('12');
      expect(password.hasError, true);
      expect(password.error.message, 'Password is not valid');
      //
      onPasswordChanged('123');
      expect(password.hasData, true);
      expect(password.state, '123');
      //
      onPasswordChanged('12');
      expect(password.hasError, true);
      expect(password.error.message, 'Password is not valid');
      //
      onPasswordChanged('123');
      expect(password.hasData, true);
      expect(password.state, '123');
      //
      // onPasswordChanged('123a');
      // expect(password.hasError, true);
      // expect(password.error.message, 'Password is not a valid number');
      // //
      // onPasswordChanged('123');
      // expect(password.hasData, true);
      // expect(password.state, '123');
    },
  );

  testWidgets(
    'dependent counters',
    (tester) async {
      bool shouldThrow = false;
      final counter1 = RM.inject(() => 0);
      final counter1Future = RM.injectFuture(
        () => Future.delayed(
          Duration(seconds: 1),
          () => shouldThrow ? throw Exception('An ERROR') : 1,
        ),
      );
      final dependentCounter1 = RM.inject<int>(
        () => counter1.state + counter1Future.state,
        dependsOn: DependsOn({counter1, counter1Future}),
      );
      final dependentCounter2 = RM.inject<int>(
        () => dependentCounter1.state + 1,
        dependsOn: DependsOn({dependentCounter1}),
      );
      int numberOfNotification = 0;
      // ignore: unused_result
      dependentCounter2.addObserver(
        listener: (rm) {
          numberOfNotification++;
        },
        shouldAutoClean: true,
      );

      expect(dependentCounter2.isWaiting, true);
      expect(dependentCounter1.isWaiting, true);
      expect(counter1Future.isWaiting, true);
      expect(counter1.isIdle, true);
      expect(numberOfNotification, 1);

      await tester.pump(Duration(seconds: 1));
      expect(counter1Future.hasData, true);
      expect(dependentCounter1.hasData, true);
      expect(dependentCounter2.hasData, true);
      expect(counter1.isIdle, true);
      expect(numberOfNotification, 2);

      //
      counter1Future.refresh();
      expect(dependentCounter2.isWaiting, true);
      expect(dependentCounter1.isWaiting, true);
      expect(counter1Future.isWaiting, true);
      expect(counter1.isIdle, true);
      expect(numberOfNotification, 3);

      await tester.pump(Duration(seconds: 1));
      expect(counter1Future.hasData, true);
      expect(dependentCounter1.hasData, true);
      expect(dependentCounter2.hasData, true);
      expect(counter1.isIdle, true);
      expect(numberOfNotification, 4);

      //
      shouldThrow = true;
      counter1Future.refresh();
      expect(dependentCounter2.isWaiting, true);
      expect(dependentCounter1.isWaiting, true);
      expect(counter1Future.isWaiting, true);
      expect(counter1.isIdle, true);
      expect(numberOfNotification, 5);

      await tester.pump(Duration(seconds: 1));
      expect(counter1Future.hasError, true);
      expect(dependentCounter1.hasError, true);
      expect(dependentCounter2.hasError, true);
      expect(counter1.isIdle, true);
      expect(numberOfNotification, 6);

      //
      shouldThrow = false;
      counter1Future.refresh();
      expect(dependentCounter2.isWaiting, true);
      expect(dependentCounter1.isWaiting, true);
      expect(counter1Future.isWaiting, true);
      expect(counter1.isIdle, true);
      // tow calls: one from error to initstate and second from init to isWaiting
      expect(numberOfNotification, 8);

      await tester.pump(Duration(seconds: 1));
      expect(counter1Future.hasData, true);
      expect(dependentCounter1.hasData, true);
      expect(dependentCounter2.hasData, true);
      expect(counter1.isIdle, true);
      expect(numberOfNotification, 9);
      //
      //
      shouldThrow = true;
      counter1Future.refresh();
      expect(dependentCounter2.isWaiting, true);
      expect(dependentCounter1.isWaiting, true);
      expect(counter1Future.isWaiting, true);
      expect(counter1.isIdle, true);
      expect(numberOfNotification, 10);

      await tester.pump(Duration(seconds: 1));
      expect(counter1Future.hasError, true);
      expect(dependentCounter1.hasError, true);
      expect(dependentCounter2.hasError, true);
      expect(counter1.isIdle, true);
      expect(numberOfNotification, 11);

      //
      shouldThrow = false;
      counter1Future.refresh();
      expect(dependentCounter2.isWaiting, true);
      expect(dependentCounter1.isWaiting, true);
      expect(counter1Future.isWaiting, true);
      expect(counter1.isIdle, true);
      expect(numberOfNotification, 13);

      await tester.pump(Duration(seconds: 1));
      expect(counter1Future.hasData, true);
      expect(dependentCounter1.hasData, true);
      expect(dependentCounter2.hasData, true);
      expect(counter1.isIdle, true);
      expect(numberOfNotification, 14);
    },
  );

  testWidgets('Object extension', (tester) async {
    final model = _Model(0).inj();
    expect(model.state.count, 0);
    model.state = _Model(1);
    expect(model.state.count, 1);

    final injectedNull = null.inj<int?>();
    expect(injectedNull.state, null);
    expect(injectedNull.toString(), endsWith('SnapState<int?>(isIdle : null)'));
    injectedNull.state = 1;
    expect(injectedNull.state, 1);
    expect(injectedNull.toString(), endsWith('SnapState<int?>(hasData: 1)'));
    //
    expect(null.inj<int>(), isA<ReactiveModel<int?>>());
    expect(() => null.inj(), throwsAssertionError);
    expect(() => null.inj<Object>(), throwsAssertionError);
    expect(() => null.inj<Object?>(), throwsAssertionError);
    //
    final injectedInt = 1.inj();
    expect(injectedInt.state, 1);
    injectedInt.state++;
    expect(injectedInt.state, 2);
    expect(injectedInt.toString(), endsWith('SnapState<int>(hasData: 2)'));
    //
    final injectedDouble = 1.0.inj();
    expect(injectedDouble.state, 1.0);
    injectedDouble.state++;
    expect(injectedDouble.state, 2.0);
    //
    final injectedString = 'str1'.inj();
    expect(injectedString.state, 'str1');
    injectedString.state = 'str2';
    expect(injectedString.state, 'str2');
    //
    final injectedBool = true.inj();
    expect(injectedBool.state, true);
    injectedBool.toggle();
    expect(injectedBool.state, false);
    //
    int numberOfNotification = 0;
    final injectedList = [1].inj();
    injectedList.addObserver(
      shouldAutoClean: true,
      listener: (rm) {
        numberOfNotification++;
      },
    );
    expect(injectedList.state, [1]);
    injectedList.state = [1, 2];
    expect(injectedList.state, [1, 2]);
    expect(numberOfNotification, 1);
    injectedList.state = [1, 2];
    expect(numberOfNotification, 1);
    injectedList.state = [2, 2];
    expect(numberOfNotification, 2);
    //
    numberOfNotification = 0;
    final injectedSet = {_Model(1)}.inj();

    injectedSet.addObserver(
      shouldAutoClean: true,
      listener: (rm) {
        numberOfNotification++;
      },
    );

    expect(injectedSet.state, {_Model(1)});
    injectedSet.state = {_Model(1), _Model(2)};
    expect(injectedSet.state, {_Model(1), _Model(2)});
    expect(numberOfNotification, 1);
    injectedSet.state = {_Model(1), _Model(2)};
    expect(numberOfNotification, 1);
    injectedSet.state = {_Model(1), _Model(3)};
    expect(numberOfNotification, 2);

    //
    numberOfNotification = 0;
    final injectedMap = {'1': _Model(1)}.inj();
    injectedMap.addObserver(
      shouldAutoClean: true,
      listener: (rm) {
        numberOfNotification++;
      },
    );
    expect(injectedMap.state, {'1': _Model(1)});
    injectedMap.state = {'1': _Model(1), '2': _Model(2)};
    expect(injectedMap.state, {'1': _Model(1), '2': _Model(2)});
    expect(numberOfNotification, 1);
    injectedMap.state = {'1': _Model(1), '2': _Model(2)};
    expect(numberOfNotification, 1);
    injectedMap.state = {'1': _Model(1), '2': _Model(3)};
    expect(numberOfNotification, 2);

    numberOfNotification = 0;
    final injectModel = _Model(5).inj();
    injectModel.addObserver(
      shouldAutoClean: true,
      listener: (rm) {
        numberOfNotification++;
      },
    );
    expect(injectModel.state.count, 5);
    injectModel.setState((s) => s.increment());
    expect(injectModel.state.count, 6);
    expect(numberOfNotification, 1);
  });

  testWidgets('description', (tester) async {
    final counter = 0.inj();
    final widget2 = OnBuilder(
      builder: () => Text('widget2'),
      listenTo: counter,
    );
    final widget1 = OnBuilder(
      listenTo: counter,
      builder: () => ElevatedButton(
        child: Text(
          counter.state.toString(),
        ),
        onPressed: () => Navigator.of(RM.context!)
            .push(MaterialPageRoute(builder: (_) => widget2)),
      ),
    );
    await tester.pumpWidget(MaterialApp(home: widget1));
    //
    expect(find.byType(ElevatedButton), findsOneWidget);
    //
    Navigator.of(RM.context!).push(
      MaterialPageRoute(
        builder: (context) {
          return widget2;
        },
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('widget2'), findsOneWidget);
    Navigator.of(RM.context!).pop();
    await tester.pump();
    await tester.pump(Duration(milliseconds: 500));
    showDialog(
      context: RM.context!,
      builder: (context) => AlertDialog(
        content: Text('Dialog'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(ElevatedButton), findsOneWidget);
    expect(find.byType(AlertDialog), findsOneWidget);
  });

  testWidgets('Inherited injected', (tester) async {
    //
    final counter = RM.inject<int>(() => throw UnimplementedError());
    //
    late Injected<int> inheritedCounter1;
    int? inheritedCounter2;
    final widget = Directionality(
      textDirection: TextDirection.ltr,
      child: counter.inherited(
        stateOverride: () => 0,
        builder: (context) {
          context = context;
          inheritedCounter1 = counter(context);
          inheritedCounter2 = counter.of(context);
          return OnBuilder(
              listenTo: inheritedCounter1, builder: () => Container());
        },
      ),
    );

    await tester.pumpWidget(MaterialApp(
      home: widget,
    ));

    expect(inheritedCounter1, isA<Injected<int>>());
    expect(inheritedCounter1.state, 0);
    expect(inheritedCounter2, 0);
    //
    inheritedCounter1.state++;
    await tester.pump();
    //
    late Injected<int> reInheritedCounter1;
    int? reInheritedCounter2;
    final widget2 = inheritedCounter1.reInherited(
      context: RM.context!,
      builder: (context) {
        reInheritedCounter1 = counter(context);
        reInheritedCounter2 = counter.of(context);
        return Container();
      },
    );
    Navigator.of(RM.context!).push(
      MaterialPageRoute(
        builder: (context) {
          return widget2;
        },
      ),
    );
    await tester.pumpAndSettle();
    expect(reInheritedCounter1, isA<Injected<int>>());
    expect(reInheritedCounter1.state, 1);
    expect(reInheritedCounter2, 1);
    Navigator.of(RM.context!).pop();
    await tester.pumpAndSettle();
    expect(inheritedCounter1.state, 1);
    expect(inheritedCounter2, 1);
  });

  testWidgets('debounce  work', (tester) async {
    final counter = RM.inject(() => 0);
    final dependentCounter = RM.inject<int>(
      () => counter.state + 1,
      dependsOn: DependsOn(
        {counter},
        debounceDelay: 1000,
      ),
    );
    dependentCounter.state;
    counter.state++;
    expect(dependentCounter.state, 1);
    counter.state++;
    expect(dependentCounter.state, 1);

    await tester.pump(Duration(microseconds: 500));

    counter.state++;
    expect(dependentCounter.state, 1);

    await tester.pump(Duration(seconds: 1));
    expect(dependentCounter.state, 4);

    counter.state++;
    expect(dependentCounter.state, 4);

    counter.state++;
    expect(dependentCounter.state, 4);

    await tester.pump(Duration(seconds: 1));
    expect(dependentCounter.state, 6);
  });

  testWidgets('throttleDelay should work', (tester) async {
    final counter = RM.inject(() => 0);
    final dependentCounter = RM.inject<int>(
      () => counter.state + 1,
      dependsOn: DependsOn(
        {counter},
        throttleDelay: 1000,
      ),
    );
    dependentCounter.state;

    counter.state++;
    expect(dependentCounter.state, 2);
    counter.state++;
    expect(dependentCounter.state, 2);

    await tester.pump(Duration(microseconds: 500));

    counter.state++;
    expect(dependentCounter.state, 2);

    await tester.pump(Duration(seconds: 1));
    counter.state++;
    expect(dependentCounter.state, 5);

    counter.state++;
    expect(dependentCounter.state, 5);

    await tester.pump(Duration(seconds: 1));
  });

  testWidgets('depend on a state that is initialy on error', (tester) async {
    final counter = RM.inject<int>(() => throw Exception('Error'));
    final dependentCounter = RM.inject<int>(
      () {
        return counter.state + 1;
      },
      dependsOn: DependsOn({counter}),
    );
    expect(counter.hasError, true);
    expect(dependentCounter.hasError, true);
  });

  testWidgets('depend on ', (tester) async {
    final counter = RM.inject<int>(() => 0);
    final dependentCounter = RM.inject<int>(
      () => counter.state + 1,
      dependsOn: DependsOn({counter}),
    );
    // print(dependentCounter.state);
    await tester.pumpWidget(dependentCounter.rebuild(() => Container()));
  });

  testWidgets(
    'test rebuilder (Deprecated)'
    'THEN',
    (tester) async {
      final model = RM.inject(() => 0);
      final widget = Directionality(
        textDirection: TextDirection.ltr,
        child: model.rebuild.call(
          () {
            return Text(model.state.toString());
          },
          sideEffects: SideEffects<int>(),
          shouldRebuild: (_, __) {
            return true;
          },
          watch: () {
            return model.state;
          },
        ),
      );
      await tester.pumpWidget(widget);
      expect(find.text('0'), findsOneWidget);
      model.state++;
      await tester.pump();
      expect(find.text('1'), findsOneWidget);
    },
  );
  testWidgets(
    'test whenRebuilder (Deprecated)'
    'THEN',
    (tester) async {
      final model = RM.inject(() => 0);
      final widget = Directionality(
        textDirection: TextDirection.ltr,
        child: model.rebuild.onAll(
          onIdle: () => Text('onIdle'),
          onWaiting: () => Text('onWaiting'),
          onError: (err, _) => Text('onError'),
          onData: (_) => Text('onData'),
          sideEffects: SideEffects<int>(),
          shouldRebuild: (_, __) {
            return true;
          },
        ),
      );
      await tester.pumpWidget(widget);
      expect(find.text('onIdle'), findsOneWidget);
      model.setState((s) => Future.delayed(Duration(seconds: 1)));
      await tester.pump();
      expect(find.text('onWaiting'), findsOneWidget);
      await tester.pump(Duration(seconds: 1));
      expect(find.text('onData'), findsOneWidget);
    },
  );

  testWidgets(
    'test whenRebuilderOr (Deprecated)'
    'THEN',
    (tester) async {
      final model = RM.inject(() => 0);
      final widget = Directionality(
        textDirection: TextDirection.ltr,
        child: model.rebuild.onOrElse(
          onIdle: () => Text('onIdle'),
          onWaiting: () => Text('onWaiting'),
          onError: (err, _) => Text('onError'),
          orElse: (_) => Text('onData'),
          sideEffects: SideEffects<int>(),
          shouldRebuild: (_, __) {
            return true;
          },
          // watch: () {},
        ),
      );
      await tester.pumpWidget(widget);
      expect(find.text('onIdle'), findsOneWidget);
      model.setState((s) => Future.delayed(Duration(seconds: 1)));
      await tester.pump();
      expect(find.text('onWaiting'), findsOneWidget);
      await tester.pump(Duration(seconds: 1));
      expect(find.text('onData'), findsOneWidget);
    },
  );

  testWidgets(
    'test rebuilder for list (Deprecated)'
    'THEN',
    (tester) async {
      final model = RM.inject(() => 0);
      final widget = Directionality(
        textDirection: TextDirection.ltr,
        child: [model].rebuild(
          () {
            return Text(model.state.toString());
          },
          sideEffects: SideEffects(),
          shouldRebuild: (_, __) {
            return true;
          },
          watch: () {
            return model.state;
          },
        ),
      );
      await tester.pumpWidget(widget);
      expect(find.text('0'), findsOneWidget);
      model.state++;
      await tester.pump();
      expect(find.text('1'), findsOneWidget);
    },
  );

  testWidgets(
    'test whenRebuilder for list (Deprecated)'
    'THEN',
    (tester) async {
      final model = RM.inject(() => 0);
      final widget = Directionality(
        textDirection: TextDirection.ltr,
        child: [model].rebuild.onAll(
              onIdle: () => Text('onIdle'),
              onWaiting: () => Text('onWaiting'),
              onError: (err, _) => Text('onError'),
              onData: (_) => Text('onData'),
              sideEffects: SideEffects(),
              shouldRebuild: (_, __) {
                return true;
              },
            ),
      );
      await tester.pumpWidget(widget);
      expect(find.text('onIdle'), findsOneWidget);
      model.setState((s) => Future.delayed(Duration(seconds: 1)));
      await tester.pump();
      expect(find.text('onWaiting'), findsOneWidget);
      await tester.pump(Duration(seconds: 1));
      expect(find.text('onData'), findsOneWidget);
    },
  );

  testWidgets(
    'test whenRebuilderOr for list (Deprecated)'
    'THEN',
    (tester) async {
      final model = RM.inject(() => 0);
      final widget = Directionality(
        textDirection: TextDirection.ltr,
        child: [model].rebuild.onOrElse(
              onIdle: () => Text('onIdle'),
              onWaiting: () => Text('onWaiting'),
              onError: (err, _) => Text('onError'),
              orElse: (_) => Text('onData'),
              sideEffects: SideEffects(),

              shouldRebuild: (_, __) {
                return true;
              },
              // watch: () {},
            ),
      );
      await tester.pumpWidget(widget);
      expect(find.text('onIdle'), findsOneWidget);
      model.setState((s) => Future.delayed(Duration(seconds: 1)));
      await tester.pump();
      expect(find.text('onWaiting'), findsOneWidget);
      await tester.pump(Duration(seconds: 1));
      expect(find.text('onData'), findsOneWidget);
    },
  );
}

class _Model {
  int count;
  _Model(
    this.count,
  );
  void increment() => count++;

  @override
  bool operator ==(Object o) {
    if (identical(this, o)) return true;

    return o is _Model && o.count == count;
  }

  @override
  int get hashCode => count.hashCode;
}

// class App extends StateLessBuilder {
//   @override
//   Widget build(BuildContext context) {
//     final counter = 1.inj(context);
//     return Directionality(
//       textDirection: TextDirection.ltr,
//       child: Text(
//         counter.state.toString(),
//       ),
//     );
//   }
// }
