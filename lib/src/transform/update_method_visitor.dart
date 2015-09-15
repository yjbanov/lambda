part of lambda.compiler;

/// Generates code for the `update` method.
abstract class BaseUpdateMethodVisitor extends AstVisitor {
  final _buf = new StringBuffer();

  /// Sub-classes must implement this getter and return the template fragment
  /// for who the update method is being generated, or `null` if we at the
  /// root template level.
  Fragment get currentFragment;

  String get code => _buf.toString();

  @override
  bool visitHtmlElement(HtmlElement elem) {
    if (elem.isBound) {
      _emitPropChangeDetection(elem);
    }
    return false;
  }

  @override
  bool visitComponentElement(ComponentElement elem) {
    _emitPropChangeDetection(elem);
    return false;
  }

  @override
  bool visitDecorator(Decorator d) {
    _emitPropChangeDetection(d);
    return false;
  }

  void _emitPropChangeDetection(HasProps withProps) {
    withProps.props.forEach((Prop p) {
      _emit(' _tmp = ${_resolveExpression(p.expression)};');
      _emit(' if (!identical(_tmp, ${p.valueField})) {');
      _emit('   ${withProps.targetObjectField}.${p.property} =');
      _emit('     ${p.valueField} = _tmp;');
      _emit(' }');
    });
  }

  @override
  bool visitTextInterpolation(TextInterpolation ti) {
    _emit(' _tmp = \'\${${_resolveExpression(ti.expression)}}\';');
    _emit(' if (!identical(_tmp, ${ti.valueField})) {');
    _emit('   ${ti.nodeField}.text = ${ti.valueField} = _tmp;');
    _emit(' }');
    return false;
  }

  @override
  bool visitFragment(Fragment f) {
    _emit(' ${f.fragmentField}.render(${_resolveExpression(f.inputExpression)});');
    return true;
  }

  void _emit(Object o) {
    _buf.write(o);
  }

  /// TODO: it should be binder's job to resolve expressions
  String _resolveExpression(Expression expr) {
    final terms = expr.terms.join('.');
    if (expr.isThis || currentFragment == null) {
      // Expression starts with `this` or we're at the root level.
      return 'context.${terms}';
    } else {
      String firstTerm = expr.terms.first;
      var lowestFragment = currentFragment;
      int levelsUp = 0;
      while(lowestFragment != null &&
          !lowestFragment.outVars.contains(firstTerm)) {
        lowestFragment = currentFragment.parentFragment;
        levelsUp++;
      }
      if (lowestFragment == null) {
        // Assume published by context
        return terms;
      } else {
        return '${'parentFragment.' * levelsUp}${terms}';
      }
    }
  }
}

String snakeCase(String s) {
  final buf = new StringBuffer(s[0].toLowerCase());
  for (int i = 1; i < s.length; i++) {
    var lowerCaseChar = s[i].toLowerCase();
    if (lowerCaseChar != s[i]) {
      buf.write('-');
    }
    buf.write(lowerCaseChar);
  }
  return buf.toString();
}
